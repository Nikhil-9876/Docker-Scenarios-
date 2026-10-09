import os
import pickle
from pathlib import Path
from datetime import datetime
from flask import Flask, render_template, request, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy

app = Flask(__name__)
CORS(app)

# Database Configuration from environment variables
DB_USER = os.environ.get("POSTGRES_USER", "postgres")
DB_PASSWORD = os.environ.get("POSTGRES_PASSWORD", "postgres")
DB_HOST = os.environ.get("POSTGRES_HOST", "iris-db-s4")
DB_PORT = os.environ.get("POSTGRES_PORT", "5432")
DB_NAME = os.environ.get("POSTGRES_DB", "iris_db")

app.config["SQLALCHEMY_DATABASE_URI"] = f"postgresql+psycopg2://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"
app.config["SQLALCHEMY_TRACK_MODIFICATIONS"] = False

db = SQLAlchemy(app)

# Model definition
class PredictionHistory(db.Model):
    __tablename__ = "prediction_history"
    id = db.Column(db.Integer, primary_key=True)
    sepal_length = db.Column(db.Float, nullable=False)
    sepal_width = db.Column(db.Float, nullable=False)
    petal_length = db.Column(db.Float, nullable=False)
    petal_width = db.Column(db.Float, nullable=False)
    prediction = db.Column(db.String(50), nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

def ensure_tables():
    try:
        db.create_all()
    except Exception as e:
        print(f"[DB Warning] Could not ensure tables immediately: {e}")

with app.app_context():
    ensure_tables()

# Load ML Model
BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "iris_model.pkl"
with MODEL_PATH.open("rb") as f:
    model = pickle.load(f)

@app.route("/")
def home():
    return render_template("index.html")

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "healthy"})

@app.route("/predict", methods=["POST"])
def predict():
    data = request.json or {}
    try:
        sepal_length = float(data["sepal_length"])
        sepal_width = float(data["sepal_width"])
        petal_length = float(data["petal_length"])
        petal_width = float(data["petal_width"])
    except (KeyError, ValueError, TypeError) as e:
        return jsonify({"error": f"Invalid input parameters: {e}"}), 400

    features = [[sepal_length, sepal_width, petal_length, petal_width]]
    pred_idx = int(model.predict(features)[0])
    classes = {0: "Setosa", 1: "Versicolor", 2: "Virginica"}
    pred_class = classes.get(pred_idx, "Unknown")

    # Persist to database
    try:
        ensure_tables()
        record = PredictionHistory(
            sepal_length=sepal_length,
            sepal_width=sepal_width,
            petal_length=petal_length,
            petal_width=petal_width,
            prediction=pred_class
        )
        db.session.add(record)
        db.session.commit()
    except Exception as e:
        db.session.rollback()
        print(f"[DB Error] Could not save prediction: {e}")

    return jsonify({"prediction": pred_class})

@app.route("/history", methods=["GET"])
def history():
    try:
        ensure_tables()
        records = PredictionHistory.query.order_by(PredictionHistory.timestamp.desc()).limit(15).all()
        return jsonify([
            {
                "id": r.id,
                "sepal_length": r.sepal_length,
                "sepal_width": r.sepal_width,
                "petal_length": r.petal_length,
                "petal_width": r.petal_width,
                "prediction": r.prediction,
                "timestamp": r.timestamp.isoformat()
            }
            for r in records
        ])
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
