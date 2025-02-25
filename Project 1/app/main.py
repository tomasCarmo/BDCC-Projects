# Imports
import warnings
warnings.filterwarnings("ignore", category=FutureWarning)

import flask
import logging
import os
import tfmodel
from google.cloud import bigquery
from google.cloud import storage
from VisionAPI import detect_labels_uri
import re
from google.cloud import firestore
import firebase_admin
from firebase_admin import credentials, firestore  

# Get the Absolute path of any environment
script_dir = os.path.dirname(os.path.abspath(__file__))
key_path = os.path.join(script_dir, 'keys', 'proj8824-72c269ba75ca.json')

key_path_expanded = os.path.expanduser(key_path)
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = key_path_expanded
cred = credentials.Certificate(key_path_expanded)
App = firebase_admin.initialize_app(cred)
db = firestore.client()

# Set up logging
logging.basicConfig(level=logging.INFO,
                     format='%(asctime)s - %(levelname)s - %(message)s',
                     datefmt='%Y-%m-%d %H:%M:%S')

PROJECT = os.environ.get('GOOGLE_CLOUD_PROJECT') 
logging.info('Google Cloud project is {}'.format(PROJECT))

# Initialisation
logging.info('Initialising app')
app = flask.Flask(__name__)

logging.info('Initialising BigQuery client')
BQ_CLIENT = bigquery.Client()

BUCKET_NAME = PROJECT + '.appspot.com'
logging.info('Initialising access to storage bucket {}'.format(BUCKET_NAME))
APP_BUCKET = storage.Client().bucket(BUCKET_NAME)

logging.info('Initialising TensorFlow classifier')
TF_CLASSIFIER = tfmodel.Model(
    app.root_path + "/static/tflite/model.tflite",
    app.root_path + "/static/tflite/dict.txt"
)
logging.info('Initialisation complete')

# End-point implementation
@app.route('/')
def index():
    return flask.render_template('index.html')

@app.route('/classes')
def classes():
    results = BQ_CLIENT.query(
    '''
        Select Description, COUNT(*) AS NumImages
        FROM `proj8824.openimages.image_labels`
        JOIN `proj8824.openimages.classes` USING(Label)
        GROUP BY Description
        ORDER BY Description
    ''').result()
    logging.info('classes: results={}'.format(results.total_rows))
    data = dict(results=results)
    return flask.render_template('classes.html', data=data)

@app.route('/relations')
def relations():
    results = BQ_CLIENT.query(
    '''
        Select relation, count(*)
        From `proj8824.openimages.relations` 
        Group By relation
    ''').result()

    return flask.render_template('relations.html', results=results)

@app.route('/image_info')
def image_info():
    image_id = flask.request.args.get('image_id')

    results = BQ_CLIENT.query(
    '''
        Select Description
        FROM `proj8824.openimages.image_labels`
        JOIN `proj8824.openimages.classes` USING(Label)
        WHERE ImageId = '{}'
    '''.format(image_id)).result()

    return flask.render_template('image_info.html', results=results, image_id=image_id)

@app.route('/image_search')
def image_search():
    description = flask.request.args.get('description', default='')
    image_limit = flask.request.args.get('image_limit', default=10, type=int)

    results = BQ_CLIENT.query(
    '''
        Select ImageId
        FROM `proj8824.openimages.image_labels`
        JOIN `proj8824.openimages.classes` USING(Label)
        WHERE Description = '{}'
        LIMIT {}
    '''.format(description, image_limit)).result()
    return flask.render_template('image_search.html', results=results, description=description)

@app.route('/relation_search')
def relation_search():
    class1 = flask.request.args.get('class1', default='%')
    relation = flask.request.args.get('relation', default='%')
    class2 = flask.request.args.get('class2', default='%')
    image_limit = flask.request.args.get('image_limit', default=10, type=int)
   
    results = BQ_CLIENT.query(
    '''
        Select a.ImageId, b.description as Desc1, a.relation, c.description as Desc2
        From openimages.relations as a 
        Left Join `proj8824.openimages.classes` as b On a.label1=b.label
        Left Join `proj8824.openimages.classes` as c On a.label2=c.label
        Where b.description LIKE '{}' AND a.relation LIKE '{}' AND c.description LIKE '{}'
        Limit {}
    '''.format(class1,relation,class2,image_limit)).result()

    return flask.render_template('relation_search.html', results=results)


@app.route('/image_classify_classes')
def image_classify_classes():
    with open(app.root_path + "/static/tflite/dict.txt", 'r') as f:
        data = dict(results=sorted(list(f)))
        return flask.render_template('image_classify_classes.html', data=data)
 
@app.route('/image_classify', methods=['POST'])
def image_classify():
    files = flask.request.files.getlist('files')
    min_confidence = flask.request.form.get('min_confidence', default=0.25, type=float)
    results = []
    if len(files) > 1 or files[0].filename != '':
        for file in files:
            
            classifications = TF_CLASSIFIER.classify(file, min_confidence)
            blob = storage.Blob(file.filename, APP_BUCKET)
            blob.upload_from_file(file, blob, content_type=file.mimetype)
            blob.make_public()
            logging.info('image_classify: filename={} blob={} classifications={}'\
                .format(file.filename,blob.name,classifications))
            results.append(dict(bucket=APP_BUCKET,
                                filename=file.filename,
                                classifications=classifications))

            # Create a document in Firestore
            doc_ref = db.collection('classifications').document()
            doc_ref.set({
                'filename': file.filename,
                'classifications': classifications,
                'bucket_name': APP_BUCKET.name,
                'timestamp': firestore.SERVER_TIMESTAMP
            })
    
    data = dict(bucket_name=APP_BUCKET.name, 
                min_confidence=min_confidence, 
                results=results)
    return flask.render_template('image_classify.html', data=data)

# Cloud Vision API
@app.route('/CloudVision', methods=['POST'])
def CloudVision():
    image_url = flask.request.form['image_url']
    min_confidence = float(flask.request.form['min_confidence']) / 100  # Assuming input is 0-100, converting to 0-1

    labels = detect_labels_uri(image_url)

    # Validate URL format and image extension
    if not re.match(r'^https?:\/\/.*\.(jpg|jpeg|png|gif)$', image_url, re.IGNORECASE):
        flash('Please enter a valid image URL ending with .jpg, .jpeg, .png, or .gif.', 'warning')
        return redirect(url_for('index'))  # Assuming 'index' is the name of your route for the form

    # Process the labels to fit the expected structure for CloudVision.html
    processed_labels = []
    for label in labels:
        if label.score >= min_confidence:
            processed_labels.append({
                'description': label.description,
                'score': label.score
            })

    # Prepare data for the template
    data = {
        'results': [{
            'image_url': image_url,
            'labels': processed_labels
        }],
        'min_confidence': min_confidence * 100  # Convert back to percentage for display
    }

    return flask.render_template('CloudVision.html', data=data)

# Initialize Firestore DB
@app.route('/classification_results')
def classification_results():
    docs = db.collection('classifications').order_by('timestamp', direction=firestore.Query.DESCENDING).stream()

    classifications = [doc.to_dict() for doc in docs]

    return flask.render_template('classification_results.html', classifications=classifications)

from flask import Flask, request, jsonify, abort
import requests
from io import BytesIO
from tfmodel import Model

# Assuming TF_CLASSIFIER is already instantiated
@app.route('/image_info2', methods=['GET'])
def image_info2():
    image_url = request.args.get('url')
    if not image_url:
        return abort(400, description="Please provide an image URL using the 'url' query parameter.")

    min_confidence = float(request.args.get('min_confidence', 0.25))

    try:
        response = requests.get(image_url)
        if response.status_code != 200:
            return abort(404, description="Image could not be retrieved.")
        image_bytes = BytesIO(response.content)
    except requests.RequestException:
        return abort(400, description="Invalid image URL.")
    
    results = TF_CLASSIFIER.classify(image_bytes, min_confidence)

    return jsonify(results)

if __name__ == '__main__':
    # When invoked as a program.
    logging.info('Starting app')
    app.run(host='0.0.0.0', port=8080, debug=True)
