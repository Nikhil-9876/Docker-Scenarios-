from flask import Flask, render_template, request, jsonify
from flask_cors import CORS
import pickle
from pathlib import Path
import os
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime

app = Flask(__name__)
CORS(app)

# Configure Database - SQLite with a persistent file stored in /data
BASE_DIR = Path(__file__).resolve().parent
DB_DIR = Path(os.getenv('DB_DIR', '/data'))
DB_DIR.mkdir(parents=True, exist_ok=True)

app.config['SQLALCHEMY_DATABASE_URI'] = f'sqlite:///{DB_DIR}/app.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# Define Database Model
class PredictionHistory(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    sepal_length = db.Column(db.Float, nullable=False)
    sepal_width = db.Column(db.Float, nullable=False)
    petal_length = db.Column(db.Float, nullable=False)
    petal_width = db.Column(db.Float, nullable=False)
    prediction = db.Column(db.String(50), nullable=False)
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

# Create tables if they don't exist
with app.app_context():
    try:
        db.create_all()
        print("Database tables ensured successfully!")
    except Exception as e:
        print(f"Error creating tables: {e}")

# Load the trained model
MODEL_PATH = BASE_DIR / "iris_model.pkl"
with MODEL_PATH.open("rb") as file:
    model = pickle.load(file)

@app.route("/")
def home():
    return render_template("index.html")

@app.route("/predict", methods=["POST"])
def predict():
    data = request.json

    # Get input values
    sepal_length = float(data["sepal_length"])
    sepal_width = float(data["sepal_width"])
    petal_length = float(data["petal_length"])
    petal_width = float(data["petal_width"])

    features = [sepal_length, sepal_width, petal_length, petal_width]

    # Make prediction
    prediction_val = model.predict([features])[0]

    classes = {
        0: "Setosa",
        1: "Versicolor",
        2: "Virginica"
    }
    
    predicted_class = classes[int(prediction_val)]

    # Save to database
    try:
        new_prediction = PredictionHistory(
            sepal_length=sepal_length,
            sepal_width=sepal_width,
            petal_length=petal_length,
            petal_width=petal_width,
            prediction=predicted_class
        )
        db.session.add(new_prediction)
        db.session.commit()
    except Exception as e:
        print(f"Database error: {e}")
        db.session.rollback()

    return jsonify({
        "prediction": predicted_class
    })

@app.route("/history", methods=["GET"])
def history():
    # Helper endpoint to view history
    try:
        records = PredictionHistory.query.order_by(PredictionHistory.timestamp.desc()).limit(10).all()
        history_list = []
        for r in records:
            history_list.append({
                "id": r.id,
                "sepal_length": r.sepal_length,
                "sepal_width": r.sepal_width,
                "petal_length": r.petal_length,
                "petal_width": r.petal_width,
                "prediction": r.prediction,
                "timestamp": r.timestamp.isoformat()
            })
        return jsonify(history_list)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
