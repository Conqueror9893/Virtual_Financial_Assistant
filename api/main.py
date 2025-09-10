# api/main.py
from flask import Flask, request, jsonify
from flask_cors import CORS
from memory import memory_store
from langgraph_flow.nodes.transfer_node import handle_transfer
from langgraph_flow.nodes.spend_insights_node import handle_spend_insight
from langgraph_flow.nodes.output_formatter import format_spend_response
from langgraph_flow.nodes.faq_node import handle_faq
from langgraph_flow.nodes.offers_node import handle_offers
from utils.logger import get_logger

app = Flask(__name__)
CORS(app)
logger = get_logger(__name__)

# Init DB
memory_store.init_db()

@app.route("/api/health")
def health():
    return jsonify({"status": "ok"})

@app.route("/transfer", methods=["POST"])
def transfer():
    data = request.json
    user_id = data.get("user_id", 1)
    query = data.get("query")
    otp = data.get("otp")  # optional

    result = handle_transfer(user_id, query, otp)
    return jsonify(result)

@app.route("/spend", methods=["POST"])
def spend():
    data = request.json
    user_id = data.get("user_id", 1)
    query = data["query"]

    insight = handle_spend_insight(user_id, query)
    response = format_spend_response(insight)
    return jsonify(response)

@app.route("/faq", methods=["POST"])
def faq():
    data = request.json
    user_id = data.get("user_id", 1)
    query = data["query"]

    result = handle_faq(user_id, query)
    return jsonify(result)

@app.route("/offers", methods=["POST"])
def offers():
    data = request.json
    user_id = data.get("user_id", 1)
    query = data.get("query", "Show me offers")

    result = handle_offers(user_id, query)
    return jsonify(result)


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
