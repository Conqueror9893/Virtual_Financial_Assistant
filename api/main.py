# api/main.py
from flask import Flask, request, jsonify
from flask_cors import CORS
from threading import Lock
import requests
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

API_BASE = "http://10.32.2.151:3009"

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
        "phase": ConversationPhase.NORMAL,  # unified phase management
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
    return jsonify(
        {
            "status": "ok",
            "intent": result_state.get("intent", "faq"),
            "confidence": result_state.get("confidence", 0.0),
        }
    )


@app.route("/chatbot", methods=["POST"])
def chatbot():
    data = request.json or {}
    user_id = int(data.get("user_id", 1))
    query = data.get("query")
    otp = data.get("otp")

    if not query and not otp:
        return (
            jsonify({"status": "error", "message": "'query' or 'otp' is required"}),
            400,
        )

    user_state = get_user_state(user_id)
    current_phase = user_state.get("phase", ConversationPhase.NORMAL)

    # ---------------------------
    # If user is already in a transfer-related phase, prioritize transfer flow
    # ---------------------------
    if current_phase in (ConversationPhase.OTP, ConversationPhase.CONFIRMATION):
        text = (query or "").strip()

        # --- NEW: Explicit confirmation handling for CONFIRMATION phase ---
        if current_phase == ConversationPhase.CONFIRMATION:
            lower_text = text.lower()
            if lower_text in ("yes", "y"):
                user_state["phase"] = ConversationPhase.CONFIRMATION
                save_user_state(user_id, user_state)
                resp = requests.post(
                    f"{API_BASE}/transfer",
                    json={"user_id": user_id, "query": "CONFIRM_YES"},
                ).json()
                return jsonify({"status": "ok", "response": resp})  # <--- ADD THIS
            elif lower_text in ("no", "n"):
                user_state["phase"] = ConversationPhase.CONFIRMATION
                save_user_state(user_id, user_state)
                resp = requests.post(
                    f"{API_BASE}/transfer",
                    json={"user_id": user_id, "query": "CONFIRM_NO"},
                ).json()
                return jsonify({"status": "ok", "response": resp})  # <--- ADD THIS
            else:
                return jsonify(
                    {
                        "status": "pending_cancel",
                        "response": "Please reply yes/no for the recommendation, or cancel the flow.",
                    }
                )

        # 1) Explicit cancellation confirmation
        if text.lower() in ("yes", "y", "cancel", "abort"):
            try:
                cancel_resp = requests.post(
                    f"{API_BASE}/transfer/cancel", json={"user_id": user_id}
                ).json()
            except Exception as e:
                logger.exception("transfer/cancel failed")
                return (
                    jsonify(
                        {
                            "status": "error",
                            "message": f"Failed to cancel pending transfer: {e}",
                        }
                    ),
                    500,
                )

            user_state["phase"] = ConversationPhase.NORMAL
            user_state["pending_transfer"] = None
            user_state["confirmation_context"] = None
            save_user_state(user_id, user_state)

            return jsonify({"status": "ok", "response": cancel_resp})

        # 2) User explicitly chooses to continue
        if text.lower() in ("no", "n", "continue"):
            return jsonify(
                {
                    "status": "ok",
                    "response": "Okay - please continue with your pending transfer (for example, provide the OTP).",
                }
            )

        # 3) If the user input looks like an OTP (digits of reasonable length), forward to transfer as OTP
        looks_like_otp = False
        otp_candidate = None
        if otp:
            otp_candidate = str(otp).strip()
            looks_like_otp = otp_candidate.isdigit()
        elif query and query.strip().isdigit() and 3 <= len(query.strip()) <= 8:
            otp_candidate = query.strip()
            looks_like_otp = True

        if looks_like_otp:
            try:
                resp = requests.post(
                    f"{API_BASE}/transfer",
                    json={"user_id": user_id, "otp": otp_candidate},
                ).json()
            except Exception as e:
                logger.exception("Transfer service call failed")
                return (
                    jsonify(
                        {"status": "error", "message": f"Transfer service failed: {e}"}
                    ),
                    500,
                )

            status = resp.get("status")
            logger.info(f"Transfer response status: {status}")
            if status == "otp_required":
                user_state["phase"] = ConversationPhase.OTP
                user_state["pending_transfer"] = resp.get("transfer_details")
            elif status == "success" and resp.get("recommendation"):
                user_state["phase"] = ConversationPhase.CONFIRMATION
                logger.info("Entering CONFIRMATION phase")
                user_state["confirmation_context"] = {
                    "action": "confirm_recommendation",
                    "details": resp,
                }
            else:
                logger.info("Transfer completed or failed, returning to NORMAL phase")
                user_state["phase"] = ConversationPhase.NORMAL
                user_state["pending_transfer"] = None
                user_state["confirmation_context"] = None

            save_user_state(user_id, user_state)
            return jsonify({"status": "ok", "response": resp})

        # 4) Otherwise: treat this as a new query attempt - ask for cancel confirmation
        return jsonify(
            {
                "status": "pending_cancel",
                "response": "You have a pending transfer. Do you want to cancel it and continue with your new request?",
            }
        )

    # ---------------------------
    # Not in a transfer phase: normal behavior -> call Intent API then dispatch
    # ---------------------------
    try:
        intent_resp = requests.post(f"{API_BASE}/intent", json={"query": query}).json()
        intent = intent_resp.get("intent", "faq")
    except Exception as e:
        logger.exception("Intent service failed")
        return (
            jsonify({"status": "error", "message": f"Intent service failed: {e}"}),
            500,
        )

    try:
        if intent == "fund_transfer":
            resp = requests.post(
                f"{API_BASE}/transfer",
                json={"user_id": user_id, "query": query, "otp": otp},
            ).json()
        elif intent == "spends_check":
            resp = requests.post(
                f"{API_BASE}/spend", json={"user_id": user_id, "query": query}
            ).json()
        elif intent == "balance_check":
            resp = requests.post(
                f"{API_BASE}/faq", json={"user_id": user_id, "query": query}
            ).json()
        elif intent == "offers":
            resp = requests.post(
                f"{API_BASE}/offers",
                json={"user_id": user_id, "query": query or "Show me offers"},
            ).json()
        else:
            resp = requests.post(
                f"{API_BASE}/faq", json={"user_id": user_id, "query": query}
            ).json()
    except Exception as e:
        logger.exception("Downstream API call failed")
        return jsonify({"status": "error", "message": f"Service call failed: {e}"}), 500

    inner_resp = (
        resp.get("response") if isinstance(resp.get("response"), dict) else resp
    )
    status = inner_resp.get("status")

    if status == "otp_required":
        user_state["phase"] = ConversationPhase.OTP
        user_state["pending_transfer"] = inner_resp.get("transfer_details")
    elif status == "success" and inner_resp.get("recommendation"):
        user_state["phase"] = ConversationPhase.CONFIRMATION
        user_state["confirmation_context"] = {
            "action": "confirm_recommendation",
            "details": inner_resp,
        }
    else:
        user_state["phase"] = ConversationPhase.NORMAL
        user_state["pending_transfer"] = None
        user_state["confirmation_context"] = None

    save_user_state(user_id, user_state)
    return jsonify({"status": "ok", "response": resp})


@app.route("/transfer", methods=["POST"])
def transfer():
    data = request.json or {}
    user_id = int(data.get("user_id", 1))
    user_state = get_user_state(user_id)

    user_input = data.get("query")
    otp = data.get("otp")

    # Require query if no OTP and not confirmation
    if (
        otp is None
        and not user_input
        and user_state["phase"] == ConversationPhase.NORMAL
    ):
        return jsonify({"status": "error", "message": "'query' is required"}), 400

    # ----- Confirmation step -----
    if user_state["phase"] == ConversationPhase.CONFIRMATION:
        # --- NEW: Handle explicit confirmation input ---
        if user_input in ("CONFIRM_YES", "CONFIRM_NO"):
            user_state["user_input"] = user_input
            user_state["intent"] = "confirmation"
            result = graph.invoke(user_state)
            save_user_state(user_id, result)
            return jsonify({"status": "ok", "response": result["result"]})
        else:
            return (
                jsonify(
                    {
                        "status": "error",
                        "message": "Invalid input during confirmation. Please reply CONFIRM_YES or CONFIRM_NO.",
                    }
                ),
                400,
            )

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


@app.route("/transfer/cancel", methods=["POST"])
def cancel_transfer():
    data = request.json or {}
    user_id = int(data.get("user_id", 1))

    user_state = get_user_state(user_id)

    # Reset transfer-related state
    user_state["phase"] = ConversationPhase.NORMAL
    user_state["pending_transfer"] = None
    user_state["confirmation_context"] = None
    user_state["user_input"] = ""
    user_state["result"] = ""

    save_user_state(user_id, user_state)

    return jsonify(
        {
            "status": "ok",
            "message": "Pending transfer has been cancelled. You can continue with your new request.",
        }
    )


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
    app.run(debug=True, host="0.0.0.0", port=3009)
