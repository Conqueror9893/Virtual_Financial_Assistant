# # api/main.py
# from flask import Flask, request, jsonify
# from flask_cors import CORS
# from threading import Lock

# from langgraph_flow.nodes.spend_insights_node import handle_spend_insight
# from langgraph_flow.nodes.output_formatter import format_spend_response
# from langgraph_flow.nodes.faq_node import handle_faq
# from langgraph_flow.nodes.offers_node import handle_offers
# from utils.logger import get_logger

# app = Flask(__name__)
# CORS(app)
# logger = get_logger(__name__)

# # Simple in-memory store for conversation state keyed by user_id
# # (Replace with persistent DB or cache in production)
# user_states = {}
# state_lock = Lock()

# # Import your LangGraph flow builder
# from langgraph_flow.langgraph_flow import build_flow

# graph = build_flow()

# # Initialize default empty state template
# def create_default_state():
#     return {
#         "user_input": "",
#         "intent": "unknown",
#         "result": "",
#         "awaiting_otp": False,
#         "otp_attempts": 0,
#         "pending_transfer": None,
#         "awaiting_confirmation": False,
#         "confirmation_context": None,
#     }

# def get_user_state(user_id):
#     with state_lock:
#         if user_id not in user_states:
#             user_states[user_id] = create_default_state()
#         return user_states[user_id]

# def save_user_state(user_id, state):
#     with state_lock:
#         user_states[user_id] = state

# @app.route("/api/health")
# def health():
#     return jsonify({"status": "ok"})

# @app.route("/transfer", methods=["POST"])
# def transfer():
#     data = request.json or {}
#     user_id = int(data.get("user_id", 1))
#     user_state = get_user_state(user_id)

#     user_input = data.get("query")
#     otp = data.get("otp")

#     # Require query if not OTP step
#     if otp is None and not user_input:
#         return jsonify({"status": "error", "message": "'query' is required when no OTP is provided"}), 400

#     # Parse JSON transfer details if OTP provided and query looks like a JSON string
#     if otp is not None and isinstance(user_input, str):
#         import json as pyjson
#         try:
#             user_input = pyjson.loads(user_input)
#         except Exception:
#             return jsonify({"status": "error", "message": "Invalid transfer details format with OTP"}), 400

#     # ----- Update user_state -----
#     if user_state.get("awaiting_otp"):
#         user_state["intent"] = "otp"
#         user_state["otp_value"] = otp  # store OTP explicitly
#     elif user_state.get("awaiting_confirmation"):
#         user_state["intent"] = "confirmation"
#         user_state["confirmation_input"] = user_input  # store confirmation explicitly
#     else:
#         user_state["intent"] = "transfer"
#         user_state["user_input"] = user_input

#     # Run through LangGraph
#     result = graph.invoke(user_state)

#     # Save updated state
#     save_user_state(user_id, result)

#     # Always return a clean response object (instead of dumping whole state)
#     return jsonify({"status": "ok", "response": result["result"]})


# @app.route("/spend", methods=["POST"])
# def spend():
#     data = request.json or {}
#     user_id = int(data.get("user_id", 1))
#     query = data.get("query")
#     if not query:
#         return jsonify({"status": "error", "message": "'query' is required"}), 400

#     insight = handle_spend_insight(user_id, query)
#     response = format_spend_response(insight)
#     return jsonify(response)

# @app.route("/faq", methods=["POST"])
# def faq():
#     data = request.json or {}
#     user_id = int(data.get("user_id", 1))
#     query = data.get("query")
#     if not query:
#         return jsonify({"status": "error", "message": "'query' is required"}), 400

#     result = handle_faq(user_id, query)
#     return jsonify(result)

# @app.route("/offers", methods=["POST"])
# def offers():
#     data = request.json or {}
#     user_id = int(data.get("user_id", 1))
#     query = data.get("query", "Show me offers")

#     result = handle_offers(user_id, query)
#     return jsonify(result)

# if __name__ == "__main__":
#     app.run(debug=True, host="0.0.0.0", port=5000)


from flask import Flask, request, jsonify
from flask_cors import CORS
from threading import Lock

from langgraph_flow.nodes.spend_insights_node import handle_spend_insight
from langgraph_flow.nodes.output_formatter import format_spend_response
from langgraph_flow.nodes.faq_node import handle_faq
from langgraph_flow.nodes.offers_node import handle_offers
from langgraph_flow.nodes.transfer_node import handle_transfer  # ✅ ensure transfer_node is used
from utils.logger import get_logger

app = Flask(__name__)
CORS(app)
logger = get_logger(__name__)

# Simple in-memory store for conversation state keyed by user_id
user_states = {}
state_lock = Lock()

from langgraph_flow.langgraph_flow import build_flow
graph = build_flow()

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


# @app.route("/transfer", methods=["POST"])
# def transfer():
#     data = request.json or {}
#     user_id = int(data.get("user_id", 1))
#     otp = data.get("otp")

#     # Normalize transfer input
#     details = data.get("transfer_details") or data.get("query")

#     if not details:
#         return jsonify({"status": "error", "message": "Missing transfer details"}), 400

#     # Pass into transfer_node
#     resp = handle_transfer(user_id, details, otp)

#     return jsonify({"status": "ok", "response": resp})

@app.route("/transfer", methods=["POST"])
def transfer():
    data = request.json or {}
    user_id = int(data.get("user_id", 1))
    user_state = get_user_state(user_id)

    user_input = data.get("query")
    otp = data.get("otp")

    # Require query if no OTP and not a confirmation step
    if otp is None and not user_input and not user_state.get("awaiting_confirmation"):
        return jsonify({"status": "error", "message": "'query' is required"}), 400

    # ----- Handle confirmation separately -----
    if user_state.get("awaiting_confirmation"):
        user_state["user_input"] = user_input
        user_state["intent"] = "confirmation"
        result = graph.invoke(user_state)
        save_user_state(user_id, result)
        return jsonify({"status": "ok", "response": result["result"]})

    # ----- Handle OTP step separately -----
    if user_state.get("awaiting_otp"):
        # user_input is OTP here
        otp_val = otp or user_input  # prefer explicit otp, fallback to query
        user_state["user_input"] = str(otp_val) if otp_val is not None else ""
        user_state["intent"] = "otp"
        result = graph.invoke(user_state)
        save_user_state(user_id, result)
        return jsonify({"status": "ok", "response": result["result"]})

    # ----- Normal transfer step -----
    try:
        resp = handle_transfer(user_id, user_input, otp)
    except Exception as e:
        return jsonify({"status": "error", "message": f"Transfer failed: {e}"}), 400

    # Update user state for OTP or recommendation
    user_state["user_input"] = user_input
    user_state["result"] = resp

    if resp.get("status") == "otp_required":
        user_state["awaiting_otp"] = True
        user_state["pending_transfer"] = {
            "query": user_input,
            "transfer_details": resp.get("transfer_details")
        }
    else:
        user_state["awaiting_otp"] = False
        user_state["pending_transfer"] = None

    save_user_state(user_id, user_state)

    return jsonify({"status": "ok", "response": resp})




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
