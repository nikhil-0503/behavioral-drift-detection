# 📱 Behavioral Drift Detection System

> A comprehensive mobile application and machine learning system for detecting behavioral drift in smartphone users

## 🎯 Overview

Behavioral Drift Detection is an intelligent system that monitors and detects significant changes in smartphone user behavior patterns. By analyzing mobile device usage data, the system can identify when a user's daily habits deviate from their established baseline, which can indicate important life events, health concerns, or security issues.

This project combines a **Flutter mobile application** for data collection and real-time monitoring with a **Python ML backend** for sophisticated behavioral analysis using multiple detection algorithms.

---

## ❓ Why Behavioral Drift Detection?

### Problem Statement
Smartphones have become ubiquitous, and smartphone usage patterns reflect our daily routines, mental health, social interactions, and overall well-being. Detecting significant deviations from a user's normal behavior can be valuable for:

- **Health Monitoring**: Identifying potential health issues through changes in sleep patterns or app usage
- **Mental Health**: Detecting depression, anxiety, or stress through unusual behavioral changes
- **Security**: Identifying compromised accounts or unauthorized device usage
- **Research**: Understanding behavioral patterns in large populations
- **Personal Insights**: Understanding personal habits and lifestyle changes

This system automates behavioral drift detection, making it practical for widespread deployment.

---

## 🔬 How It Works

### System Architecture

The system operates in three main phases:

```
Data Collection (Flutter App)
        ↓
    Data Processing & Feature Engineering (ML Pipeline)
        ↓
    Multiple Drift Detection Algorithms
        ↓
    Results Fusion & Visualization (Flutter App)
```

### Detection Algorithms

The system employs **three complementary approaches** for robust drift detection:

#### 1. **Statistical Drift Detection**
- Establishes baseline statistics (mean, std) from first 7 days
- Uses Z-score analysis to detect anomalies
- Flags when feature values deviate by 2+ standard deviations
- **Advantage**: Simple, interpretable, no model training needed

#### 2. **Isolation Forest**
- Unsupervised anomaly detection algorithm
- Isolates anomalous behavior patterns
- Learns normal behavior from baseline period
- **Advantage**: Detects complex multivariate anomalies

#### 3. **Autoencoder (Deep Learning)**
- Neural network-based reconstruction approach
- Learns to compress and reconstruct normal behavior
- High reconstruction error indicates anomalies
- **Advantage**: Captures non-linear relationships in behavior

### Feature Engineering

The system extracts behavioral features from raw sensor data:

- **App Usage**: Most used apps, app switching frequency, total screen time
- **Communication**: Call frequency/duration, SMS count
- **Lock/Unlock**: Phone lock patterns, usage intensity
- **Calendar**: Event frequency, meeting patterns
- **Location**: Movement patterns, visited places

---

## 📊 Dataset

The system includes support for comprehensive mobile sensing data:

### Data Sources
- **App Usage**: Running apps per user
- **Calibration Data**: Device calibration timestamps
- **Call Logs**: Incoming/outgoing call records
- **Dining Patterns**: Location-based eating data
- **Education**: Educational activity data
- **EMA (Experience Sampling)**: User-reported experiences
- **Sensing**: Raw sensor readings
- **SMS**: Text message logs
- **StudentLife Survey**: Long-term user surveys
- **Calendar Events**: Schedule information

### Processed Output
- Daily aggregated features
- Drift detection results (statistical, Isolation Forest, Autoencoder)
- Fused final predictions
- JSON outputs for app consumption

---

## 🛠 Technology Stack

### Backend
- **Framework**: FastAPI (Python web framework)
- **Machine Learning**: Scikit-learn, PyTorch, NumPy, Pandas
- **Database Ready**: Supporting JSON outputs for mobile integration
- **API Server**: Uvicorn (ASGI server)

### Frontend
- **Framework**: Flutter (Cross-platform mobile)
- **UI Components**: Material Design, FL Chart library
- **State Management**: Provider pattern
- **Database**: SQLite (local persistence)
- **Authentication**: Firebase Auth with Google Sign-In
- **Real-time Features**: Flutter integration with ML models

### Development Environment
- Python 3.10+
- Dart/Flutter SDK 3.10.4+
- Deep learning support via PyTorch

---

## 📁 Project Structure

```
behavioral-drift-detection/
├── backend/                          # FastAPI backend server
│   ├── api.py                       # Main API endpoints
│   ├── requirements.txt             # Python dependencies
│   └── __pycache__/
│
├── ml/                              # Machine Learning pipeline
│   ├── models/
│   │   ├── statistical_drift.py    # Statistical analysis
│   │   ├── isolation_forest.py     # Isolation Forest model
│   │   └── autoencoder_drift.py    # Deep learning model
│   ├── preprocessing/
│   │   ├── app_usage_features.py   # App usage feature extraction
│   │   ├── phonelock_features.py   # Phone unlock pattern features
│   │   ├── feature_expansion.py    # Feature engineering
│   │   └── merge_daily_features.py # Aggregation
│   ├── inference/
│   │   └── drift_fusion.py         # Model prediction fusion
│   ├── fusion/
│   │   ├── export_for_flutter.py   # Export results for app
│   │   └── generate_final_output.py # Final result generation
│   └── notebooks/
│       └── exploration.ipynb        # Data exploration
│
├── flutter_app/                     # Mobile application
│   └── behavioral_drift_app/
│       ├── lib/
│       │   ├── main.dart           # App entry point
│       │   ├── screens/            # UI screens
│       │   ├── models/             # Data models
│       │   ├── services/           # API & Backend services
│       │   ├── widgets/            # Reusable widgets
│       │   ├── data/               # Local data access
│       │   ├── config/             # Configuration
│       │   └── firebase_options.dart # Firebase config
│       ├── android/                # Android configuration
│       ├── ios/                    # iOS configuration
│       ├── web/                    # Web configuration
│       ├── linux/                  # Linux configuration
│       ├── macos/                  # macOS configuration
│       ├── windows/                # Windows configuration
│       ├── assets/                 # Images & resources
│       ├── pubspec.yaml            # Flutter dependencies
│       └── test/                   # Flutter tests
│
├── data/
│   ├── raw/                        # Raw sensor data
│   │   ├── app_usage/             # App usage CSVs
│   │   ├── calendar/              # Calendar events
│   │   ├── call_log/              # Call records
│   │   ├── sms/                   # Text messages
│   │   └── ...                    # Other sensors
│   └── processed/                  # Processed outputs
│       ├── daily_features.csv      # Daily behavioral features
│       ├── statistical_drift_results.csv
│       ├── isolation_forest_results.csv
│       ├── autoencoder_drift_results.csv
│       └── final_drift_output.json # Final fused results
│
└── docs/                           # Documentation
    ├── problem_statement.md
    ├── methodology.md
    ├── dataset_description.md
    └── contribution_of_members.md
```

---

## 🚀 Getting Started

### Prerequisites

Before you begin, ensure you have the following installed:

- **Python 3.10 or higher**
- **Flutter SDK 3.10.4 or higher**
- **Git**
- **A code editor** (VS Code, Android Studio, or similar)

#### System Requirements
- **OS**: Windows, macOS, or Linux
- **RAM**: Minimum 4GB (8GB recommended for ML model training)
- **Disk Space**: 2GB for dependencies and data

### Installation

#### Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/behavioral-drift-detection.git
cd behavioral-drift-detection
```

#### Step 2: Set Up Backend (Python/ML)

##### 2.1 Create Python Virtual Environment

```bash
# Windows
python -m venv venv
venv\Scripts\activate

# macOS/Linux
python3 -m venv venv
source venv/bin/activate
```

##### 2.2 Install Python Dependencies

```bash
pip install --upgrade pip
cd backend
pip install -r requirements.txt
```

##### 2.3 Verify Installation

```bash
python -c "import fastapi, torch, pandas, sklearn; print('✅ All dependencies installed!')"
```

#### Step 3: Set Up ML Pipeline

The ML models are located in the `ml/` directory. They can be run independently or through the FastAPI backend.

```bash
# From project root
cd ml/preprocessing
python merge_daily_features.py          # Aggregate daily features
```

#### Step 4: Set Up Flutter Application

##### 4.1 Navigate to Flutter App

```bash
cd flutter_app/behavioral_drift_app
```

##### 4.2 Get Flutter Dependencies

```bash
flutter pub get
```

##### 4.3 Configure Firebase (Optional but Recommended)

Update Firebase configuration in `lib/firebase_options.dart` with your Firebase project credentials.

##### 4.4 Run the App

**On Emulator/Simulator:**
```bash
flutter run
```

**On Physical Device:**
```bash
# First, ensure your device is connected
flutter devices
flutter run
```

---

## 📖 How to Use

### Running the Backend API

```bash
cd backend
uvicorn api:app --reload --port 8000
```

The API will be available at `http://localhost:8000`

**API Documentation**: Navigate to `http://localhost:8000/docs` for interactive Swagger UI

### Key API Endpoints

```
POST   /analyze          - Run drift detection analysis
GET    /results          - Fetch latest drift detection results
GET    /health          - Health check
GET    /models/status   - Model status information
```

### Using the Flutter Application

1. **Launch the app** on your device/emulator
2. **Sign in** using your Google account (Firebase Auth)
3. **Grant permissions** for data collection (if applicable)
4. **View Dashboard**: See real-time behavioral drift alerts
5. **Explore Patterns**: View your behavioral patterns over time
6. **Check Alerts**: Review any detected behavioral drift events

### Running ML Pipeline Manually

```bash
# Feature Engineering
cd ml/preprocessing
python app_usage_features.py
python phonelock_features.py
python feature_expansion.py
python merge_daily_features.py

# Model Training & Inference
cd ml/models
python statistical_drift.py
python isolation_forest.py
python autoencoder_drift.py

# Fusion (Combine results from all 3 models)
cd ml/inference
python drift_fusion.py

# Export for Flutter
cd ml/fusion
python export_for_flutter.py
```

### Expected Workflow

```
1. Data Collection
   └─ Flask app collects sensor data from phones

2. Feature Engineering
   └─ Extract behaviors from raw data

3. Model Training & Inference
   └─ Statistical Analysis / Isolation Forest / Autoencoder

4. Results Fusion
   └─ Combine predictions from multiple models

5. Export & Visualization
   └─ Results available in Flutter app via API
```

---

## 📊 Understanding Results

### Output Files

#### CSV Results
- **statistical_drift_results.csv**: Z-score based detection
- **isolation_forest_results.csv**: Anomaly scores
- **autoencoder_drift_results.csv**: Reconstruction error

#### Fusion Output
- **final_drift_output.csv**: Combined prediction from all 3 models
- **final_drift_output.json**: JSON format for API consumption

### Result Interpretation

**Drift Score**: 0.0 - 1.0 (higher = more drift)
- 0.0 - 0.3: Normal behavior
- 0.3 - 0.7: Moderate drift
- 0.7 - 1.0: Significant drift detected

**Drift Flags**: Boolean (true/false)
- `true`: Behavioral drift detected
- `false`: Behavior within normal baseline

---

## 🔧 Configuration

### Backend Configuration

Edit `backend/api.py` to configure:

```python
# API Port
HOST = "0.0.0.0"
PORT = 8000

# CORS settings
allow_origins = ["*"]  # Restrict in production

# Model paths
MODEL_PATH = "path/to/models"
DATA_PATH = "path/to/data"
```

### Flutter Configuration

Edit `flutter_app/behavioral_drift_app/lib/config/app_config.dart` to configure:

```dart
const String API_BASE_URL = "http://localhost:8000";
const int API_TIMEOUT_SECONDS = 30;
const int SYNC_INTERVAL_MINUTES = 60;
```

---

## 🧪 Testing

### Backend Tests

```bash
cd backend
pytest tests/
```

### Flutter Tests

```bash
cd flutter_app/behavioral_drift_app
flutter test
```

---

## 📈 Performance Considerations

- **Statistical Drift**: Fast, minimal computation
- **Isolation Forest**: Moderate speed, scales well
- **Autoencoder**: Slower, requires GPU for optimal performance
- **Fusion**: Combines predictions efficiently

### Optimization Tips

1. Use GPU acceleration for autoencoder (PyTorch + CUDA)
2. Cache processed features to avoid recomputation
3. Use batch processing for multiple users
4. Implement incremental learning for streaming data

---

## 🤝 Contributing

We welcome contributions! Please follow these steps:

### How to Contribute

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** changes (`git commit -m 'Add amazing-feature'`)
4. **Push** to branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Contribution Guidelines

- Follow PEP 8 (Python) and Dart style guides
- Add tests for new features
- Update documentation
- Keep commits atomic and descriptive

---

## 🐛 Troubleshooting

### Backend Issues

**Port Already in Use**
```bash
# Change port in api.py or
lsof -i :8000  # Find process
kill -9 <PID>  # Kill process
```

**Models Not Loading**
- Check file paths in `backends/api.py`
- Ensure all required packages are installed

### Flutter Issues

**Dependency Conflicts**
```bash
flutter clean
flutter pub get
flutter pub upgrade
```

**Firebase Authentication Issues**
- Verify Firebase project credentials
- Check internet connectivity
- Review Firebase console console for errors

### Common Errors

| Error | Solution |
|-------|----------|
| `ModuleNotFoundError: No module named 'torch'` | `pip install torch` |
| `ConnectionRefusedError` | Ensure backend API is running on correct port |
| `CORS error` | Check API CORS configuration |
| `Device not found` | Connect device and run `flutter devices` |

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 📞 Support & Contact

### Questions or Issues?

- **GitHub Issues**: [Open an issue](https://github.com/yourusername/behavioral-drift-detection/issues)
- **Email**: your-email@example.com
- **Documentation**: See `docs/` folder

### References

- [Flutter Documentation](https://flutter.dev/docs)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Scikit-learn](https://scikit-learn.org/)
- [PyTorch](https://pytorch.org/)

---

## 🎓 Academic Information

**Course**: Mobile Application Development Lab
**Level**: Third Year, 6th Semester

**Team Members**: See [contribution_of_members.md](docs/contribution_of_members.md)

---

## 🎉 Acknowledgments

- Flutter and FastAPI community
- Open-source ML libraries (scikit-learn, PyTorch, pandas)
- Firebase for authentication and backend services
- All contributors and testers

---

<div align="center">

**Made with ❤️ by the Behavioral Drift Detection Team**

[⭐ Star us on GitHub](https://github.com/yourusername/behavioral-drift-detection) | [🐛 Report Issues](https://github.com/yourusername/behavioral-drift-detection/issues)

</div>
