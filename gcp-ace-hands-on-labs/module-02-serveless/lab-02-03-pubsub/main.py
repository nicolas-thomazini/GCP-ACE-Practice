from flask import Flask, request, jsonify
import base64

app = Flask(__name__)


@app.route("/", methods=["POST"])
def receive_message():
    envelope = request.get_json()

    if not envelope or "message" not in envelope:
        return jsonify({"error": "Invalid Pub/Sub message"}), 400

    message = envelope["message"]

    data = message.get("data", "")
    decoded_data = base64.b64decode(data).decode("utf-8")

    print(f"Received message: {decoded_data}")

    return jsonify({
        "status": "success",
        "message": decoded_data
    }), 200


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=True)