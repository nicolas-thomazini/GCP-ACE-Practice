import os
from flask import jsonify

def hello_http(request):
    return jsonify({
        "message": "Hello from Cloud Functions!",
        "runtime": "Python 3.12",
        "service": "cloud-functions",
        "version": "2.0",
        "environment": os.environ.get("APP_ENV", "not-configured")
    })