import os
import pickle

from flask import Flask, render_template, request, url_for, redirect

app = Flask(__name__)

MODEL_PATH = os.path.join("models", "gaussian_nb_model.pkl")

with open(MODEL_PATH, "rb") as f:
    model = pickle.load(f)


@app.route("/", methods=["GET"])
def index():
    return render_template("index.html")


@app.route("/predict", methods=["GET" ,"POST"])
def predict():
    try:
        if request.method == "GET":
            return redirect(url_for("index"))
        
        sepal_length = float(request.form["sepal_length"])
        sepal_width = float(request.form["sepal_width"])
        petal_length = float(request.form["petal_length"])
        petal_width = float(request.form["petal_width"])
    except (KeyError, ValueError):
        return render_template(
            "result.html",
            prediction="Invalid input. Please enter valid numbers for all fields.",
            inputs=None,
        )
    features = [[sepal_length, sepal_width, petal_length, petal_width]]
    prediction = model.predict(features)[0]
    inputs = {
        "Sepal Length": sepal_length,
        "Sepal Width": sepal_width,
        "Petal Length": petal_length,
        "Petal Width": petal_width,
    }

    return render_template("result.html", prediction=prediction, inputs=inputs)

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)


