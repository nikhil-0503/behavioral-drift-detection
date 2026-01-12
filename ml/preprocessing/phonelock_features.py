import os
import pandas as pd
from datetime import datetime

RAW_PATH = r"..\..\data\raw\studentlife\sensing\phonelock"
OUT_PATH = r"..\..\data\processed"

def extract_phonelock_features():
    records = []

    for file in os.listdir(RAW_PATH):
        if not file.endswith(".csv"):
            continue

        df = pd.read_csv(os.path.join(RAW_PATH, file))

        # convert timestamps
        df["start_time"] = pd.to_datetime(df["start"], unit="s")
        df["date"] = df["start_time"].dt.date

        daily_counts = df.groupby("date").size().reset_index(name="unlock_count")
        records.append(daily_counts)

    final_df = pd.concat(records).groupby("date").sum().reset_index()
    return final_df

if __name__ == "__main__":
    os.makedirs(OUT_PATH, exist_ok=True)
    phonelock_df = extract_phonelock_features()
    phonelock_df.to_csv(f"{OUT_PATH}/phonelock_daily.csv", index=False)
    print("✅ phonelock_daily.csv created")
