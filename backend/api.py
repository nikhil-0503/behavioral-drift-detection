from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import json
import os
import subprocess
import sys
from datetime import datetime

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
