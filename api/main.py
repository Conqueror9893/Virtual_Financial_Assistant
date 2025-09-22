from flask import Flask, jsonify
from flask_cors import CORS
from utils.logger import get_logger
from api.unified_router import unified_api

app = Flask(__name__)
CORS(app)
logger = get_logger(__name__)

# Register the blueprint for the unified API
app.register_blueprint(unified_api, url_prefix='/api')

# ---------------- Routes ----------------
@app.route("/api/health")
def health():
    """Health check endpoint."""
    return jsonify({"status": "ok"})

if __name__ == "__main__":
    # Note: In a production environment, use a proper WSGI server like Gunicorn
    app.run(debug=True, host="0.0.0.0", port=5000)