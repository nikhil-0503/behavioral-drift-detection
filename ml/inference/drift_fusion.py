import pandas as pd
import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

stat_path = os.path.join(
    BASE_DIR,
    "data",
    "processed",
    "statistical_drift_results.csv"
)

ml_path = os.path.join(
    BASE_DIR,
    "data",
    "processed",
    "isolation_forest_results.csv"
)

stat_df = pd.read_csv(stat_path)
ml_df = pd.read_csv(ml_path)

stat_df['date'] = pd.to_datetime(stat_df['date'])
ml_df['date'] = pd.to_datetime(ml_df['date'])

# Merge on date
merged = pd.merge(stat_df, ml_df, on='date', how='inner')

# Final drift decision
merged['final_drift_detected'] = (
    merged['drift_detected'] | merged['ml_drift_detected']
)

output_path = os.path.join(
    BASE_DIR,
    "data",
    "processed",
    "final_drift_results.csv"
)

merged.to_csv(output_path, index=False)

print("✅ Drift fusion complete")
