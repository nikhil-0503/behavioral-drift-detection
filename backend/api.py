from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel
import json
import os
import subprocess
import sys
import numpy as np
from datetime import datetime
from typing import Optional

# ── ML imports ──
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
import torch
import torch.nn as nn

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROCESSED_DIR = os.path.join(BASE_DIR, "data", "processed")
DRIFT_JSON_PATH = os.path.join(PROCESSED_DIR, "final_drift_output.json")
FUSION_SCRIPT_PATH = os.path.join(
	BASE_DIR, "ml", "fusion", "generate_final_output.py"
)

app = FastAPI(title="Behavioral Drift API", version="1.0.0")

app.add_middleware(
	CORSMiddleware,
	allow_origins=["*"],
	allow_credentials=True,
	allow_methods=["*"],
	allow_headers=["*"],
)


# ──────────────────────────────────────────────────
# AUTOENCODER MODEL (same architecture as offline)
# ──────────────────────────────────────────────────
class AutoEncoder(nn.Module):
	def __init__(self, input_dim):
		super().__init__()
		self.encoder = nn.Sequential(
			nn.Linear(input_dim, 16),
			nn.ReLU(),
			nn.Linear(16, 8),
		)
		self.decoder = nn.Sequential(
			nn.Linear(8, 16),
			nn.ReLU(),
			nn.Linear(16, input_dim),
		)

	def forward(self, x):
		return self.decoder(self.encoder(x))


# ──────────────────────────────────────────────────
# ML DRIFT COMPUTATION FUNCTIONS
# ──────────────────────────────────────────────────

def _extract_features(history: list[dict]) -> np.ndarray:
	"""
	Extract features from daily usage history.
	Input: list of {"date": "YYYY-MM-DD", "minutes": float}
	Output: 2D numpy array with engineered features per day.
	"""
	minutes = [h["minutes"] for h in history]
	n = len(minutes)
	features = []
	for i in range(n):
		day_min = minutes[i]
		# Rolling mean (last 3 days)
		window_start = max(0, i - 2)
		rolling_mean = np.mean(minutes[window_start : i + 1])
		# Rolling std
		rolling_std = np.std(minutes[window_start : i + 1]) if i >= 1 else 0.0
		# Day-over-day change
		delta = minutes[i] - minutes[i - 1] if i > 0 else 0.0
		# Ratio to overall mean so far
		cumulative_mean = np.mean(minutes[: i + 1])
		ratio = day_min / max(cumulative_mean, 0.01)

		features.append([day_min, rolling_mean, rolling_std, delta, ratio])
	return np.array(features)


def _run_statistical_drift(features: np.ndarray, baseline_days: int = 7) -> dict:
	"""
	Statistical z-score drift detection.
	Returns per-day drift flags and scores.
	"""
	if len(features) <= baseline_days:
		baseline_days = max(1, len(features) // 2)

	baseline = features[:baseline_days]
	mean = baseline.mean(axis=0)
	std = baseline.std(axis=0)
	std[std == 0] = 1.0  # avoid division by zero

	z_scores = np.abs((features - mean) / std)
	max_z = z_scores.max(axis=1)

	# Drift if max z-score >= 2
	drift_flags = max_z >= 2.0
	return {
		"drift_flags": drift_flags.tolist(),
		"scores": max_z.tolist(),
	}


def _run_isolation_forest(features: np.ndarray) -> dict:
	"""
	Isolation Forest anomaly detection on usage features.
	"""
	if len(features) < 3:
		return {
			"drift_flags": [False] * len(features),
			"scores": [0.0] * len(features),
		}

	scaler = StandardScaler()
	X_scaled = scaler.fit_transform(features)

	contamination = min(0.15, max(0.01, 1.0 / len(features)))
	iso = IsolationForest(
		n_estimators=200,
		contamination=contamination,
		random_state=42,
	)
	preds = iso.fit_predict(X_scaled)
	scores = -iso.score_samples(X_scaled)  # higher = more anomalous

	# Normalize scores to 0-1
	s_min, s_max = scores.min(), scores.max()
	if s_max > s_min:
		scores_norm = (scores - s_min) / (s_max - s_min)
	else:
		scores_norm = np.zeros_like(scores)

	return {
		"drift_flags": (preds == -1).tolist(),
		"scores": scores_norm.tolist(),
	}


def _run_autoencoder(features: np.ndarray, baseline_days: int = 7) -> dict:
	"""
	Autoencoder reconstruction error based drift detection.
	"""
	if len(features) < 3:
		return {
			"drift_flags": [False] * len(features),
			"scores": [0.0] * len(features),
		}

	if len(features) <= baseline_days:
		baseline_days = max(1, len(features) // 2)

	scaler = StandardScaler()
	X_scaled = scaler.fit_transform(features)
	X_tensor = torch.tensor(X_scaled, dtype=torch.float32)

	input_dim = X_tensor.shape[1]
	model = AutoEncoder(input_dim)
	criterion = nn.MSELoss()
	optimizer = torch.optim.Adam(model.parameters(), lr=0.001)

	# Train on baseline
	X_train = X_tensor[:baseline_days]
	for _ in range(100):
		optimizer.zero_grad()
		out = model(X_train)
		loss = criterion(out, X_train)
		loss.backward()
		optimizer.step()

	# Compute reconstruction error
	with torch.no_grad():
		reconstructed = model(X_tensor)
		recon_error = torch.mean((X_tensor - reconstructed) ** 2, dim=1).numpy()

	# Threshold: baseline mean + 2*std
	baseline_error = recon_error[:baseline_days]
	threshold = baseline_error.mean() + 2 * baseline_error.std()
	if threshold == 0:
		threshold = 0.01

	drift_flags = recon_error > threshold

	# Normalize scores
	max_err = recon_error.max()
	if max_err > 0:
		scores_norm = recon_error / max_err
	else:
		scores_norm = np.zeros_like(recon_error)

	return {
		"drift_flags": drift_flags.tolist(),
		"scores": scores_norm.tolist(),
	}


def _fuse_results(
	stat: dict, iso: dict, ae: dict, n_days: int
) -> list[dict]:
	"""
	Fuse results from all three models using majority voting.
	Returns per-day fused drift decision + confidence.
	"""
	results = []
	for i in range(n_days):
		votes = [
			int(stat["drift_flags"][i]),
			int(iso["drift_flags"][i]),
			int(ae["drift_flags"][i]),
		]
		confidence = round(sum(votes) / 3.0, 3)
		final_drift = confidence >= 0.34  # at least 1/3 models agree

		results.append({
			"dayIndex": i,
			"finalDrift": final_drift,
			"confidence": confidence,
			"models": {
				"statistical": {
					"drift": stat["drift_flags"][i],
					"score": round(stat["scores"][i], 4),
				},
				"isolationForest": {
					"drift": iso["drift_flags"][i],
					"score": round(iso["scores"][i], 4),
				},
				"autoencoder": {
					"drift": ae["drift_flags"][i],
					"score": round(ae["scores"][i], 4),
				},
			},
		})
	return results


# ──────────────────────────────────────────────────
# PYDANTIC MODELS
# ──────────────────────────────────────────────────

class DailyUsage(BaseModel):
	date: str
	minutes: float


class AppDriftRequest(BaseModel):
	packageName: str
	history: list[DailyUsage]


class MlDriftRequest(BaseModel):
	apps: list[AppDriftRequest]


# ──────────────────────────────────────────────────
# EXISTING ENDPOINTS (unchanged)
# ──────────────────────────────────────────────────

def _load_drift_days() -> list[dict]:
	if not os.path.exists(DRIFT_JSON_PATH):
		return []
	with open(DRIFT_JSON_PATH, "r", encoding="utf-8") as f:
		data = json.load(f)
	if not isinstance(data, list):
		return []
	return data


@app.get("/health")
def health():
	data_available = os.path.exists(DRIFT_JSON_PATH)
	return {
		"status": "ok",
		"dataAvailable": data_available,
		"timestamp": datetime.utcnow().isoformat() + "Z",
	}


@app.get("/drift/days")
def get_drift_days(limit: int | None = None):
	days = _load_drift_days()
	if limit is not None:
		if limit < 1:
			raise HTTPException(status_code=400, detail="limit must be >= 1")
		days = days[-limit:]
	return JSONResponse(content=days)


@app.get("/drift/summary")
def get_summary():
	days = _load_drift_days()
	if not days:
		return {
			"totalDays": 0,
			"driftDays": 0,
			"lastDriftDate": None,
			"avgConfidence": 0.0,
			"latestDate": None,
		}

	drift_days = [d for d in days if d.get("drift")]
	last_drift_date = drift_days[-1]["date"] if drift_days else None
	avg_conf = sum(d.get("confidence", 0.0) for d in days) / len(days)

	return {
		"totalDays": len(days),
		"driftDays": len(drift_days),
		"lastDriftDate": last_drift_date,
		"avgConfidence": round(avg_conf, 3),
		"latestDate": days[-1]["date"],
	}


@app.post("/drift/recompute")
def recompute_drift():
	if not os.path.exists(FUSION_SCRIPT_PATH):
		raise HTTPException(status_code=404, detail="Fusion script not found")

	result = subprocess.run(
		[sys.executable, FUSION_SCRIPT_PATH],
		capture_output=True,
		text=True,
	)

	if result.returncode != 0:
		raise HTTPException(
			status_code=500,
			detail={
				"error": "Recompute failed",
				"stderr": result.stderr.strip(),
				"stdout": result.stdout.strip(),
			},
		)

	return {
		"status": "ok",
		"message": "Drift recomputed",
		"stdout": result.stdout.strip(),
	}


# ──────────────────────────────────────────────────
# NEW: REAL-TIME ML DRIFT ENDPOINT
# ──────────────────────────────────────────────────

@app.post("/ml/drift/apps")
def compute_ml_drift(request: MlDriftRequest):
	"""
	Accept per-app usage history from the phone, run all three ML models
	(Isolation Forest, Autoencoder, Statistical Z-score), fuse results,
	and return drift analysis for each app.
	"""
	results = []

	for app_req in request.apps:
		history = [{"date": h.date, "minutes": h.minutes} for h in app_req.history]

		if len(history) < 2:
			# Not enough data for ML — return no-drift
			results.append({
				"packageName": app_req.packageName,
				"date": history[-1]["date"] if history else "",
				"finalDrift": False,
				"confidence": 0.0,
				"models": {
					"statistical": {"drift": False, "score": 0.0},
					"isolationForest": {"drift": False, "score": 0.0},
					"autoencoder": {"drift": False, "score": 0.0},
				},
				"message": "Insufficient data for ML analysis (need >= 2 days)",
			})
			continue

		try:
			# Extract features from usage history
			features = _extract_features(history)
			n_days = len(features)

			# Run all three models
			stat_result = _run_statistical_drift(features)
			iso_result = _run_isolation_forest(features)
			ae_result = _run_autoencoder(features)

			# Fuse results
			fused = _fuse_results(stat_result, iso_result, ae_result, n_days)

			# Return the latest day's result (most recent)
			latest = fused[-1]
			latest["packageName"] = app_req.packageName
			latest["date"] = history[-1]["date"]

			# Also include a summary of drift trend
			drift_count = sum(1 for f in fused if f["finalDrift"])
			latest["driftTrend"] = {
				"totalDays": n_days,
				"driftDays": drift_count,
				"driftRate": round(drift_count / n_days, 3) if n_days > 0 else 0,
			}

			results.append(latest)

		except Exception as e:
			results.append({
				"packageName": app_req.packageName,
				"date": history[-1]["date"] if history else "",
				"finalDrift": False,
				"confidence": 0.0,
				"models": {
					"statistical": {"drift": False, "score": 0.0},
					"isolationForest": {"drift": False, "score": 0.0},
					"autoencoder": {"drift": False, "score": 0.0},
				},
				"error": str(e),
			})

	return JSONResponse(content=results)
