import pandas as pd
import json
import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

csv_path = os.path.join(
    BASE_DIR,
    "data",
    "processed",
    "final_drift_output.csv"
)

output_path = os.path.join(
    BASE_DIR,
    "flutter_app",
    "behavioral_drift_app",
    "assets",
    "drift_results.json"
)

df = pd.read_csv(csv_path)

# Keep only what UI needs
df = df[["date", "final_drift_detected"]]

records = df.to_dict(orient="records")

with open(output_path, "w") as f:
    json.dump(records, f, indent=2)

print("✅ JSON exported for Flutter UI")
