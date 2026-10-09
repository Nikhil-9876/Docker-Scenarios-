import os
import pickle
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.naive_bayes import GaussianNB
from sklearn.metrics import accuracy_score, classification_report

DATA_PATH = os.path.join("data", "Iris (1).csv")
df = pd.read_csv(DATA_PATH)

rename_map = {
    "SepalLengthCm": "sepal_length",
    "SepalWidthCm": "sepal_width",
    "PetalLengthCm": "petal_length",
    "PetalWidthCm": "petal_width",
    "Species": "species",
}
df = df.rename(columns=rename_map)
if "Id" in df.columns:
    df = df.drop(columns=["Id"])

FEATURES = ["sepal_length", "sepal_width", "petal_length", "petal_width"]
TARGET = "species"

X = df[FEATURES]
y = df[TARGET]

X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

model = GaussianNB()
model.fit(X_train, y_train)

y_pred = model.predict(X_test)
acc = accuracy_score(y_test, y_pred)

print(f"Test Accuracy: {acc:.4f}")
print("\nClassification Report:\n")
print(classification_report(y_test, y_pred))

os.makedirs("models", exist_ok=True)
MODEL_PATH = os.path.join("models", "gaussian_nb_model.pkl")

with open(MODEL_PATH, "wb") as f:
    pickle.dump(model, f)

print(f"\nModel saved to: {MODEL_PATH}")