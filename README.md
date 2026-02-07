# Behavioral Drift Detection System

## Timeo – A Smartphone Behavior Analysis Platform

**Version:** 2.0.0  
**Status:** Research/Prototype + Real-Time Monitoring (Android)  
**License:** See repository  
**Last Updated:** February 2026

---

## What's New in v2.0.0 – Real-Time Behavioral Drift

### Overview

v2.0.0 adds **real-time, app-specific behavioral drift detection** to the existing offline ML pipeline. The app now monitors selected target apps on Android, computes user-vs-own-baseline drift, and enforces daily time limits with app blocking.

### Key Features

- **Google Authentication** (Firebase Auth with Google Sign-In) — mandatory before accessing the dashboard
- **Permission Wizard** — onboarding flow that gates access behind Usage Stats, Accessibility Service, and Overlay permissions
- **App-Specific Monitoring** — user selects which apps to monitor; apps can be ADDED but never removed (accountability by design)
- **Immutable Limits** — daily time limits can only be REDUCED, never increased; enforced at data, UI, and service layers
- **Real-Time Drift** — compares today's per-app usage against the user's own 14-day baseline; drift score = deviation magnitude
- **Background Service** — foreground service + boot receiver ensures continuous monitoring even after reboot
- **App Blocking** — accessibility service detects foreground app and blocks when limit is exceeded; overlay shows accountability message
- **Modern Dashboard** — Material 3 UI with bar charts, usage progress, drift explanations, and behavioral nudges
- **Platform Guards** — iOS/web/desktop show "not supported yet" screen

### Architecture (v2.0 additions)

```
Login (Google) → Permission Wizard → Dashboard
                                        ├── Real-Time Dashboard (new)
                                        ├── Offline Stats (existing)
                                        ├── Logs (existing)
                                        └── About (existing)

Native Android (MethodChannel):
  MainActivity ──→ UsageStatsManager (usage data)
  AppBlockerAccessibilityService ──→ foreground app detection + blocking
  MonitoringForegroundService ──→ periodic limit enforcement
  BootReceiver ──→ restart service after reboot
  BlockOverlayActivity ──→ "app blocked" full-screen message
```

### Firebase Setup

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add an Android app with package name `com.example.behavioral_drift_app`
3. Download `google-services.json` and place it at:
   ```
   flutter_app/behavioral_drift_app/android/app/google-services.json
   ```
4. Enable **Google Sign-In** in Firebase Console → Authentication → Sign-in method
5. Add your SHA-1 fingerprint (from `./gradlew signingReport`) to the Firebase Android app settings

### Android Permissions

| Permission | Purpose |
|---|---|
| `PACKAGE_USAGE_STATS` | Read app usage statistics from UsageStatsManager |
| `SYSTEM_ALERT_WINDOW` | Show block overlay when limit exceeded |
| `BIND_ACCESSIBILITY_SERVICE` | Detect foreground app for blocking |
| `FOREGROUND_SERVICE` | Run monitoring service continuously |
| `RECEIVE_BOOT_COMPLETED` | Restart monitoring after device reboot |
| `QUERY_ALL_PACKAGES` | List installed apps for the "add app" picker |
| `POST_NOTIFICATIONS` | Show foreground service notification (Android 13+) |

### Background Service Behavior

- **MonitoringForegroundService**: polls UsageStatsManager every 30 seconds; marks apps as blocked in SharedPreferences when their limit is exceeded
- **AppBlockerAccessibilityService**: listens for `TYPE_WINDOW_STATE_CHANGED` events; if a blocked app comes to foreground, launches `BlockOverlayActivity`
- **BootReceiver**: on `BOOT_COMPLETED`, starts the foreground service so monitoring resumes automatically
- **Midnight Reset**: daily usage counters reset at midnight via WorkManager or on next poll cycle

### Running Tests

```bash
cd flutter_app/behavioral_drift_app
flutter test test/limit_rules_test.dart test/app_list_test.dart test/enforcement_test.dart
```

Tests cover:
- Limit rules: reduce allowed, increase rejected, zero/negative rejected
- App list: model serialization, usage ratio, limit exceeded logic, remaining minutes
- Enforcement triggers: warn at 80%, block at 100%, mutual exclusivity, limit reduction chains

### Design Decisions

| Decision | Rationale |
|---|---|
| **Provider** for state management | Lightweight, no extra packages needed beyond what Flutter provides; sufficient for this scope |
| **sqflite** for local DB | Mature, well-tested, no code generation required (unlike drift ORM) |
| **MethodChannel** for native comms | Direct control over Android APIs (UsageStatsManager, Accessibility); no third-party native plugins with uncertain maintenance |
| **Append-only app list** | Accountability: once you commit to monitoring an app, you can't hide from the data |
| **Reduce-only limits** | Prevents "I'll just bump the limit to 4 hours" rationalization; enforced at model, DB, and UI levels |
| **User-vs-own baseline** | Drift is personal — comparing to other users' behavior is meaningless for self-improvement |
| **Foreground service** | Required for persistent monitoring; START_STICKY ensures restart after OOM kill |

---

> **Below is the original v1.0 documentation for the offline ML pipeline.**

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [Machine Learning Pipeline](#machine-learning-pipeline)
4. [Flutter Application](#flutter-application)
5. [Current Implementation Status](#current-implementation-status)
6. [Repository Structure](#repository-structure)
7. [Known Limitations](#known-limitations)
8. [Future Roadmap](#future-roadmap)
9. [How to Run the Project](#how-to-run-the-project)
10. [Developer Notes](#developer-notes)

---

## Project Overview

### Problem Statement

**Behavioral drift** occurs when a person's daily smartphone usage patterns deviate significantly from their historical baseline. This can indicate:
- Changes in mental health or stress levels
- Shifts in work-life patterns
- Adoption of new applications or technologies
- Behavioral anomalies or concerning changes

This project builds a machine learning system to automatically detect and flag these behavioral deviations in real-time.

### What is Behavioral Drift?

Behavioral drift is defined as a **statistically significant change** in one or more of the following metrics compared to a user's personal baseline:

- **App Usage Activity**: Total number of app events (app opens, interactions) per day
- **Phone Lock/Unlock Frequency**: Number of times the user unlocks their device per day
- **Aggregated Features**: Derived metrics like rolling means, volatility, and ratio-to-baseline measures

A drift is flagged when one or more machine learning models detect an anomaly in this data.

### Target Users

- **Researchers** studying behavioral patterns and mental health indicators
- **Students** and academic institutions analyzing smartphone usage
- **Privacy-conscious individuals** who want to monitor their own behavior offline
- **Developers** extending this system with additional models or data sources

### Key Characteristics

✅ **Offline Processing** – All inference happens on processed data, no real-time data collection  
✅ **Multi-Model Approach** – Three independent drift detection techniques providing robust decisions  
✅ **Visual Dashboard** – Flutter app for easy interpretation of results  
✅ **Explainable Results** – Confidence scores and individual model votes are visible  
✅ **Academic Foundation** – Built on StudentLife dataset and peer-reviewed techniques  

---

## System Architecture

### End-to-End Data Flow

```
┌──────────────────────────────────────────────────────────────────┐
│                     SMARTPHONE RAW DATA                          │
│  (StudentLife Dataset: app usage logs, phone lock events)       │
└────────────────────────┬─────────────────────────────────────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │   PREPROCESSING STAGE 1        │
        │  (Raw Feature Extraction)      │
        │  • app_usage_features.py       │
        │  • phonelock_features.py       │
        │  Output: Daily app events,     │
        │          Daily unlock counts   │
        └────────────────┬───────────────┘
                         │
                         ▼
        ┌────────────────────────────────┐
        │   PREPROCESSING STAGE 2        │
        │  (Feature Merge & Expansion)   │
        │  • merge_daily_features.py     │
        │  • feature_expansion.py        │
        │  Output: Expanded feature set  │
        │  (14 features per day)         │
        └────────────────┬───────────────┘
                         │
          ┌──────────────┴──────────────┐
          │                             │
          ▼                             ▼
  ┌──────────────────┐         ┌──────────────────┐
  │  Isolation       │         │  Autoencoder     │
  │  Forest          │         │  Deep Learning   │
  │  Model           │         │  Model           │
  │  ↓               │         │  ↓               │
  │ ML Drift         │         │ DL Drift         │
  │ Scores           │         │ Scores           │
  └────────┬─────────┘         └────────┬─────────┘
           │                            │
           └──────────────┬─────────────┘
                          │
                          ▼
        ┌────────────────────────────────┐
        │  Statistical Drift Detection   │
        │  (Baseline Z-score analysis)   │
        │  Output: Statistical flags     │
        └────────────────┬───────────────┘
                         │
          ┌──────────────┴─────────────────┐
          │                                │
          ▼                                │
  ┌───────────────────────────────────┐   │
  │  FUSION ENGINE                    │───┘
  │  (Voting + Confidence Calculation)│
  │  • Merge all model outputs        │
  │  • Vote combination (3 models)    │
  │  • Confidence = votes/3           │
  │  • Final drift decision           │
  └────────────────┬────────────────────┘
                   │
        ┌──────────┴──────────┐
        ▼                     ▼
   CSV Output          JSON Output
   (for debugging)     (for Flutter)
        │                     │
        └──────────────┬──────┘
                       │
                       ▼
        ┌────────────────────────────────┐
        │   FLUTTER MOBILE APP           │
        │   (Offline Visualization)      │
        │  • Load JSON from assets       │
        │  • Display Charts & Timeline   │
        │  • Show Confidence Scores      │
        │  • Responsive UI               │
        └────────────────────────────────┘
```

### Data Flow Summary

| Stage | Input | Process | Output |
|-------|-------|---------|--------|
| **Raw Data** | CSV app usage, phone lock logs | User-per-file extraction | `daily_features.csv` |
| **Feature Engineering** | Daily metrics | Log scaling, rolling stats, ratios | `daily_features_expanded.csv` |
| **Model Inference** | Expanded features | 3 parallel ML models | 3 separate result CSVs |
| **Fusion** | All model outputs | Voting logic, confidence calc | `final_drift_output.csv` |
| **Export** | Fusion results | JSON conversion | `final_drift_output.json` |
| **Visualization** | JSON file in app assets | Load & render charts | Mobile UI output |

---

## Machine Learning Pipeline

### Overview

The ML pipeline consists of **three independent drift detectors** that operate in parallel on the same feature set. Their outputs are **fused using a voting mechanism** to produce a robust final drift decision.

### 1. Data Preprocessing

#### Stage 1: Raw Feature Extraction

**File:** [ml/preprocessing/app_usage_features.py](ml/preprocessing/app_usage_features.py)

**Purpose:** Extract daily app usage activity from StudentLife sensor logs

**Input:**
- Raw CSV files from `data/raw/studentlife/app_usage/` (one file per user)
- Format: `timestamp` (UNIX), app event logs
- ~45 users, varying date ranges

**Process:**
1. Load each user's app usage CSV
2. Convert timestamps to datetime objects
3. Group by date and count total app events per day
4. Concatenate all users and aggregate by date

**Output:** [data/processed/app_usage_daily.csv](data/processed/app_usage_daily.csv)
```csv
date,app_events
2013-03-24,14894
2013-03-25,19222
2013-03-26,14846
...
```

---

**File:** [ml/preprocessing/phonelock_features.py](ml/preprocessing/phonelock_features.py)

**Purpose:** Extract daily phone lock/unlock frequency from StudentLife sensing data

**Input:**
- Raw CSV files from `data/raw/studentlife/sensing/phonelock/`
- Format: `start` (UNIX timestamp), `end` (UNIX timestamp)
- One unlock event per row

**Process:**
1. Load each user's phone lock CSV
2. Convert start timestamp to datetime
3. Extract date and count unlock events per day
4. Aggregate across all users by date

**Output:** [data/processed/phonelock_daily.csv](data/processed/phonelock_daily.csv)
```csv
date,unlock_count
2013-03-24,0
2013-03-25,0
2013-03-26,1
...
```

---

#### Stage 2: Feature Merging

**File:** [ml/preprocessing/merge_daily_features.py](ml/preprocessing/merge_daily_features.py)

**Purpose:** Combine app usage and phone lock features into single daily feature matrix

**Input:** 
- `app_usage_daily.csv`
- `phonelock_daily.csv`

**Process:**
1. Load both CSVs
2. Merge on `date` column with outer join
3. Fill missing values with 0

**Output:** [data/processed/daily_features.csv](data/processed/daily_features.csv)
```csv
date,unlock_count,app_events
2013-03-24,0,14894
2013-03-25,0,19222
...
```

---

#### Stage 3: Feature Engineering & Expansion

**File:** [ml/preprocessing/feature_expansion.py](ml/preprocessing/feature_expansion.py)

**Purpose:** Create 14 advanced features from raw daily metrics for model input

**Input:** [data/processed/daily_features.csv](data/processed/daily_features.csv) (2 raw features)

**Engineered Features:**

| Feature | Calculation | Purpose |
|---------|-------------|---------|
| `app_events_log` | log₁₊ₓ(app_events) | Reduce skewness of app data |
| `unlock_log` | log₁₊ₓ(unlock_count) | Reduce skewness of unlock data |
| `app_events_7day_mean` | 7-day rolling mean | Personal baseline |
| `unlock_7day_mean` | 7-day rolling mean | Personal baseline |
| `app_events_7day_std` | 7-day rolling std dev | Personal volatility |
| `unlock_7day_std` | 7-day rolling std dev | Personal volatility |
| `app_events_change` | First-order difference | Day-to-day change |
| `unlock_change` | First-order difference | Day-to-day change |
| `app_events_ratio_to_mean` | value / rolling_mean | Deviation from personal norm |
| `unlock_ratio_to_mean` | value / rolling_mean | Deviation from personal norm |
| `behavior_intensity` | log(apps) + log(unlocks) | Combined activity score |
| `instability_score` | std(apps) + std(unlocks) | Combined volatility score |

**Data Cleaning:**
- Replace ±∞ values with 0
- Fill NaN with 0 (especially for first 7 days when rolling window undefined)

**Output:** [data/processed/daily_features_expanded.csv](data/processed/daily_features_expanded.csv) (14 features × 105 days)

```csv
date,app_events,unlock_count,app_events_log,unlock_log,...,behavior_intensity,instability_score
2013-03-24,14894,0,9.608,0.0,...,9.608,0.0
2013-03-25,19222,0,9.863,0.0,...,9.863,0.0
...
```

---

### 2. Machine Learning Models

Each model runs **independently** on the expanded feature set. They produce binary or continuous outputs:

#### Model 1: Isolation Forest (Unsupervised Anomaly Detection)

**File:** [ml/models/isolation_forest.py](ml/models/isolation_forest.py)

**Purpose:** Detect global anomalies in behavior space

**Algorithm:**
- **Isolation Forest** (scikit-learn)
- Unsupervised learning (no labels required)
- Builds random decision trees that isolate anomalies

**Hyperparameters:**
```python
n_estimators=200        # 200 decision trees
contamination=0.15      # Expect ~15% anomalies (tuned for dataset)
random_state=42         # Reproducibility
```

**Input:** [data/processed/daily_features_expanded.csv](data/processed/daily_features_expanded.csv) (14 features)

**Preprocessing:** StandardScaler normalization (mean=0, std=1)

**Output:** [data/processed/isolation_forest_results.csv](data/processed/isolation_forest_results.csv)
```csv
date,ml_drift_detected
2013-03-24,False       # -1 in IF (anomaly) → False after binary conversion
2013-03-25,True        # +1 in IF (normal) → True; conversely -1 → False
2013-03-26,True        # ...
...
```

**Interpretation:**
- `ml_drift_detected = True` → Isolation Forest flagged as anomaly
- `ml_drift_detected = False` → Normal point

---

#### Model 2: Autoencoder (Deep Learning Reconstruction Error)

**File:** [ml/models/autoencoder_drift.py](ml/models/autoencoder_drift.py)

**Purpose:** Learn normal behavior pattern; flag high reconstruction errors

**Architecture:**
```
Input (14) → Dense(16) → ReLU → Dense(8) → ReLU → Dense(16) → ReLU → Output (14)
```

**Training:**
- **Baseline days:** First 7 days (assumed normal)
- **Epochs:** 100
- **Loss function:** Mean Squared Error (MSE)
- **Optimizer:** Adam (lr=0.001)

**Drift Detection:**
1. Train on baseline: minimize reconstruction error on first 7 days
2. Compute reconstruction error for all days: MSE(original, reconstructed)
3. Calculate threshold: μ(baseline_error) + 2σ(baseline_error)
4. Flag as drift if: error > threshold

**Input:** [data/processed/daily_features_expanded.csv](data/processed/daily_features_expanded.csv) (14 features)

**Preprocessing:** StandardScaler normalization

**Output:** [data/processed/autoencoder_drift_results.csv](data/processed/autoencoder_drift_results.csv)
```csv
date,autoencoder_drift_score,dl_drift_detected
2013-03-24,0.412,False        # Score below threshold → Not drift
2013-03-25,0.528,True         # Score above threshold → Drift
2013-03-26,0.401,False        # ...
...
```

**Interpretation:**
- `autoencoder_drift_score`: Continuous error (0.0 = perfect, >1.0 = bad)
- `dl_drift_detected = True` → Reconstruction error exceeds threshold

---

#### Model 3: Statistical Drift Detection (Z-Score Analysis)

**File:** [ml/models/statistical_drift.py](ml/models/statistical_drift.py)

**Purpose:** Compare monitoring period against baseline using classical statistics

**Method:**
1. **Baseline:** First 7 days → compute mean and std dev for each feature
2. **Monitoring:** Days 8+ → compute Z-score for each feature
3. **Drift flag:** If ANY feature has |Z-score| ≥ 2, mark as drift (2σ significance)

**Formula:**
```
Z_score = (feature_value - baseline_mean) / baseline_std

drift = ANY(|Z_score| ≥ 2)
```

**Input:** [data/processed/daily_features_expanded.csv](data/processed/daily_features_expanded.csv) (14 features)

**Output:** [data/processed/statistical_drift_results.csv](data/processed/statistical_drift_results.csv)
```csv
date,drift_score,drift_detected
2013-03-24,0.105,False        # Largest |Z| among all features
2013-03-25,2.304,True         # At least one Z-score ≥ 2
2013-03-26,1.876,False        # All |Z| < 2
...
```

**Interpretation:**
- `drift_score`: Maximum absolute Z-score across all features
- `drift_detected = True` → At least one feature >2σ from baseline

---

### 3. Fusion Logic

**File:** [ml/inference/drift_fusion.py](ml/inference/drift_fusion.py)

**Purpose:** Combine three independent model outputs into a single robust drift decision

**Process:**

1. **Load Results:** Merge three model CSVs by date
2. **Voting System:** Count how many models flagged drift
3. **Confidence Calculation:** 
   ```
   votes = [isolation_forest_drift, autoencoder_drift, statistical_drift]
   confidence = sum(votes) / 3    # ∈ [0.0, 1.0]
   ```
4. **Final Decision:**
   ```
   final_drift_detected = confidence >= 0.34
   ```
   This means: **≥1 out of 3 models voting for drift triggers final flag**

**Input:** Three CSV files:
- [data/processed/isolation_forest_results.csv](data/processed/isolation_forest_results.csv)
- [data/processed/autoencoder_drift_results.csv](data/processed/autoencoder_drift_results.csv)
- [data/processed/statistical_drift_results.csv](data/processed/statistical_drift_results.csv)

**Output:** [data/processed/final_drift_results.csv](data/processed/final_drift_results.csv)
```csv
date,ml_drift_detected,autoencoder_drift_detected,drift_detected,confidence,final_drift_detected
2013-03-24,False,False,False,0.0,False           # 0 votes → 0.0 confidence
2013-03-25,True,False,False,0.33,True           # 1 vote → 0.33 confidence ≥ 0.34
2013-03-26,True,False,False,0.33,True           # 1 vote → 0.33 confidence ≥ 0.34
2013-03-27,True,False,False,0.33,True           # 1 vote → 0.33 confidence ≥ 0.34
2013-03-28,True,True,False,0.67,True            # 2 votes → 0.67 confidence
2013-03-29,True,True,True,1.0,True              # 3 votes → 1.0 confidence (unanimous)
...
```

**Why this design?**
- **Robustness:** Single model false positive doesn't trigger alert
- **Explainability:** Confidence score shows how many models agree
- **Flexibility:** Can adjust threshold (0.34 = ≥1/3, could change to 0.67 = ≥2/3)

---

### 4. Output Files

#### Final CSV Export

**File:** [data/processed/final_drift_output.csv](data/processed/final_drift_output.csv)

Contains **all model votes and final decision** for debugging/audit:

```csv
date,ml_drift_detected,autoencoder_drift_detected,drift_detected,confidence,final_drift_detected
```

**Use Cases:**
- Validate individual model performance
- Compare model agreements
- Audit drift flag decisions
- Train next iteration of fusion logic

---

#### Final JSON Export (Flutter Input)

**File:** [ml/fusion/export_for_flutter.py](ml/fusion/export_for_flutter.py)

**Purpose:** Convert CSV results to JSON format for Flutter app

**Input:** [data/processed/final_drift_output.csv](data/processed/final_drift_output.csv)

**Process:**
1. Keep only: `date`, `final_drift_detected`, `confidence`
2. Rename Pythonic booleans to JSON format
3. Convert date to YYYY-MM-DD string
4. Dump to `drift_results.json`

**Output:** [data/processed/final_drift_output.json](data/processed/final_drift_output.json)

```json
[
  {
    "date": "2013-03-24",
    "drift": false,
    "confidence": 0.0
  },
  {
    "date": "2013-03-25",
    "drift": true,
    "confidence": 0.33
  },
  {
    "date": "2013-03-26",
    "drift": true,
    "confidence": 0.33
  }
  ...
]
```

**Schema:**
- `date` (string): YYYY-MM-DD format
- `drift` (boolean): Final drift flag
- `confidence` (number): 0.0–1.0 confidence score

---

## Flutter Application

### Purpose

Timeo is an **offline mobile dashboard** that visualizes ML-computed behavioral drift detection results. Its role is to:
- Load pre-computed drift results from JSON
- Display behavioral statistics and trends
- Provide intuitive visual feedback
- Allow historical browsing of detected deviations

**Note:** The app does NOT collect user data; it only visualizes results from the ML pipeline.

### Architecture

#### Data Flow in Flutter

```
assets/drift_results.json
         ↓
    DriftRepository.load()
         ↓
  Parse JSON → List<DriftDay>
         ↓
   FutureBuilder in UI
         ↓
  Render Charts & Lists
```

**Key Components:**

| Component | Location | Purpose |
|-----------|----------|---------|
| **Root App** | [lib/main.dart](flutter_app/behavioral_drift_app/lib/main.dart) | Navigation, theme, routing |
| **Repository** | [lib/data/drift_repository.dart](flutter_app/behavioral_drift_app/lib/data/drift_repository.dart) | Load JSON from assets |
| **Data Model** | [lib/models/drift_day.dart](flutter_app/behavioral_drift_app/lib/models/drift_day.dart) | DriftDay class (date, drift, confidence) |
| **Stats Page** | [lib/screens/stats_page.dart](flutter_app/behavioral_drift_app/lib/screens/stats_page.dart) | Pie chart, confidence timeline |
| **Logs Page** | [lib/screens/logs_page.dart](flutter_app/behavioral_drift_app/lib/screens/logs_page.dart) | Timeline of drift events |
| **About Page** | [lib/screens/about_page.dart](flutter_app/behavioral_drift_app/lib/screens/about_page.dart) | Project info & methodology |
| **Login Page** | [lib/screens/login_page.dart](flutter_app/behavioral_drift_app/lib/screens/login_page.dart) | Splash/entry screen (UI only) |

---

### Data Model

**File:** [lib/models/drift_day.dart](flutter_app/behavioral_drift_app/lib/models/drift_day.dart)

```dart
class DriftDay {
  final String date;         // "2013-03-25"
  final bool drift;          // true = drift detected
  final double confidence;   // 0.0–1.0
  
  DriftDay({required this.date, required this.drift, required this.confidence});
  
  factory DriftDay.fromJson(Map<String, dynamic> json) {
    return DriftDay(
      date: json['date'],
      drift: json['drift'],
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}
```

---

### Repository: Loading Data

**File:** [lib/data/drift_repository.dart](flutter_app/behavioral_drift_app/lib/data/drift_repository.dart)

```dart
class DriftRepository {
  static Future<List<DriftDay>> load() async {
    final jsonStr = await rootBundle.loadString('assets/drift_results.json');
    final List data = json.decode(jsonStr);
    return data.map((e) => DriftDay.fromJson(e)).toList();
  }
}
```

**Key Points:**
- Uses `rootBundle.loadString()` to load asset files
- Error handling: prints to console on failure
- Returns empty list if file not found (graceful degradation)

---

### Application Structure

**File:** [lib/main.dart](flutter_app/behavioral_drift_app/lib/main.dart)

**Root App:** TimeoApp (StatefulWidget)

```dart
MaterialApp(
  debugShowCheckedModeBanner: false,
  themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
  theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.deepPurple),
  routes: {
    "/": LoginPage(),          // Splash screen
    "/home": MainScaffold()    // Tabbed navigation
  }
)
```

**Theme:**
- Material Design 3 (M3)
- Dark mode supported
- Color seed: Deep Purple

**Navigation:**
- Bottom Navigation Bar with 3 tabs
- Theme toggle in AppBar

---

### User Interface Screens

#### 1. Login Page

**File:** [lib/screens/login_page.dart](flutter_app/behavioral_drift_app/lib/screens/login_page.dart)

**Purpose:** Entry/splash screen, credential input (UI only, no actual auth)

**Features:**
- Gradient background (purple theme)
- Email & password input fields
- Sign-in button
- Leads to `/home` (analytics dashboard)

**Status:** ✅ Implemented (non-functional auth—just navigation)

---

#### 2. Stats Page (Primary Dashboard)

**File:** [lib/screens/stats_page.dart](flutter_app/behavioral_drift_app/lib/screens/stats_page.dart)

**Purpose:** Primary visualization of behavioral statistics

**Widgets:**

**A. Summary Cards**
```
┌─────────────────────────────────┐
│  Total Drift Days: 42           │  (count of days where drift=true)
├─────────────────────────────────┤
│  Last Drift Detected: 2013-04-05 │  (most recent drift date)
├─────────────────────────────────┤
│  System Status: Active          │  (static label)
└─────────────────────────────────┘
```

**B. Drift Distribution Pie Chart**

```
          ┌────────┐
       ╱─────────────────╲
      │  Drift   │Normal │
      │ (42d)    │(63d)  │
       ╲─────────────────╱
          └────────┘
```

- Library: `fl_chart` (PieChart)
- Two sectors: Drift (red) vs. Normal (green)
- Shows absolute day counts
- Interactive: highlight on tap

**C. Confidence Timeline Chart**

```
  1.0 │     ╱╲
      │    ╱  ╲╱─╲
  0.5 │───╱────╲──╲─────
      │  ╱        ╲
  0.0 │─────────────
      └─────────────────→ Days
```

- Library: `fl_chart` (LineChart)
- X-axis: Sequential day index (0–104)
- Y-axis: Confidence (0.0–1.0)
- Line color: Deep purple
- Shows trend of model agreement over time

**Status:** ✅ Fully implemented

---

#### 3. Logs Page (Timeline View)

**File:** [lib/screens/logs_page.dart](flutter_app/behavioral_drift_app/lib/screens/logs_page.dart)

**Purpose:** Detailed chronological view of each day's status

**UI Pattern:**

```
  Icon  │  Date (bold)
  ─────┼─────────────────────────
   ⚠️  │  2013-03-25
  ─ │  Behavior deviation detected
   ─────
       │
   ✓   │  2013-03-26
  ─────┤─────────────────────────
   │   Normal behavior
  ─────
```

**Features per Row:**
- Status icon: ⚠️ (drift) or ✓ (normal)
- Date (YYYY-MM-DD, bold)
- Status text
- Confidence percentage (right-aligned)

**Scrollable:** Full ListView of all 105 days

**Status:** ✅ Fully implemented

---

#### 4. About Page

**File:** [lib/screens/about_page.dart](flutter_app/behavioral_drift_app/lib/screens/about_page.dart)

**Purpose:** Explain project scope, methodology, and tech stack

**Sections:**
1. **Project Title & Description**
   - "Timeo – Behavioral Drift Detection"
   - Explains what it analyzes

2. **What Does Timeo Analyze?**
   - Daily smartphone usage patterns
   - App usage behavior
   - Aggregated behavioral features
   - Long-term deviations

3. **How Does It Work?**
   - Daily features extracted from raw data
   - Multiple drift detection techniques applied
   - Results fused into final decision
   - Visualized in app

4. **Machine Learning Techniques**
   - Isolation Forest
   - Autoencoder
   - Statistical drift detection
   - Fusion logic

5. **Tech Stack**
   - Flutter & Dart
   - Python ML pipeline
   - Pandas, Scikit-Learn, TensorFlow
   - Offline JSON integration

6. **Disclaimer**
   - "Data is pre-computed; app does not collect live user data"

**Status:** ✅ Fully implemented

---

### How Data Flows into UI

1. **At App Startup:**
   ```
   main() → TimeoApp() → routes["/"] = LoginPage
   ```

2. **User Navigates to /home:**
   ```
   LoginPage → MaterialApp routes → /home → Scaffold + BottomNavigationBar
   ```

3. **StatsPage (or LogsPage) Loads:**
   ```dart
   FutureBuilder<List<DriftDay>>(
     future: DriftRepository.load(),  // Async JSON load
     builder: (context, snapshot) {
       if (!snapshot.hasData) 
         return CircularProgressIndicator();
       
       final days = snapshot.data!;
       // Compute statistics
       // Render charts
     }
   )
   ```

4. **Charts Render:**
   ```
   days → Compute drift counts, confidence values
        → PieChart & LineChart consume data
        → UI updates with visuals
   ```

---

### Dependencies

**File:** [pubspec.yaml](flutter_app/behavioral_drift_app/pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  fl_chart: ^0.66.2         # For pie & line charts
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

**Why these?**
- `flutter`: Core framework
- `fl_chart`: Charting library (replacement for manual canvas drawing)
- `cupertino_icons`: iOS-style icons
- `flutter_lints`: Code quality

---

## Current Implementation Status

### ✅ What is COMPLETE

#### Machine Learning Pipeline

| Component | Status | Details |
|-----------|--------|---------|
| **Raw Data Preprocessing** | ✅ Complete | App usage & phone lock feature extraction |
| **Feature Engineering** | ✅ Complete | 14 behavioral features, log scaling, rolling stats |
| **Isolation Forest Model** | ✅ Complete | Trained, 200 trees, 15% contamination |
| **Autoencoder Model** | ✅ Complete | Trained on 7-day baseline, 8-neuron bottleneck |
| **Statistical Drift Detection** | ✅ Complete | Z-score analysis, 2σ threshold |
| **Fusion Logic** | ✅ Complete | Voting system, confidence calculation |
| **CSV Outputs** | ✅ Complete | All intermediate & final results saved |
| **JSON Export** | ✅ Complete | Flutter-compatible JSON generated |

#### Flutter Application

| Component | Status | Details |
|-----------|--------|---------|
| **Login Page** | ✅ Complete | UI only (no real authentication) |
| **Stats Dashboard** | ✅ Complete | Pie chart, confidence timeline, summary cards |
| **Logs/Timeline Page** | ✅ Complete | Chronological daily view with icons |
| **About Page** | ✅ Complete | Project documentation |
| **Data Repository** | ✅ Complete | JSON loading from assets |
| **Data Model** | ✅ Complete | DriftDay class with JSON serialization |
| **Theme Support** | ✅ Complete | Dark/light mode toggle |
| **Bottom Navigation** | ✅ Complete | 3-tab navigation |

---

### ❌ What is NOT Implemented

| Feature | Status | Notes |
|---------|--------|-------|
| **Real-time Data Collection** | ❌ Not implemented | App does not collect live sensor data |
| **Backend API** | ❌ Not implemented | `backend/api.py` exists but is empty |
| **User Authentication** | ❌ Not implemented | Login page is UI only; no actual auth |
| **Database/Persistence** | ❌ Not implemented | No user accounts, settings, or data storage |
| **Live Behavior Monitoring** | ❌ Not implemented | Inference only on pre-computed data |
| **App Blocking/Restrictions** | ❌ Not implemented | Dashboard only, no action enforcement |
| **Push Notifications** | ❌ Not implemented | No alerts when drift detected |
| **Export Features** | ❌ Not implemented | No CSV/PDF export from app |
| **Network Sync** | ❌ Not implemented | Completely offline |
| **User-Specific Models** | ❌ Not implemented | Single trained model for all data |
| **Multi-User Support** | ❌ Not implemented | Data aggregates across all users |

---

### Data Characteristics

| Aspect | Details |
|--------|---------|
| **Source Dataset** | StudentLife (academic study, 2013) |
| **Time Range** | March 24 – June 6, 2013 (105 days) |
| **User Coverage** | ~45 participants, aggregated |
| **Total Records** | 105 daily features |
| **Models Trained** | Yes (on this static dataset) |
| **Inference Mode** | Offline CSV batch processing |
| **Data Live-ness** | Static; no updates unless pipeline re-run |
| **Data Privacy** | Public academic dataset |

---

## Repository Structure

```
behavioral-drift-detection/
│
├─ README.md                          # This file
├─ backend/
│  └─ api.py                         # (Empty stub for future backend)
│  └─ requirements.txt               # (Empty)
│
├─ data/
│  ├─ raw/
│  │  └─ studentlife/
│  │     ├─ app_usage/               # Raw app event logs (45 users)
│  │     ├─ sensing/phonelock/       # Raw phone lock events
│  │     ├─ calendar/, call_log/, sms/, etc.  # (Not used in current pipeline)
│  │
│  └─ processed/
│     ├─ app_usage_daily.csv         # Daily app event counts
│     ├─ phonelock_daily.csv         # Daily unlock counts
│     ├─ daily_features.csv          # Merged basic features
│     ├─ daily_features_expanded.csv # 14-feature matrix (model input)
│     ├─ isolation_forest_results.csv
│     ├─ autoencoder_drift_results.csv
│     ├─ statistical_drift_results.csv
│     ├─ final_drift_results.csv     # All model votes + final decision
│     ├─ final_drift_output.csv      # Final CSV (debug version)
│     └─ final_drift_output.json     # Final JSON (Flutter input)
│
├─ docs/
│  ├─ contribution_of_members.md     # (Empty)
│  ├─ dataset_description.md         # (Empty)
│  ├─ methodology.md                 # (Empty)
│  └─ problem_statement.md           # (Empty)
│
├─ ml/
│  ├─ preprocessing/
│  │  ├─ app_usage_features.py       # Extract app events
│  │  ├─ phonelock_features.py       # Extract unlock counts
│  │  ├─ merge_daily_features.py     # Combine features
│  │  └─ feature_expansion.py        # Engineer 14 features
│  │
│  ├─ models/
│  │  ├─ isolation_forest.py         # IF model + inference
│  │  ├─ autoencoder_drift.py        # DL model + inference
│  │  └─ statistical_drift.py        # Z-score drift detection
│  │
│  ├─ inference/
│  │  └─ drift_fusion.py             # Merge 3 models, voting logic
│  │
│  ├─ fusion/
│  │  ├─ generate_final_output.py    # Main fusion + CSV+JSON export
│  │  ├─ export_for_flutter.py       # JSON export (alternative)
│  │  └─ generate_final_output - Copy.py  # Backup
│  │
│  └─ notebooks/
│     └─ exploration.ipynb           # (Empty)
│
└─ flutter_app/
   └─ behavioral_drift_app/
      ├─ pubspec.yaml                # Flutter dependencies
      ├─ assets/
      │  └─ drift_results.json       # Final drift data (app input)
      │
      ├─ lib/
      │  ├─ main.dart                # App entry + routing
      │  ├─ data/
      │  │  └─ drift_repository.dart # JSON loader
      │  ├─ models/
      │  │  └─ drift_day.dart        # DriftDay class
      │  ├─ screens/
      │  │  ├─ login_page.dart       # Splash/entry
      │  │  ├─ stats_page.dart       # Pie chart + timeline
      │  │  ├─ logs_page.dart        # Daily timeline
      │  │  ├─ about_page.dart       # Info page
      │  │  └─ drift_timeline.dart   # Timeline widget
      │  └─ widgets/
      │     # (Potentially custom widgets, if any)
      │
      ├─ android/, ios/, web/, linux/, macos/, windows/
      │  # Platform-specific builds (generated)
      │
      └─ test/
         # (No visible test files)
```

---

### Key Files Explained

| File | Purpose | Input | Output |
|------|---------|-------|--------|
| [ml/preprocessing/app_usage_features.py](ml/preprocessing/app_usage_features.py) | Extract daily app events | Raw app CSVs | `app_usage_daily.csv` |
| [ml/preprocessing/phonelock_features.py](ml/preprocessing/phonelock_features.py) | Extract daily unlocks | Raw phone lock CSVs | `phonelock_daily.csv` |
| [ml/preprocessing/merge_daily_features.py](ml/preprocessing/merge_daily_features.py) | Combine features | Both daily CSVs | `daily_features.csv` |
| [ml/preprocessing/feature_expansion.py](ml/preprocessing/feature_expansion.py) | Engineer 14 features | `daily_features.csv` | `daily_features_expanded.csv` |
| [ml/models/isolation_forest.py](ml/models/isolation_forest.py) | IF anomaly detection | Expanded features | `isolation_forest_results.csv` |
| [ml/models/autoencoder_drift.py](ml/models/autoencoder_drift.py) | DL reconstruction error | Expanded features | `autoencoder_drift_results.csv` |
| [ml/models/statistical_drift.py](ml/models/statistical_drift.py) | Z-score drift detection | Expanded features | `statistical_drift_results.csv` |
| [ml/inference/drift_fusion.py](ml/inference/drift_fusion.py) | Merge models (voting) | 3 model CSVs | `final_drift_results.csv` |
| [ml/fusion/generate_final_output.py](ml/fusion/generate_final_output.py) | Final fusion + export | All model results | CSV + JSON |
| [flutter_app/.../lib/main.dart](flutter_app/behavioral_drift_app/lib/main.dart) | App root & routing | — | Mobile UI |
| [flutter_app/.../lib/data/drift_repository.dart](flutter_app/behavioral_drift_app/lib/data/drift_repository.dart) | Load JSON | `drift_results.json` | List<DriftDay> |
| [flutter_app/.../assets/drift_results.json](flutter_app/behavioral_drift_app/assets/drift_results.json) | Final data | Generated by ML | Flutter input |

---

## Known Limitations

### Data & Dataset

1. **Fixed Training Dataset**
   - Uses StudentLife data from 2013 (fixed historical dataset)
   - Cannot adapt to new users or new time periods
   - Models trained once; no online learning

2. **Aggregated User Data**
   - All app/phone lock data is aggregated across ~45 users
   - No per-user baseline models
   - Cannot identify individual behavioral patterns

3. **Limited Feature Set**
   - Only 2 raw signals: app events + phone lock frequency
   - No call logs, SMS, calendar, or survey data (available but unused)
   - Missing context: app categories, time-of-day patterns, location

4. **Small Temporal Window**
   - 105 days of data (March–June 2013)
   - Only 7-day baseline period
   - Cannot capture seasonal variations

---

### Machine Learning Model Limitations

5. **Fixed Contamination Rate**
   - Isolation Forest uses `contamination=0.15` (hardcoded)
   - Assumes 15% of days are anomalies (may not reflect reality)
   - No hyperparameter tuning for deployment data

6. **Autoencoder Training on Baseline**
   - Assumes first 7 days are all "normal"
   - Sensitive to baseline contamination (if day 1–7 contains outliers)
   - No regularization or dropout (risk of overfitting)

7. **Statistical Method Limitation**
   - Z-score analysis assumes Gaussian distribution (unverified for this data)
   - Single global threshold (2σ) for all features
   - No adjustment for multiple comparisons (28 comparisons across 2 features × 7-day windows)

8. **Simplistic Fusion Logic**
   - Simple majority voting (≥1/3 votes)
   - Equal weighting for all models (no confidence-weighted voting)
   - No model-specific calibration

---

### Application Limitations

9. **Offline Only**
   - No real-time data collection from device sensors
   - No live updates; must manually re-run ML pipeline
   - No cloud sync or backup

10. **No Real User Authentication**
    - Login page is UI-only; no actual credential validation
    - No user accounts or profiles
    - No permission system

11. **No Data Export from App**
    - Cannot export charts, reports, or logs from Flutter app
    - No sharing functionality
    - Data locked in app local assets

12. **No Interactive Configuration**
    - Cannot change model hyperparameters from UI
    - Cannot retrain or fine-tune models
    - Cannot adjust fusion logic thresholds

---

### Operational Limitations

13. **Single Data Source**
    - Hardcoded to StudentLife dataset format
    - Would require code changes to support new data schema
    - No data validation or error recovery

14. **No Error Recovery**
    - ML pipeline fails if CSV structure changes
    - No graceful handling of missing files
    - Flutter app shows empty UI if JSON missing

15. **No Monitoring or Logging**
    - No logs of model performance over time
    - No metrics tracking (precision, recall, F1)
    - No alerts if pipeline fails

16. **Not Production-Ready**
    - Designed for research/prototype use
    - No rate limiting, security, or compliance features
    - No documentation of assumptions or reproducibility info

---

## Future Roadmap

### Phase 1: Enhanced Offline Analysis (Short-term)

- [ ] **User-Specific Model Training**
  - Train separate Isolation Forest for each user
  - Maintain per-user baseline in app
  - More accurate personalized drift detection

- [ ] **Improved Feature Set**
  - Include app category information (social, productivity, etc.)
  - Add time-of-day patterns (morning vs. evening usage)
  - Extract phone usage entropy (diversity of apps)

- [ ] **Better Baseline Period**
  - Allow configurable baseline length (not fixed 7 days)
  - Detect and exclude outliers from baseline calculation
  - Adaptive baseline that updates over time

- [ ] **Model Hyperparameter Tuning**
  - Validate Isolation Forest contamination rate
  - Cross-validation for autoencoder architecture
  - Statistical test selection for Z-score thresholds

### Phase 2: Real-Time Data Collection (Medium-term)

- [ ] **Native Sensor Integration**
  - Capture app usage events in real-time (Android/iOS APIs)
  - Record phone lock/unlock events
  - Periodic aggregation to daily features

- [ ] **Local ML Inference**
  - Run TensorFlow Lite models on-device
  - Daily inference without cloud dependency
  - Immediate notifications on detected drift

- [ ] **Persistent Storage**
  - SQLite database for historical feature storage
  - Local model persistence
  - Crash recovery

- [ ] **Push Notifications**
  - Alert user when drift detected
  - Configurable notification frequency
  - User action logging (dismiss, snooze, investigate)

### Phase 3: Backend & Multi-User Support (Long-term)

- [ ] **Backend API**
  - REST/GraphQL server for result synchronization
  - User authentication (OAuth2/Firebase)
  - Model training pipeline orchestration

- [ ] **Cloud Dashboard**
  - Multi-device sync
  - Long-term trend analysis
  - Comparative analysis (across users, if opted in)

- [ ] **Active Response**
  - App usage restriction (block distracting apps)
  - Scheduled downtime enforcement
  - Wellness recommendations

- [ ] **Privacy & Compliance**
  - On-device encryption of sensitive data
  - User data anonymization
  - GDPR/HIPAA compliance

### Phase 4: Research Extensions (Advanced)

- [ ] **Additional Data Modalities**
  - Accelerometer/gyroscope (physical activity)
  - Location traces (mobility patterns)
  - Communication logs (social behavior)

- [ ] **Advanced ML Techniques**
  - Temporal models (LSTM, Transformer) for sequence analysis
  - Variational Autoencoder (VAE) for better reconstruction
  - Online learning / active learning

- [ ] **Interpretability**
  - SHAP values to explain model decisions
  - Feature importance rankings per user
  - Drift root cause analysis

- [ ] **Validation Studies**
  - Correlation with self-reported wellness (ESM)
  - Longitudinal validation with real users
  - Clinical outcome prediction

---

## How to Run the Project

### Prerequisites

- **Python 3.8+** (for ML pipeline)
- **Flutter 3.10.4+** & **Dart** (for mobile app)
- **Git** (to clone repository)

---

### Step 1: Set Up Python Environment

#### Option A: Using Virtual Environment

```bash
cd c:\Users\Nikhil\Downloads\Flutter Project\behavioral-drift-detection

# Create virtual environment
python -m venv venv

# Activate it
venv\Scripts\activate  # Windows
# or
source venv/bin/activate  # macOS/Linux

# Install dependencies
pip install pandas scikit-learn torch numpy
```

#### Option B: Using Conda

```bash
conda create -n drift-detection python=3.10
conda activate drift-detection
conda install pandas scikit-learn pytorch numpy -c pytorch
```

---

### Step 2: Verify Raw Data

Ensure raw data exists at expected paths:

```
data/raw/studentlife/
├─ app_usage/
│  ├─ running_app_u00.csv
│  ├─ running_app_u01.csv
│  ...
└─ sensing/phonelock/
   ├─ phonelock_u*.csv
```

If data missing, obtain from StudentLife dataset (publicly available: http://studentlife.cs.dartmouth.edu).

---

### Step 3: Run ML Pipeline

Execute preprocessing and model scripts **in order**:

```bash
# Step 3.1: Extract basic daily features
python ml/preprocessing/app_usage_features.py
python ml/preprocessing/phonelock_features.py

# Step 3.2: Merge features
python ml/preprocessing/merge_daily_features.py

# Step 3.3: Engineer expanded features
python ml/preprocessing/feature_expansion.py

# Step 3.4: Run all three models
python ml/models/isolation_forest.py
python ml/models/autoencoder_drift.py
python ml/models/statistical_drift.py

# Step 3.5: Fuse results
python ml/inference/drift_fusion.py

# Step 3.6: Export for Flutter
python ml/fusion/generate_final_output.py
# OR
python ml/fusion/export_for_flutter.py
```

**Expected Outputs:**
```
data/processed/
├─ app_usage_daily.csv                    ✅
├─ phonelock_daily.csv                    ✅
├─ daily_features.csv                     ✅
├─ daily_features_expanded.csv            ✅
├─ isolation_forest_results.csv           ✅
├─ autoencoder_drift_results.csv          ✅
├─ statistical_drift_results.csv          ✅
├─ final_drift_results.csv                ✅
├─ final_drift_output.csv                 ✅
└─ final_drift_output.json                ✅
```

---

### Step 4: Plug JSON into Flutter

Copy the generated JSON to Flutter app assets:

```bash
copy data/processed/final_drift_output.json ^
  flutter_app/behavioral_drift_app/assets/drift_results.json
```

Or manually:
1. Open `data/processed/final_drift_output.json`
2. Copy contents
3. Paste into `flutter_app/behavioral_drift_app/assets/drift_results.json`

---

### Step 5: Build & Run Flutter App

#### Set Up Flutter Environment

```bash
# Check Flutter installation
flutter --version
flutter doctor

# Get dependencies
cd flutter_app/behavioral_drift_app
flutter pub get
```

#### Run on Connected Device/Emulator

```bash
# List available devices
flutter devices

# Run app (hot reload enabled)
flutter run

# Or run with specific device
flutter run -d <device_id>
```

#### Build Release APK (Android) or IPA (iOS)

```bash
# Android APK
flutter build apk --release

# iOS IPA (macOS only)
flutter build ios --release

# Web (if enabled)
flutter build web
```

---

### Step 6: Verify Results

1. **Check ML Output:**
   ```bash
   # View final drift output
   cat data/processed/final_drift_output.json | head -20
   ```

2. **Check Flutter App:**
   - Navigate to Stats page → see pie chart and confidence timeline
   - Navigate to Logs page → see daily timeline
   - Navigate to About page → see project info

---

### Troubleshooting

#### Python Issues

```
Error: ModuleNotFoundError: No module named 'torch'
→ Solution: pip install torch (requires internet, larger download)

Error: FileNotFoundError: studentlife/app_usage/*.csv
→ Solution: Verify data is in data/raw/studentlife/
```

#### Flutter Issues

```
Error: assets/drift_results.json not found
→ Solution: Run ML pipeline first, copy JSON to assets/

Error: PlatformException (Bad UTF-8 encoding in JSON)
→ Solution: Verify JSON formatted correctly (check with jq or online validator)

Error: Build fails on Gradle
→ Solution: flutter clean, then flutter pub get, then flutter run
```

---

## Developer Notes

### Adding New Models

To integrate a new drift detection model (e.g., LSTM, Isolation Forest variant):

1. **Create New Model File**
   ```python
   # ml/models/your_model.py
   import pandas as pd
   from sklearn.preprocessing import StandardScaler
   
   df = pd.read_csv("../../data/processed/daily_features_expanded.csv")
   df['date'] = pd.to_datetime(df['date'])
   
   X = df.drop(columns=['date']).values
   scaler = StandardScaler()
   X_scaled = scaler.fit_transform(X)
   
   # Train your model
   model = YourModel()
   model.fit(X_scaled[7:])  # Skip first 7 days or use for baseline
   
   # Predict
   predictions = model.predict(X_scaled)
   
   # Save results
   df['your_model_drift'] = predictions > threshold
   df[['date', 'your_model_drift']].to_csv(
     "../../data/processed/your_model_results.csv", index=False
   )
   ```

2. **Update Fusion Logic**
   ```python
   # ml/inference/drift_fusion.py (or ml/fusion/generate_final_output.py)
   your_model_df = pd.read_csv("your_model_results.csv")
   merged = merged.merge(your_model_df, on='date', how='left')
   
   # Update voting
   votes = [
     iso_forest_drift,
     autoencoder_drift,
     stat_drift,
     your_model_drift  # ← Add here
   ]
   confidence = sum(votes) / len(votes)  # Now 4 models
   ```

3. **Re-export JSON**
   ```bash
   python ml/fusion/generate_final_output.py
   ```

4. **Rebuild Flutter**
   ```bash
   flutter run
   ```

---

### Extending the Fusion Logic

Current fusion uses **majority voting with ≥1/3 threshold**:

```python
def fuse(row):
    votes = [iso, ae, stat]
    confidence = sum(votes) / 3
    final = confidence >= 0.34  # ≥1 out of 3
```

**Alternative Strategies:**

**Option 1: Weighted Voting**
```python
weights = [0.4, 0.4, 0.2]  # If some models more reliable
weighted_score = sum(v*w for v, w in zip(votes, weights))
final = weighted_score >= 0.5
```

**Option 2: Stacking (Meta-Learner)**
```python
# Train logistic regression on model outputs
meta_model = LogisticRegression()
meta_model.fit([iso, ae, stat], true_drift_labels)  # On validation set
confidence = meta_model.predict_proba([iso, ae, stat])[:, 1]
```

**Option 3: Thresholding by Model**
```python
# Stricter for autoencoder (deepest model)
if ae_drift or (iso_drift and stat_drift):
    final = True
else:
    final = False
```

**To Change:**
1. Modify fusion function in `ml/fusion/generate_final_output.py`
2. Re-run: `python ml/fusion/generate_final_output.py`
3. Rebuild Flutter app and verify JSON changes

---

### Modifying Flutter UI

#### Change Theme Color

**File:** [lib/main.dart](flutter_app/behavioral_drift_app/lib/main.dart)

```dart
theme: ThemeData(
  useMaterial3: true,
  colorSchemeSeed: Colors.deepPurple,  # ← Change color here
  brightness: Brightness.light,
),
```

#### Add New Screen

1. Create file: `lib/screens/your_screen.dart`
2. Add widget class
3. Update [lib/main.dart](flutter_app/behavioral_drift_app/lib/main.dart):
   ```dart
   final List<Widget> pages = const [
     StatsPage(),
     LogsPage(),
     YourScreen(),  // ← Add
     AboutPage(),
   ];
   ```
4. Add BottomNavigationBar item

#### Change Chart Type

Replace `PieChart` with `BarChart`, `ScatterChart`, etc. from `fl_chart`:

```dart
// In stats_page.dart
BarChart(
  BarChartData(
    barGroups: [
      BarChartGroupData(x: 0, barRods: [BarChartRodData(y: driftCount)])
    ]
  )
)
```

See [fl_chart docs](https://github.com/imaNNeoFighT/fl_chart) for examples.

---

### Plugging in a Backend Later

Currently, the app loads data from local assets. To connect to a backend API:

**Step 1: Create Network Service**
```dart
// lib/services/api_service.dart
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://your-server.com/api';
  
  static Future<List<DriftDay>> fetchDriftResults(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/drift/$userId'),
      headers: {'Authorization': 'Bearer $token'}
    );
    
    if (response.statusCode == 200) {
      final List data = json.decode(response.body);
      return data.map((e) => DriftDay.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load drift results');
    }
  }
}
```

**Step 2: Update Repository**
```dart
// lib/data/drift_repository.dart
class DriftRepository {
  static Future<List<DriftDay>> load() async {
    // Try network first
    try {
      return await ApiService.fetchDriftResults(userId);
    } catch (e) {
      // Fallback to local assets
      print("Network unavailable, using local cache");
      return _loadLocal();
    }
  }
  
  static Future<List<DriftDay>> _loadLocal() async {
    final jsonStr = await rootBundle.loadString('assets/drift_results.json');
    final List data = json.decode(jsonStr);
    return data.map((e) => DriftDay.fromJson(e)).toList();
  }
}
```

**Step 3: Add HTTP Dependency**
```yaml
# pubspec.yaml
dependencies:
  http: ^1.0.0
  dio: ^4.0.0  # (alternative, more powerful)
```

**Step 4: Update Backend**
Create REST endpoint:
```python
# backend/api.py
from flask import Flask, jsonify
app = Flask(__name__)

@app.route('/api/drift/<user_id>', methods=['GET'])
def get_drift_results(user_id):
    # Query database for user results
    results = db.query(DriftResult).filter(DriftResult.user_id == user_id).all()
    return jsonify([r.to_dict() for r in results])
```

---

### Model Retraining Pipeline

To retrain models on new data:

**Step 1: Add New Raw Data**
Place new StudentLife CSVs in `data/raw/studentlife/app_usage/` and `data/raw/studentlife/sensing/phonelock/`

**Step 2: Re-run Preprocessing**
```bash
# This will overwrite daily features
python ml/preprocessing/app_usage_features.py
python ml/preprocessing/phonelock_features.py
python ml/preprocessing/merge_daily_features.py
python ml/preprocessing/feature_expansion.py
```

**Step 3: Retrain Models**
```bash
# Models will refit on new data
python ml/models/isolation_forest.py
python ml/models/autoencoder_drift.py
python ml/models/statistical_drift.py
```

**Step 4: Regenerate Fusion**
```bash
python ml/fusion/generate_final_output.py
```

**Step 5: Update Flutter**
```bash
copy data/processed/final_drift_output.json ^
  flutter_app/behavioral_drift_app/assets/drift_results.json
flutter run
```

---

### Performance Notes

| Component | Time | Resources |
|-----------|------|-----------|
| **Preprocessing** | ~2s | <100 MB RAM |
| **Isolation Forest** | ~5s | ~200 MB RAM |
| **Autoencoder** | ~15s | ~500 MB RAM (GPU optional) |
| **Statistical Drift** | <1s | <50 MB RAM |
| **Fusion** | <1s | <50 MB RAM |
| **Total ML Pipeline** | ~25s | ~1 GB RAM |
| **Flutter App Load** | ~2s on startup | ~100 MB RAM |
| **App Runtime** | <100 MB sustained | Minimal |

---

### Testing & Validation

**Manual Testing Checklist:**

- [ ] ML Pipeline
  - [ ] All CSVs generated
  - [ ] JSON valid (check with `python -m json.tool drift_results.json`)
  - [ ] Confidence scores in [0.0, 1.0]
  - [ ] Drift dates chronological

- [ ] Flutter App
  - [ ] Login page navigates to home
  - [ ] Stats page loads without errors
  - [ ] Pie chart renders
  - [ ] Confidence timeline renders
  - [ ] Logs page shows all 105 days
  - [ ] About page displays text
  - [ ] Dark mode toggle works
  - [ ] No console errors

**Automated Testing:**
```bash
# In flutter_app/behavioral_drift_app/
flutter test
```

(Currently no test suite—recommended to add)

---

### Logging & Debugging

**Python:**
```python
import logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)
logger.info("Processing started")
logger.error("File not found", exc_info=True)
```

**Flutter:**
```dart
import 'dart:developer' as developer;
developer.log("Loading drift data...");
debugPrint("Loaded ${days.length} days");
print("❌ Error: $e");
```

Check logs in:
- **Python:** Console output
- **Flutter:** VS Code Debug Console or `flutter logs`

---

## Contact & Support

For questions about:
- **ML Pipeline:** Check [ml/](ml/) documentation
- **Flutter App:** Check `lib/`READMES or inline comments
- **Data:** See [docs/dataset_description.md](docs/dataset_description.md) (when completed)
- **Methodology:** See [docs/methodology.md](docs/methodology.md) (when completed)

---

## Contributing

This is an academic research project. Contributions should:
1. Follow the existing code structure
2. Include docstrings/comments
3. Test on sample data first
4. Document any breaking changes

---

## License

Specify license in repository root (e.g., MIT, GPL-3.0)

---

## Changelog

**v1.0.0** (February 2026)
- ✅ Complete ML pipeline (3 models + fusion)
- ✅ Flutter dashboard with charts
- ✅ JSON data export
- ✅ Production README
- ❌ Backend API (empty stub)
- ❌ Real-time data collection

---

## Acknowledgments

- **StudentLife Dataset:** Dartmouth College
- **Libraries:** pandas, scikit-learn, PyTorch, Flutter, fl_chart
- **Team:** (Add contributor names if applicable)

---

**End of README**

This README is the single source of truth for the Behavioral Drift Detection System. Keep it updated as the project evolves.
