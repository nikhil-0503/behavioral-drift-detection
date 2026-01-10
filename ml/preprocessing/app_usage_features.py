import os
import pandas as pd

RAW_PATH = r"..\..\data\raw\studentlife\app_usage"
OUT_PATH = r"..\..\data\processed"

def extract_app_usage():
    records = []

    for file in os.listdir(RAW_PATH):
        if not file.endswith(".csv"):
            continue

        df = pd.read_csv(os.path.join(RAW_PATH, file))
        df["timestamp"] = pd.to_datetime(df["timestamp"], unit="s")
        df["date"] = df["timestamp"].dt.date

        daily = df.groupby("date").size().reset_index(name="app_events")
        records.append(daily)

    final_df = pd.concat(records).groupby("date").sum().reset_index()
    return final_df

if __name__ == "__main__":
    os.makedirs(OUT_PATH, exist_ok=True)
    app_df = extract_app_usage()
    app_df.to_csv(f"{OUT_PATH}/app_usage_daily.csv", index=False)
    print("✅ app_usage_daily.csv created")
