import os
import pandas as pd
import numpy as np
import torch
import torch.nn as nn
from sklearn.preprocessing import StandardScaler

# ------------------ Paths ------------------
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA_PATH = os.path.join(BASE_DIR, "data", "processed", "daily_features_expanded.csv")
OUT_PATH = os.path.join(BASE_DIR, "data", "processed", "autoencoder_drift_results.csv")

# ------------------ Load data ------------------
df = pd.read_csv(DATA_PATH)
df['date'] = pd.to_datetime(df['date'])

X = df.drop(columns=['date'])
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

X_tensor = torch.tensor(X_scaled, dtype=torch.float32)

# ------------------ Autoencoder Model ------------------
class AutoEncoder(nn.Module):
    def __init__(self, input_dim):
        super().__init__()
        self.encoder = nn.Sequential(
            nn.Linear(input_dim, 16),
            nn.ReLU(),
            nn.Linear(16, 8)
        )
        self.decoder = nn.Sequential(
            nn.Linear(8, 16),
            nn.ReLU(),
            nn.Linear(16, input_dim)
        )

    def forward(self, x):
        encoded = self.encoder(x)
        decoded = self.decoder(encoded)
        return decoded

model = AutoEncoder(X_tensor.shape[1])
criterion = nn.MSELoss()
optimizer = torch.optim.Adam(model.parameters(), lr=0.001)

# ------------------ Train on baseline ------------------
baseline_days = 7
X_train = X_tensor[:baseline_days]

epochs = 100
for epoch in range(epochs):
    optimizer.zero_grad()
    outputs = model(X_train)
    loss = criterion(outputs, X_train)
    loss.backward()
    optimizer.step()

# ------------------ Reconstruction Error ------------------
with torch.no_grad():
    reconstructed = model(X_tensor)
    recon_error = torch.mean((X_tensor - reconstructed) ** 2, dim=1).numpy()

# ------------------ Drift Detection ------------------
threshold = np.mean(recon_error[:baseline_days]) + 2 * np.std(recon_error[:baseline_days])
df['autoencoder_drift_score'] = recon_error
df['dl_drift_detected'] = df['autoencoder_drift_score'] > threshold

# ------------------ Save ------------------
df[['date', 'autoencoder_drift_score', 'dl_drift_detected']].to_csv(OUT_PATH, index=False)
print("✅ Autoencoder-based drift detection complete")
