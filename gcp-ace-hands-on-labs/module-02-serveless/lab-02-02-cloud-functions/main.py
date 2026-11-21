import os
from flask import jsonify
from google.cloud import storage

def hello_http(request):
    bucket_name = "ace-functions-iam-618071923969"
    file_name = "test-iam.txt"

    try:
        client = storage.Client()
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(file_name)

        content = blob.download_as_text()

        return jsonify({
            "message": "File read successfully!",
            "file": file_name,
            "content": content,
            "environment": os.environ.get("APP_ENV", "not-configured")
        })

    except Exception as e:
        return jsonify({
            "error": str(e),
            "type": type(e).__name__
        }), 500