# api/main.py
from flask import Flask, request, jsonify
from flask_cors import CORS
from threading import Lock

from langgraph_flow.nodes.spend_insights_node import handle_spend_insight
from langgraph_flow.nodes.output_formatter import format_spend_response
from langgraph_flow.nodes.faq_node import handle_faq
from langgraph_flow.nodes.offers_node import handle_offers
from utils.logger import get_logger

app = Flask(__name__)
CORS(app)
logger = get_logger(__name__)

# Simple in-memory store for conversation state keyed by user_id
# (Replace with persistent DB or cache in production)
user_states = {}
state_lock = Lock()

# Import your LangGraph flow builder
from langgraph_flow.langgraph_flow import build_flow

graph = build_flow()

# Initialize default empty state template
def create_default_state():
    return {
        "user_input": "",
        "intent": "unknown",
        "result": "",
        "awaiting_otp": False,
        "otp_attempts": 0,
        "pending_transfer": None,
        "awaiting_confirmation": False,
        "confirmation_context": None,
    }

def get_user_state(user_id):
    with state_lock:
        if user_id not in user_states:
            user_states[user_id] = create_default_state()
        return user_states[user_id]

def save_user_state(user_id, state):
    with state_lock:
        user_states[user_id] = state

@app.route("/api/health")
def health():
    return jsonify({"status": "ok"})

@app.route("/transfer", methods=["POST"])
def transfer():
    data = request.json or {}
    user_id = int(data.get("user_id", 1))
    user_state = get_user_state(user_id)

    user_input = data.get("query")
    otp = data.get("otp")

    # Make sure user_input is present when no OTP
    if otp is None and not user_input:
        return jsonify({"status": "error", "message": "'query' is required when no OTP is provided"}), 400

    # For OTP step, if query is a stringified JSON, parse it
    if otp is not None and isinstance(user_input, str):
        import json as pyjson
        try:
            user_input = pyjson.loads(user_input)
        except Exception:
            return jsonify({"status": "error", "message": "Invalid transfer details format with OTP"}), 400

    # Update user_state with input and set correct intent for flow
    user_state["user_input"] = user_input

    if user_state.get("awaiting_otp"):
        user_state["intent"] = "otp"
    elif user_state.get("awaiting_confirmation"):
        user_state["intent"] = "confirmation"
    else:
        user_state["intent"] = "unknown"

    # Call the flow with the current state
    result = graph.invoke(user_state)

    # Save updated state for user
    save_user_state(user_id, result)

    return jsonify(result["result"])

@app.route("/spend", methods=["POST"])
def spend():
    data = request.json or {}
    user_id = int(data.get("user_id", 1))
    query = data.get("query")
    if not query:
        return jsonify({"status": "error", "message": "'query' is required"}), 400

    insight = handle_spend_insight(user_id, query)
    response = format_spend_response(insight)
    return jsonify(response)

@app.route("/faq", methods=["POST"])
def faq():
    data = request.json or {}
    user_id = int(data.get("user_id", 1))
    query = data.get("query")
    if not query:
        return jsonify({"status": "error", "message": "'query' is required"}), 400

    result = handle_faq(user_id, query)
    return jsonify(result)

@app.route("/offers", methods=["POST"])
def offers():
    data = request.json or {}
    user_id = int(data.get("user_id", 1))
    query = data.get("query", "Show me offers")

    result = handle_offers(user_id, query)
    return jsonify(result)

if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
