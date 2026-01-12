import pandas as pd
import numpy as np

# -----------------------------
# Load daily features
# -----------------------------
df = pd.read_csv(r"..\..\data\processed\daily_features.csv")

# Fix date
df['date'] = pd.to_datetime(df['date'], dayfirst=True)
df = df.sort_values('date')

# -----------------------------
# 1. Log-scaled features
# -----------------------------
df['app_events_log'] = np.log1p(df['app_events'])
df['unlock_log'] = np.log1p(df['unlock_count'])

# -----------------------------
# 2. Rolling statistics (7-day)
# -----------------------------
df['app_events_7day_mean'] = df['app_events'].rolling(7).mean()
df['unlock_7day_mean'] = df['unlock_count'].rolling(7).mean()

df['app_events_7day_std'] = df['app_events'].rolling(7).std()
df['unlock_7day_std'] = df['unlock_count'].rolling(7).std()

# -----------------------------
# 3. Day-to-day change
# -----------------------------
df['app_events_change'] = df['app_events'].diff()
df['unlock_change'] = df['unlock_count'].diff()

# -----------------------------
# 4. Ratio to personal baseline
# -----------------------------
df['app_events_ratio_to_mean'] = (
    df['app_events'] / df['app_events_7day_mean']
)

df['unlock_ratio_to_mean'] = (
    df['unlock_count'] / df['unlock_7day_mean']
)

# -----------------------------
# 5. Composite behavior scores
# -----------------------------
df['behavior_intensity'] = (
    df['app_events_log'] + df['unlock_log']
)

df['instability_score'] = (
    df['app_events_7day_std'].fillna(0) +
    df['unlock_7day_std'].fillna(0)
)

# -----------------------------
# Cleanup
# -----------------------------
df = df.replace([np.inf, -np.inf], 0)
df = df.fillna(0)

# Save expanded features
df.to_csv("..\..\data\processed\daily_features_expanded.csv", index=False)

print("✅ daily_features_expanded.csv created")
