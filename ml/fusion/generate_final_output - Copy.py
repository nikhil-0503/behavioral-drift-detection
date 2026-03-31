import pandas as pd
import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Paths
ml_path = os.path.join(
    BASE_DIR, "data", "processed", "isolation_forest_results.csv"
)

stat_path = os.path.join(
    BASE_DIR, "data", "processed", "statistical_drift_results.csv"
)

output_path = os.path.join(
    BASE_DIR, "data", "processed", "final_drift_output.csv"
)

# Load ML drift results
ml_df = pd.read_csv(ml_path)
ml_df["date"] = pd.to_datetime(ml_df["date"])

# Try loading statistical drift (optional)
if os.path.exists(stat_path):
    stat_df = pd.read_csv(stat_path)
    stat_df["date"] = pd.to_datetime(stat_df["date"])
else:
    # If not present, create empty statistical drift
    stat_df = ml_df[["date"]].copy()
    stat_df["statistical_drift_detected"] = False

# Merge
merged_df = pd.merge(ml_df, stat_df, on="date", how="left")

# Safety fallback
if "statistical_drift_detected" not in merged_df.columns:
    merged_df["statistical_drift_detected"] = False

# Final fusion logic
merged_df["final_drift_detected"] = (
    merged_df["ml_drift_detected"] |
    merged_df["statistical_drift_detected"]
)

# Save output
merged_df[[
    "date",
    "ml_drift_detected",
    "statistical_drift_detected",
    "final_drift_detected"
]].to_csv(output_path, index=False)

print("✅ Final drift fusion complete")
print(f"📁 Saved to: {output_path}")
