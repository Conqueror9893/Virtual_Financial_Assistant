# api/main.py
from flask import Flask, request, jsonify
from flask_cors import CORS
from threading import Lock

from langgraph_flow.nodes.spend_insights_node import handle_spend_insight
from langgraph_flow.nodes.output_formatter import format_spend_response
from langgraph_flow.nodes.faq_node import handle_faq
from langgraph_flow.nodes.offers_node import handle_offers
from langgraph_flow.nodes.transfer_node import handle_transfer
from langgraph_flow.nodes.intent_classifier import classify_intent
from utils.logger import get_logger

from langgraph_flow.langgraph_flow import build_flow, ConversationPhase

app = Flask(__name__)
CORS(app)
logger = get_logger(__name__)

# Simple in-memory store for conversation state keyed by user_id
user_states = {}
state_lock = Lock()

graph = build_flow()


# ---------------- State Management ----------------
def create_default_state():
    return {
        "user_input": "",
        "intent": "unknown",
        "result": "",
        "otp_attempts": 0,
        "pending_transfer": None,
        "confirmation_context": None,
        "phase": ConversationPhase.NORMAL,  # ✅ unified phase management
    }


def get_user_state(user_id):
    with state_lock:
        if user_id not in user_states:
            user_states[user_id] = create_default_state()
        return user_states[user_id]


def save_user_state(user_id, state):
    with state_lock:
        user_states[user_id] = state


# ---------------- Routes ----------------
@app.route("/api/health")
def health():
    return jsonify({"status": "ok"})



@app.route("/intent", methods=["POST"])
def intent():
    data = request.json or {}
    user_input = data.get("query", "")
    if not user_input:
        return jsonify({"status": "error", "message": "'query' is required"}), 400

    state = {"input": user_input}
    result_state = classify_intent(state)
    return jsonify({
        "status": "ok",
        "intent": result_state.get("intent", "faq"),
        "confidence": result_state.get("confidence", 0.0)
    })


@app.route("/chatbot", methods=["POST"])
def chatbot():
    data = request.json or {}
    user_id = int(data.get("user_id", 1))
    query = data.get("query")
    if not query:
        return jsonify({"status": "error", "message": "'query' is required"}), 400

    # Step 2a: Get intent by internal call to classify_intent function
    state = {"input": query}
    result_state = classify_intent(state)
    intent = result_state.get("intent", "faq")

    # Step 2b: Dispatch to appropriate handler based on intent
    if intent == "fund_transfer":
        user_state = get_user_state(user_id)
        user_state["user_input"] = query
        user_state["intent"] = intent
        result = graph.invoke(user_state)
        save_user_state(user_id, result)
        return jsonify({"status": "ok", "response": result.get("result", "")})

    elif intent == "spends_check":
        insight = handle_spend_insight(user_id, query)
        response = format_spend_response(insight)
        return jsonify({"status": "ok", "response": response})

    elif intent == "balance_check":
        # If you have a balance check handler, call it here.
        # Otherwise, fallback to FAQ.
        result = handle_faq(user_id, query)
        return jsonify({"status": "ok", "response": result})

    else:
        # Default fallback - FAQ or unrecognized intent
        result = handle_faq(user_id, query)
        return jsonify({"status": "ok", "response": result})



@app.route("/transfer", methods=["POST"])
def transfer():
    data = request.json or {}
    user_id = int(data.get("user_id", 1))
    user_state = get_user_state(user_id)

    user_input = data.get("query")
    otp = data.get("otp")

    # Require query if no OTP and not confirmation
    if otp is None and not user_input and user_state["phase"] == ConversationPhase.NORMAL:
        return jsonify({"status": "error", "message": "'query' is required"}), 400

    # ----- Confirmation step -----
    if user_state["phase"] == ConversationPhase.CONFIRMATION:
        user_state["user_input"] = user_input
        user_state["intent"] = "confirmation"
        result = graph.invoke(user_state)
        save_user_state(user_id, result)
        return jsonify({"status": "ok", "response": result["result"]})

    # ----- OTP step -----
    if user_state["phase"] == ConversationPhase.OTP:
        otp_val = otp or user_input
        user_state["user_input"] = str(otp_val) if otp_val else ""
        user_state["intent"] = "otp"
        result = graph.invoke(user_state)
        save_user_state(user_id, result)
        return jsonify({"status": "ok", "response": result["result"]})

    # ----- Normal transfer -----
    try:
        resp = handle_transfer(user_id, user_input, otp)
    except Exception as e:
        logger.exception("Transfer failed")
        return jsonify({"status": "error", "message": f"Transfer failed: {e}"}), 400

    user_state["user_input"] = user_input
    user_state["result"] = resp

    # Phase updates
    if resp.get("status") == "otp_required":
        user_state["phase"] = ConversationPhase.OTP
        user_state["pending_transfer"] = {
            "query": user_input,
            "transfer_details": resp.get("transfer_details"),
        }
    elif resp.get("status") == "success" and resp.get("recommendation"):
        user_state["phase"] = ConversationPhase.CONFIRMATION
        user_state["confirmation_context"] = {
            "action": "confirm_recommendation",
            "details": resp,
        }
    else:
        user_state["phase"] = ConversationPhase.NORMAL
        user_state["pending_transfer"] = None
        user_state["confirmation_context"] = None

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