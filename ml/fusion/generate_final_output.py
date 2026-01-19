import pandas as pd
import os
import json

# --------------------------------------------------
# PATH SETUP
# --------------------------------------------------
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PROCESSED_DIR = os.path.join(BASE_DIR, "data", "processed")

iso_path = os.path.join(PROCESSED_DIR, "isolation_forest_results.csv")
ae_path = os.path.join(PROCESSED_DIR, "autoencoder_drift_results.csv")
stat_path = os.path.join(PROCESSED_DIR, "statistical_drift_results.csv")

csv_output_path = os.path.join(PROCESSED_DIR, "final_drift_output.csv")
json_output_path = os.path.join(PROCESSED_DIR, "final_drift_output.json")

# --------------------------------------------------
# LOAD ISOLATION FOREST RESULTS (MANDATORY)
# --------------------------------------------------
iso_df = pd.read_csv(iso_path)
iso_df["date"] = pd.to_datetime(iso_df["date"])

# Expected column:
# date, ml_drift_detected
iso_df = iso_df[["date", "ml_drift_detected"]]

# --------------------------------------------------
# LOAD AUTOENCODER RESULTS (MANDATORY)
# --------------------------------------------------
ae_df = pd.read_csv(ae_path)
ae_df["date"] = pd.to_datetime(ae_df["date"])

# Your actual schema:
# date, autoencoder_drift_score, dl_drift_detected
ae_df = ae_df.rename(columns={
    "dl_drift_detected": "autoencoder_drift_detected",
    "autoencoder_drift_score": "autoencoder_score"
})

ae_df = ae_df[[
    "date",
    "autoencoder_drift_detected",
    "autoencoder_score"
]]

# --------------------------------------------------
# LOAD STATISTICAL DRIFT (OPTIONAL)
# --------------------------------------------------
if os.path.exists(stat_path):
    stat_df = pd.read_csv(stat_path)
    stat_df["date"] = pd.to_datetime(stat_df["date"])
    stat_df = stat_df[["date", "drift_detected"]]
else:
    # If not present, assume no statistical drift
    stat_df = iso_df[["date"]].copy()
    stat_df["drift_detected"] = False

# --------------------------------------------------
# MERGE ALL RESULTS
# --------------------------------------------------
merged = iso_df.merge(ae_df, on="date", how="left")
merged = merged.merge(stat_df, on="date", how="left")

merged = merged.fillna(False)

# --------------------------------------------------
# FUSION LOGIC
# --------------------------------------------------
def fuse(row):
    votes = [
        int(row["ml_drift_detected"]),
        int(row["autoencoder_drift_detected"]),
        int(row["drift_detected"])
    ]
    confidence = round(sum(votes) / 3, 2)
    final_drift = confidence >= 0.34  # at least 1/3 votes
    return pd.Series([final_drift, confidence])

merged[["final_drift_detected", "confidence"]] = merged.apply(fuse, axis=1)

# --------------------------------------------------
# SAVE CSV (FOR DEBUG / RECORD)
# --------------------------------------------------
merged_out = merged[[
    "date",
    "ml_drift_detected",
    "autoencoder_drift_detected",
    "drift_detected",
    "confidence",
    "final_drift_detected"
]]

merged_out.to_csv(csv_output_path, index=False)

# --------------------------------------------------
# EXPORT JSON (FOR FLUTTER)
# --------------------------------------------------
json_data = []
for _, row in merged_out.iterrows():
    json_data.append({
        "date": row["date"].strftime("%Y-%m-%d"),
        "drift": bool(row["final_drift_detected"]),
        "confidence": float(row["confidence"])
    })

with open(json_output_path, "w") as f:
    json.dump(json_data, f, indent=2)

print("✅ Drift fusion complete")
print(f"📄 CSV saved to:  {csv_output_path}")
print(f"📱 JSON saved to: {json_output_path}")
