import pandas as pd

phonelock = pd.read_csv("data/processed/phonelock_daily.csv")
app = pd.read_csv("data/processed/app_usage_daily.csv")

daily_features = phonelock.merge(app, on="date", how="outer").fillna(0)

daily_features.to_csv("..\..\data\processed\daily_features.csv", index=False)
print("🎯 daily_features.csv READY")
