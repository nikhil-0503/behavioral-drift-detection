import pandas as pd
from sklearn.ensemble import IsolationForest
from sklearn.preprocessing import StandardScaler
import os

# Get project root directory
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

data_path = os.path.join(
    BASE_DIR,
    "data",
    "processed",
    "daily_features_expanded.csv"
)

df = pd.read_csv(data_path)
df['date'] = pd.to_datetime(df['date'])

X = df.drop(columns=['date'])

scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

iso_forest = IsolationForest(
    n_estimators=200,
    contamination=0.15,
    random_state=42
)

preds = iso_forest.fit_predict(X_scaled)
df['ml_drift_detected'] = preds == -1

output_path = os.path.join(
    BASE_DIR,
    "data",
    "processed",
    "isolation_forest_results.csv"
)

df[['date', 'ml_drift_detected']].to_csv(output_path, index=False)

print("✅ Isolation Forest drift detection complete")
