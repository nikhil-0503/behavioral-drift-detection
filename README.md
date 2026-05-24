# Timeo - Behavioral Drift Detection

Behavioral Drift Detection is an end-to-end project that detects changes in smartphone usage behavior over time.

The repository includes:
- A data preprocessing and feature engineering pipeline.
- Multiple drift detection models (statistical, machine learning, deep learning).
- A fusion layer that combines model outputs into a final daily drift decision.
- A FastAPI backend for serving drift results and real-time drift analysis.
- A Flutter mobile app for visualization and user interaction.

## Why This Project Exists

Smartphone behavior can reveal routine changes that may be relevant for:
- digital wellbeing,
- habit tracking,
- anomaly awareness,
- research on user behavior patterns.

A single model can be noisy or brittle. This project uses a multi-model approach and fuses predictions to improve robustness.

## What The Project Does

At a high level, the system:
1. Builds daily behavioral features from raw smartphone logs (app usage events + phone unlock events).
2. Detects drift using three independent approaches:
   - Statistical z-score detector,
   - Isolation Forest detector,
   - Autoencoder reconstruction-error detector.
3. Fuses model votes into a final confidence score and drift flag.
4. Exports results for both backend API responses and Flutter UI visualization.

## How It Works

### 1. Data Flow

Raw data is under `data/raw/...`.

Preprocessing outputs:
- `data/processed/app_usage_daily.csv`
- `data/processed/phonelock_daily.csv`
- `data/processed/daily_features.csv`
- `data/processed/daily_features_expanded.csv`

Model outputs:
- `data/processed/statistical_drift_results.csv`
- `data/processed/isolation_forest_results.csv`
- `data/processed/autoencoder_drift_results.csv`

Fusion outputs:
- `data/processed/final_drift_output.csv`
- `data/processed/final_drift_output.json`

Flutter export:
- `flutter_app/behavioral_drift_app/assets/drift_results.json`

### 2. Feature Engineering

Core daily features are built from:
- app event count per day,
- unlock count per day.

Expanded features include:
- log transforms,
- rolling mean and rolling std,
- day-to-day deltas,
- ratio-to-baseline features,
- composite intensity and instability scores.

### 3. Drift Models

#### A) Statistical Drift (`ml/models/statistical_drift.py`)
- Baseline: first 7 days.
- Computes per-feature z-scores.
- Marks drift when absolute z-score crosses threshold.

#### B) Isolation Forest (`ml/models/isolation_forest.py`)
- Standardizes expanded features.
- Trains unsupervised anomaly detector.
- Predicts anomalous days as drift days.

#### C) Autoencoder (`ml/models/autoencoder_drift.py`)
- Trains autoencoder on baseline window.
- Uses reconstruction error as drift score.
- Threshold based on baseline error distribution.

### 4. Fusion Logic

Fusion script: `ml/fusion/generate_final_output.py`

It merges model outputs by date and computes:
- vote count from three detectors,
- confidence = votes / 3,
- final drift flag using confidence threshold.

Current threshold logic marks drift at confidence >= 0.34 (at least one model votes drift).

## Repository Layout

```text
backend/                 FastAPI service
ml/preprocessing/        Feature extraction and preprocessing scripts
ml/models/               Statistical, Isolation Forest, Autoencoder scripts
ml/fusion/               Fusion + export scripts
data/raw/                Input dataset
data/processed/          Intermediate and final outputs
flutter_app/             Flutter mobile app
docs/                    Project documentation and architecture assets
```

## Download The Project

## Option 1: Git clone

```bash
git clone <YOUR_REPO_URL>
cd behavioral-drift-detection
```

## Option 2: ZIP download

1. Download ZIP from your Git hosting page.
2. Extract to a folder.
3. Open the extracted folder in VS Code.

## Prerequisites

## Python + Backend
- Python 3.10+ recommended.
- `pip`.

## Flutter App
- Flutter SDK installed and configured.
- Dart SDK (comes with Flutter).
- Android Studio (for Android emulator/device tooling).
- Firebase project (for Google Sign-In in app).

## Quick Start (Use Existing Processed Outputs)

This is the fastest way to run the project without regenerating all ML artifacts.

### 1) Start backend API

From project root:

```bash
cd backend
pip install -r requirements.txt
uvicorn api:app --reload --host 0.0.0.0 --port 8000
```

Health check:
- Open `http://localhost:8000/health`

### 2) Run Flutter app

From project root:

```bash
cd flutter_app/behavioral_drift_app
flutter pub get
flutter run
```

Notes:
- On Android emulator, backend base URL is `http://10.0.2.2:8000`.
- On web/desktop, backend base URL is `http://localhost:8000`.

## Full Reproduction (End-to-End Pipeline)

If you want to regenerate all derived files from raw data, run scripts in this order.

Important: `ml/preprocessing` scripts use relative paths, so run them from the `ml/preprocessing` directory.

### Step A: Build daily features

```bash
cd ml/preprocessing
python app_usage_features.py
python phonelock_features.py
python merge_daily_features.py
python feature_expansion.py
```

### Step B: Run drift models

From project root:

```bash
python ml/models/statistical_drift.py
python ml/models/isolation_forest.py
python ml/models/autoencoder_drift.py
```

### Step C: Fuse outputs

From project root:

```bash
python ml/fusion/generate_final_output.py
```

Optional export for Flutter asset:

```bash
python ml/fusion/export_for_flutter.py
```

### Step D: Start backend and app

Follow the same backend and Flutter commands from Quick Start.

## Backend API Reference

Base URL: `http://localhost:8000`

### `GET /health`
Returns service status and whether fused drift JSON is available.

### `GET /drift/days?limit=N`
Returns drift timeline entries from `data/processed/final_drift_output.json`.

### `GET /drift/summary`
Returns:
- total days,
- total drift days,
- last drift date,
- average confidence,
- latest date.

### `POST /drift/recompute`
Runs fusion script (`ml/fusion/generate_final_output.py`) and updates final outputs.

### `POST /ml/drift/apps`
Real-time model endpoint that accepts per-app daily usage history and returns fused ML drift analysis.

Example payload:

```json
{
  "apps": [
    {
      "packageName": "com.example.app",
      "history": [
        { "date": "2026-03-20", "minutes": 32 },
        { "date": "2026-03-21", "minutes": 75 },
        { "date": "2026-03-22", "minutes": 40 }
      ]
    }
  ]
}
```

## Flutter App Notes

Flutter module path:
- `flutter_app/behavioral_drift_app`

Key capabilities:
- Firebase authentication with Google Sign-In.
- Dashboard/statistics/log views.
- Real-time drift API integration.
- Local persistence + optional cloud sync services.
- Android-focused monitoring and permission workflow.

### Firebase/Google Auth Setup (Required for Sign-In)

See app-specific guide:
- `flutter_app/behavioral_drift_app/README.md`

At minimum:
1. Enable Google provider in Firebase Authentication.
2. Replace `android/app/google-services.json` with your Firebase file.
3. Configure iOS plist if building iOS.
4. Re-run `flutter clean` and `flutter pub get`.

If authentication is not needed for your demo, you can still inspect backend outputs independently.

## Common Issues and Fixes

### Backend fails to start
- Confirm you installed packages from `backend/requirements.txt`.
- Ensure Python environment has `torch`, `scikit-learn`, `fastapi`, and `uvicorn`.

### `GET /drift/days` returns empty list
- Ensure `data/processed/final_drift_output.json` exists.
- Run `python ml/fusion/generate_final_output.py` first.

### Flutter cannot reach backend
- Verify backend is running on port 8000.
- On Android emulator use `10.0.2.2`, not `localhost`.

### Google Sign-In error (`ApiException: 10` / `DEVELOPER_ERROR`)
- Register correct SHA keys in Firebase.
- Re-download and replace `google-services.json`.

### Script path errors during preprocessing
- Run preprocessing scripts from `ml/preprocessing` so relative paths resolve correctly.

## Suggested Development Workflow

1. Create and verify processed features.
2. Run all model scripts.
3. Generate fused output.
4. Start backend and validate `/health` and `/drift/summary`.
5. Start Flutter app and verify UI data flow.

## Team/Academic Context

This repository appears structured as an academic lab project with separate components for:
- data engineering,
- model experimentation,
- deployment-facing API,
- mobile UI integration.

You can adapt it into:
- a pure offline research pipeline,
- a backend-only drift service,
- or a full mobile + backend demo system.

## License

No explicit license file is currently present in the repository.
If you plan to distribute this project, add a `LICENSE` file and attribution rules.
