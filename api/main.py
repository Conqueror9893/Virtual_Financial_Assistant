# api/main.py
from flask import Flask, request, jsonify
from flask_cors import CORS
from threading import Lock
import requests
import json
from langgraph_flow.nodes.spend_insights_node import handle_spend_insight
from langgraph_flow.nodes.output_formatter import format_spend_response
from langgraph_flow.nodes.faq_node import handle_faq
from langgraph_flow.nodes.offers_node import handle_offers
from langgraph_flow.nodes.transfer_node import handle_transfer
from langgraph_flow.nodes.intent_classifier import classify_intent
from utils.llm_connector import run_llm
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


def llm_format_chat_response(raw_response: dict, user_query: str) -> str:
    """
    Use LLM to convert structured backend responses into friendly chat replies.
    Ensures recommendation (if present) is preserved exactly as-is.
    """

    # Flatten nested responses (if any)
    if "response" in raw_response and isinstance(raw_response["response"], dict):
        inner = raw_response["response"]
        # Merge inner dict if it's nested under another "response"
        if "response" in inner and isinstance(inner["response"], dict):
            raw_response = inner["response"]
        else:
            raw_response = inner

    recommendation = raw_response.get("recommendation")
    flattened_json = json.dumps(raw_response, indent=2)

    # --- Prompt for LLM ---
    prompt = f"""
You are a helpful, professional banking assistant.
The user asked: "{user_query}"

Here is the structured backend response:
{flattened_json}

Your task:
1. Formulate a concise, conversational reply describing what happened.
2. Summarize the key info like amount, beneficiary, and status clearly.
3. Avoid exposing internal keys or JSON formatting.
4. Keep the tone polite and human, suitable for an in-app chatbot.

Currency is INR. Use the same currency in your response.
Do not start the response with "As an AI language model" or with greetings like "Hi" or "Hello". Also do not with "Best regards".
"""

    llm_output = run_llm(prompt)

    # Fallbacks if LLM fails
    if not llm_output:
        if recommendation:
            return f"{raw_response.get('message', '')}\n\n{recommendation}"
        return raw_response.get("message", str(raw_response))

    # # Ensure recommendation is preserved if LLM trimmed it out
    # if recommendation and recommendation not in llm_output:
    #     llm_output += f"\n\n{recommendation}"
    logger.info("LLM chat response: %s", llm_output)
    return llm_output


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
        return jsonify({"status": "error", "message": "'query' or 'otp' is required"}), 400

    user_state = get_user_state(user_id)
    current_phase = user_state.get("phase", ConversationPhase.NORMAL)

    if current_phase in (ConversationPhase.OTP, ConversationPhase.CONFIRMATION):
        return handle_transfer_phase(user_id, user_state, query, otp)

    return handle_normal_phase(user_id, user_state, query, otp)

def handle_transfer_phase(user_id, user_state, query, otp):
    current_phase = user_state.get("phase", ConversationPhase.NORMAL)
    text = (query or "").strip()

    if current_phase == ConversationPhase.CONFIRMATION:
        logger.info("Handling confirmation phase with input: %s", text)
        return handle_confirmation_phase(user_id, user_state, text)

    if text.lower() in ("yes", "y", "cancel", "abort"):
        return cancel_pending_transfer(user_id, user_state)

    if text.lower() in ("no", "n", "continue"):
        return jsonify({
            "status": "ok",
            "response": "Okay - please continue with your pending transfer (for example, provide the OTP).",
        })

    otp_candidate = get_otp_candidate(query, otp)
    if otp_candidate:
        return process_otp(user_id, user_state, otp_candidate)

    return jsonify({
        "status": "pending_cancel",
        "response": "You have a pending transfer. Do you want to cancel it and continue with your new request?",
    })

def handle_confirmation_phase(user_id, user_state, text):
    """
    Handles the confirmation phase safely, with proper JSON decode protection.
    """
    lower_text = text.lower()

    if lower_text in ("yes", "y"):
        user_state["phase"] = ConversationPhase.CONFIRMATION
        user_state["user_input"] = "CONFIRM_YES"
        save_user_state(user_id, user_state)

        try:
            r = requests.post(
                f"{API_BASE}/transfer",
                json={"user_id": user_id, "query": "CONFIRM_YES"},
                timeout=10,  # optional: avoid hanging
            )
            try:
                resp = r.json()
            except requests.JSONDecodeError:
                logger.error(
                    "Invalid JSON from transfer API (CONFIRM_YES): status=%s, text=%s",
                    r.status_code, r.text
                )
                return jsonify({
                    "status": "error",
                    "message": "Transfer API returned invalid response",
                    "raw": r.text,
                    "http_status": r.status_code
                }), 500

            return jsonify({"response": resp})

        except requests.RequestException as e:
            logger.exception("Transfer API request failed")
            return jsonify({
                "status": "error",
                "message": f"Transfer API request failed: {e}"
            }), 500

    elif lower_text in ("no", "n"):
        user_state["phase"] = ConversationPhase.CONFIRMATION
        user_state["user_input"] = "CONFIRM_NO"
        save_user_state(user_id, user_state)

        try:
            r = requests.post(
                f"{API_BASE}/transfer",
                json={"user_id": user_id, "query": "CONFIRM_NO"},
                timeout=10,
            )
            try:
                resp = r.json()
            except requests.JSONDecodeError:
                logger.error(
                    "Invalid JSON from transfer API (CONFIRM_NO): status=%s, text=%s",
                    r.status_code, r.text
                )
                return jsonify({
                    "status": "error",
                    "message": "Transfer API returned invalid response",
                    "raw": r.text,
                    "http_status": r.status_code
                }), 500

            return jsonify({"status": "ok", "response": resp})

        except requests.RequestException as e:
            logger.exception("Transfer API request failed")
            return jsonify({
                "status": "error",
                "message": f"Transfer API request failed: {e}"
            }), 500

    else:
        return jsonify({
            "status": "pending_cancel",
            "response": "Please reply yes/no for the recommendation, or cancel the flow.",
        })


def cancel_pending_transfer(user_id, user_state):
    try:
        cancel_resp = requests.post(
            f"{API_BASE}/transfer/cancel", json={"user_id": user_id}
        ).json()
    except Exception as e:
        logger.exception("transfer/cancel failed")
        return jsonify({
            "status": "error",
            "message": f"Failed to cancel pending transfer: {e}",
        }), 500

    user_state["phase"] = ConversationPhase.NORMAL
    user_state["pending_transfer"] = None
    user_state["confirmation_context"] = None
    save_user_state(user_id, user_state)

    return jsonify({"status": "ok", "response": cancel_resp})

def get_otp_candidate(query, otp):
    if otp:
        otp_candidate = str(otp).strip()
        if otp_candidate.isdigit():
            return otp_candidate
    elif query and query.strip().isdigit() and 3 <= len(query.strip()) <= 8:
        return query.strip()
    return None

def process_otp(user_id, user_state, otp_candidate):
    try:
        resp = requests.post(
            f"{API_BASE}/transfer",
            json={"user_id": user_id, "otp": otp_candidate},
        ).json()
    except Exception as e:
        logger.exception("Transfer service call failed")
        return jsonify({"status": "error", "message": f"Transfer service failed: {e}"}), 500

    inner_resp = resp.get("response", resp)
    if isinstance(inner_resp, dict) and "response" in inner_resp:
        inner_resp = inner_resp["response"]

    user_query_for_llm = otp_candidate
    llm_text = llm_format_chat_response(inner_resp, user_query_for_llm)

    if inner_resp.get("recommendation"):
        final_response = {
            "message": llm_text,
            "recommendation": inner_resp["recommendation"],
            "recommendation_id": inner_resp.get("recommendation_id"),
        }
    else:
        final_response = {"message": llm_text}

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
    return jsonify({"status": "ok", "response": final_response})

def handle_normal_phase(user_id, user_state, query, otp):
    try:
        intent_resp = requests.post(f"{API_BASE}/intent", json={"query": query}).json()
        intent = intent_resp.get("intent", "faq")
    except Exception as e:
        logger.exception("Intent service failed")
        return jsonify({"status": "error", "message": f"Intent service failed: {e}"}), 500

    try:
        resp = dispatch_intent(intent, user_id, query, otp)
    except Exception as e:
        logger.exception("Downstream API call failed")
        return jsonify({"status": "error", "message": f"Service call failed: {e}"}), 500

    inner_resp = resp.get("response") if isinstance(resp.get("response"), dict) else resp
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
    user_query_for_llm = query or otp or ""
    chat_reply = llm_format_chat_response(inner_resp, user_query_for_llm)
    return jsonify({"status": "ok", "response": chat_reply})

def dispatch_intent(intent, user_id, query, otp):
    if intent == "fund_transfer":
        return requests.post(
            f"{API_BASE}/transfer",
            json={"user_id": user_id, "query": query, "otp": otp},
        ).json()
    elif intent == "spends_check":
        return requests.post(
            f"{API_BASE}/spend", json={"user_id": user_id, "query": query}
        ).json()
    elif intent == "balance_check":
        return requests.post(
            f"{API_BASE}/faq", json={"user_id": user_id, "query": query}
        ).json()
    elif intent == "offers":
        return requests.post(
            f"{API_BASE}/offers",
            json={"user_id": user_id, "query": query or "Show me offers"},
        ).json()
    else:
        return requests.post(
            f"{API_BASE}/faq", json={"user_id": user_id, "query": query}
        ).json()


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
        logger.info("Handling confirmation step with input: %s", user_input)
        # --- NEW: Handle explicit confirmation input ---
        if user_input in ("CONFIRM_YES", "CONFIRM_NO"):
            user_state["user_input"] = user_input
            logger.info("User confirmation input: %s", user_input)
            user_state["intent"] = "confirmation"
            result = graph.invoke(user_state)
            save_user_state(user_id, result)
            logger.info("Confirmation result: %s", result)
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
