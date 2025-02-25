# The code of a GCF triggered by HTTP
import functions_framework
from flask import Flask, request, jsonify, abort
import requests
from io import BytesIO
import tfmodel
from tfmodel import Model

# Define TF Model
TF_CLASSIFIER = tfmodel.Model(
    "tflite/model.tflite",
    "tflite/dict.txt"
)

@functions_framework.http
def img_classifier(request):
    # Check for minimum confidence
    if request.args and 'min_confidence' in request.args:
        min_conf = float(request.args['min_confidence'])
    else:
        min_conf = 0.25
    # Check for image url
    if request.args and 'url' in request.args:
        img_url = request.args['url']
    else:
        return abort(404, description="Image URL missing.")

    try:
        response = requests.get(img_url)
        if response.status_code != 200:
            return abort(404, description="Image could not be retrieved.")
        image_bytes = BytesIO(response.content)
    except requests.RequestException:
        return abort(400, description="Invalid image URL.")

    results = TF_CLASSIFIER.classify(image_bytes, min_conf)

    return jsonify(results)