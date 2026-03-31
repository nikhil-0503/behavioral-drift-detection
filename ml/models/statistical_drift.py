import pandas as pd
import numpy as np

# Load expanded features
df = pd.read_csv("../../data/processed/daily_features_expanded.csv")
df['date'] = pd.to_datetime(df['date'])

# Baseline = first 7 days
baseline = df.iloc[:7]
monitoring = df.iloc[7:]

# Compute baseline stats
mean = baseline.mean(numeric_only=True)
std = baseline.std(numeric_only=True)

# Z-score
z_scores = (monitoring[mean.index] - mean) / std

# Drift flag
drift_flags = (z_scores.abs() >= 2)

# Save results
result = monitoring[['date']].copy()
result['drift_score'] = z_scores.abs().max(axis=1)
result['drift_detected'] = drift_flags.any(axis=1)

result.to_csv("../../data/processed/statistical_drift_results.csv", index=False)

print("✅ Statistical drift detection complete")
