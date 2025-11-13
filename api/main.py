# api/main.py - Refactored for new LangGraph structure

"""
Flask Backend for Virtual Financial Assistant

Uses refactored LangGraph with:
- Centralized state management
- Isolated transfer flow
- Clean routing
"""

from flask import Flask, request, jsonify
from flask_cors import CORS
from threading import Lock
import requests
import json
import logging

# ============================================================================
# IMPORTS - Updated for new structure
# ============================================================================

from langgraph_flow.flows.main_flow import build_main_flow
from langgraph_flow.core.state import StateManager, AgentState
from langgraph_flow.core.constants import ConversationPhase, IntentType
from langgraph_flow.services.intent_classifier import IntentClassifier

# Keep your existing handlers
from langgraph_flow.handlers.spend_insights_node import handle_spend_insight
from langgraph_flow.handlers.faq_node import handle_faq
from langgraph_flow.handlers.offers_node import handle_offers
from langgraph_flow.handlers.transfer_node import handle_transfer
from utils.llm_connector import run_llm
from utils.logger import get_logger
from utils.output_formatter import format_spend_response


# ============================================================================
# SETUP
# ============================================================================

app = Flask(__name__)
CORS(app)
logger = get_logger(__name__)

API_BASE = "http://10.32.2.151:3009"

# Build the LangGraph once at startup
graph = build_main_flow()

# In-memory user state store (keyed by user_id)
user_states = {}
state_lock = Lock()


# ============================================================================
# STATE MANAGEMENT
# ============================================================================

def create_default_state() -> AgentState:
    """Create a new default state for a user."""
    state: AgentState = {
        "user_input": "",
        "intent": IntentType.UNKNOWN,
        "result": "",
        "phase": ConversationPhase.NORMAL,
        "otp_attempts": 0,
        "pending_transfer": None,
        "confirmation_context": None,
        "user_id": "1",
    }
    StateManager.ensure_defaults(state)
    return state


def get_user_state(user_id: str) -> dict:
    """Get or create user state."""
    user_id_str = str(user_id)
    with state_lock:
        if user_id_str not in user_states:
            user_states[user_id_str] = create_default_state()
        return user_states[user_id_str]


def save_user_state(user_id: str, state: dict) -> None:
    """Save user state."""
    user_id_str = str(user_id)
    with state_lock:
        user_states[user_id_str] = state


def reset_user_state(user_id: str) -> None:
    """Reset user state to default."""
    user_id_str = str(user_id)
    with state_lock:
        user_states[user_id_str] = create_default_state()


# ============================================================================
# RESPONSE FORMATTING
# ============================================================================

def llm_format_chat_response(raw_response: dict, user_query: str) -> str:
    """
    Convert structured backend responses into friendly chat replies.
    Preserves recommendations exactly as-is.
    
    Args:
        raw_response: Structured response from handler
        user_query: Original user query for context
    
    Returns:
        Formatted chat response string
    """
    # Flatten nested responses
    if "response" in raw_response and isinstance(raw_response["response"], dict):
        inner = raw_response["response"]
        if "response" in inner and isinstance(inner["response"], dict):
            raw_response = inner["response"]
        else:
            raw_response = inner

    recommendation = raw_response.get("recommendation")
    flattened_json = json.dumps(raw_response, indent=2)

    prompt = f"""
You are a helpful, professional banking assistant.
The user asked: "{user_query}"

Here is the structured backend response:
{flattened_json}

Your task:
1. Keep the reply concise and direct (no extra details, no introduction).
2. Formulate a conversational reply describing what happened.
3. Summarize only the key info - amount, beneficiary. Do not add explanations.
4. Do not expose internal keys, raw JSON, or formatting.
5. Do not start with greetings ("Hi", "Hello", etc.).
6. Do not end with "Best regards" or similar.
7. Do not return status codes or raw JSON.
8. If there is a 'recommendation', preserve it verbatim in the reply.

Currency is USD. Use the same currency in your response. Start the reply directly.
"""

    try:
        llm_output = run_llm(prompt)
        if llm_output:
            logger.info("LLM formatted response: %s", llm_output[:100])
            
            # Ensure recommendation is preserved
            if recommendation and recommendation not in llm_output:
                llm_output += f"\n\n{recommendation}"
            
            return llm_output
    except Exception as e:
        logger.warning(f"LLM formatting failed: {e}")

    # Fallback if LLM fails
    if recommendation:
        return f"{raw_response.get('message', '')}\n\n{recommendation}"
    return raw_response.get("message", str(raw_response))


def extract_response_from_result(result: dict) -> dict:
    """Extract and format response from LangGraph result."""
    raw_response = result.get("result", {})
    
    # Flatten nested responses
    if isinstance(raw_response, dict) and "response" in raw_response:
        if isinstance(raw_response["response"], dict):
            raw_response = raw_response["response"]
    
    return raw_response


# ============================================================================
# HEALTH CHECK
# ============================================================================

@app.route("/api/health", methods=["GET"])
def health():
    """Health check endpoint."""
    return jsonify({"status": "ok", "service": "virtual_financial_assistant"})


# ============================================================================
# INTENT DETECTION
# ============================================================================

@app.route("/intent", methods=["POST"])
def intent():
    """
    Detect user intent from query.
    
    Request:
        {"query": "Show me spending"}
    
    Response:
        {"status": "ok", "intent": "spend", "confidence": 0.95}
    """
    data = request.json or {}
    query = data.get("query", "").strip()
    
    if not query:
        return jsonify({"status": "error", "message": "'query' is required"}), 400

    try:
        intent = IntentClassifier.classify(query)
        confidence = 0.85  # Default confidence
        
        return jsonify({
            "status": "ok",
            "intent": intent,
            "confidence": confidence,
        })
    except Exception as e:
        logger.exception("Intent classification failed")
        return jsonify({
            "status": "error",
            "message": f"Intent classification failed: {e}"
        }), 500


# ============================================================================
# VOICE ENDPOINT
# ============================================================================

@app.route("/voice", methods=["POST"])
def voice():
    """
    Handle voice interaction.
    
    Request:
        {"user_id": 1, "query": "Show my spending"}
    
    Response:
        {"status": "ok", "response": "..."}
    """
    data = request.json or {}
    user_id = str(data.get("user_id", "1"))
    query = data.get("query", "").strip()
    
    if not query:
        return jsonify({"status": "error", "message": "'query' is required"}), 400

    try:
        user_state = get_user_state(user_id)
        StateManager.ensure_defaults(user_state)
        
        # Set user input and run graph
        user_state["user_input"] = query
        user_state["intent"] = IntentType.UNKNOWN  # Let classifier determine
        
        result = graph.invoke(user_state)
        save_user_state(user_id, result)
        
        return jsonify({
            "status": "ok",
            "response": result.get("result", "No response"),
            "phase": str(result.get("phase", ConversationPhase.NORMAL)),
        })
    except Exception as e:
        logger.exception("Voice processing failed")
        return jsonify({
            "status": "error",
            "message": f"Voice processing failed: {e}"
        }), 500


# ============================================================================
# MAIN CHATBOT ENDPOINT
# ============================================================================

@app.route("/chatbot", methods=["POST"])
def chatbot():
    """
    Main chatbot endpoint.
    
    Handles all user queries and manages conversation state.
    Routes to appropriate handlers based on phase and intent.
    
    Request:
        {"user_id": 1, "query": "...", "otp": "..."}
    
    Response:
        {"status": "ok", "response": {...}}
    """
    data = request.json or {}
    user_id = str(data.get("user_id", "1"))
    query = data.get("query", "").strip()
    otp = data.get("otp", "").strip()
    
    if not query and not otp:
        return jsonify({
            "status": "error",
            "message": "'query' or 'otp' is required"
        }), 400

    try:
        user_state = get_user_state(user_id)
        StateManager.ensure_defaults(user_state)
        
        phase = StateManager.get_phase(user_state)
        
        # Route based on current phase
        if phase == ConversationPhase.OTP:
            return handle_otp_phase(user_id, user_state, query, otp)
        elif phase == ConversationPhase.CONFIRMATION:
            return handle_confirmation_phase_route(user_id, user_state, query)
        else:
            return handle_normal_phase_route(user_id, user_state, query)
    
    except Exception as e:
        logger.exception("Chatbot request failed")
        return jsonify({
            "status": "error",
            "message": f"Chatbot processing failed: {e}"
        }), 500


# ============================================================================
# PHASE HANDLERS
# ============================================================================

def handle_otp_phase(user_id: str, user_state: dict, query: str, otp: str) -> tuple:
    """
    Handle OTP phase.
    
    In this phase, user must provide OTP.
    """
    logger.info("Handling OTP phase for user %s", user_id)
    
    # Determine OTP candidate
    otp_candidate = otp or (query if query.strip().isdigit() else None)
    
    if not otp_candidate:
        return jsonify({
            "status": "pending_otp",
            "response": "Please provide the OTP sent to your registered email/phone."
        }), 200
    
    try:
        user_state["user_input"] = otp_candidate
        user_state["intent"] = IntentType.OTP
        
        # Invoke graph to handle OTP validation
        result = graph.invoke(user_state)
        save_user_state(user_id, result)
        
        response = extract_response_from_result(result)
        
        return jsonify({
            "status": "ok",
            "response": response,
            "phase": str(result.get("phase", ConversationPhase.NORMAL)),
        }), 200
    
    except Exception as e:
        logger.exception("OTP validation failed")
        return jsonify({
            "status": "error",
            "message": f"OTP validation failed: {e}"
        }), 500


def handle_confirmation_phase_route(user_id: str, user_state: dict, query: str) -> tuple:
    """
    Handle confirmation phase.
    
    User must reply 'yes' or 'no' to confirm recommendation.
    """
    logger.info("Handling confirmation phase for user %s with input: %s", user_id, query)
    
    if not query:
        return jsonify({
            "status": "pending_confirmation",
            "response": "Please reply 'yes' or 'no' to the recommendation."
        }), 200
    
    try:
        # Normalize confirmation input
        normalized = query.lower().strip()
        
        if normalized not in ("yes", "no"):
            return jsonify({
                "status": "pending_confirmation",
                "response": "Please reply 'yes' or 'no' to the recommendation, or 'cancel' to abort."
            }), 200
        
        user_state["user_input"] = normalized
        user_state["intent"] = IntentType.CONFIRMATION
        
        # Invoke graph to handle confirmation
        result = graph.invoke(user_state)
        save_user_state(user_id, result)
        
        response = extract_response_from_result(result)
        
        return jsonify({
            "status": "ok",
            "response": response,
            "phase": str(result.get("phase", ConversationPhase.NORMAL)),
        }), 200
    
    except Exception as e:
        logger.exception("Confirmation handling failed")
        return jsonify({
            "status": "error",
            "message": f"Confirmation failed: {e}"
        }), 500


def handle_normal_phase_route(user_id: str, user_state: dict, query: str) -> tuple:
    """
    Handle normal phase.
    
    Classify intent and route to appropriate handler.
    """
    logger.info("Handling normal phase for user %s with query: %s", user_id, query[:50])
    
    try:
        user_state["user_input"] = query
        user_state["intent"] = IntentType.UNKNOWN  # Let classifier determine
        
        # Invoke graph - it will classify and route
        result = graph.invoke(user_state)
        save_user_state(user_id, result)
        
        response = extract_response_from_result(result)
        
        return jsonify({
            "status": "ok",
            "response": response,
            "phase": str(result.get("phase", ConversationPhase.NORMAL)),
        }), 200
    
    except Exception as e:
        logger.exception("Normal phase handling failed")
        return jsonify({
            "status": "error",
            "message": f"Processing failed: {e}"
        }), 500


# ============================================================================
# TRANSFER ENDPOINT
# ============================================================================

@app.route("/transfer", methods=["POST"])
def transfer():
    """
    Handle fund transfer requests.
    
    Manages:
    - Initial transfer validation
    - OTP phase
    - Confirmation phase
    
    Request:
        {"user_id": 1, "query": "Transfer $100 to John", "otp": "123456"}
    
    Response:
        {"status": "ok", "response": {...}}
    """
    data = request.json or {}
    user_id = str(data.get("user_id", "1"))
    query = data.get("query", "").strip()
    otp = data.get("otp", "").strip()
    
    try:
        user_state = get_user_state(user_id)
        StateManager.ensure_defaults(user_state)
        
        phase = StateManager.get_phase(user_state)
        
        # Route based on phase
        if phase == ConversationPhase.OTP:
            logger.info("Transfer in OTP phase")
            user_state["user_input"] = otp or query
            user_state["intent"] = IntentType.OTP
            result = graph.invoke(user_state)
        
        elif phase == ConversationPhase.CONFIRMATION:
            logger.info("Transfer in CONFIRMATION phase")
            user_state["user_input"] = query or otp
            user_state["intent"] = IntentType.CONFIRMATION
            result = graph.invoke(user_state)
        
        else:
            # Normal phase - initiate transfer
            if not query:
                return jsonify({
                    "status": "error",
                    "message": "'query' is required to initiate transfer"
                }), 400
            
            logger.info("Transfer initiating for user %s", user_id)
            user_state["user_input"] = query
            user_state["intent"] = IntentType.TRANSFER
            result = graph.invoke(user_state)
        
        save_user_state(user_id, result)
        response = extract_response_from_result(result)
        
        return jsonify({
            "status": "ok",
            "response": response,
            "phase": str(result.get("phase", ConversationPhase.NORMAL)),
        }), 200
    
    except Exception as e:
        logger.exception("Transfer failed")
        return jsonify({
            "status": "error",
            "message": f"Transfer failed: {e}"
        }), 500


@app.route("/transfer/cancel", methods=["POST"])
def cancel_transfer():
    """
    Cancel pending transfer and reset state.
    
    Request:
        {"user_id": 1}
    
    Response:
        {"status": "ok", "message": "Transfer cancelled"}
    """
    data = request.json or {}
    user_id = str(data.get("user_id", "1"))
    
    try:
        user_state = get_user_state(user_id)
        StateManager.reset_transfer_state(user_state)
        user_state["phase"] = ConversationPhase.NORMAL
        user_state["intent"] = IntentType.UNKNOWN
        save_user_state(user_id, user_state)
        
        logger.info("Transfer cancelled for user %s", user_id)
        
        return jsonify({
            "status": "ok",
            "message": "Pending transfer has been cancelled. You can continue with your new request."
        }), 200
    
    except Exception as e:
        logger.exception("Transfer cancellation failed")
        return jsonify({
            "status": "error",
            "message": f"Cancellation failed: {e}"
        }), 500


# ============================================================================
# INDIVIDUAL INTENT ENDPOINTS
# ============================================================================

@app.route("/spend", methods=["POST"])
def spend():
    """
    Get spending insights.
    
    Request:
        {"user_id": 1, "query": "Show my spending"}
    
    Response:
        {"status": "ok", "response": {...}}
    """
    data = request.json or {}
    user_id = str(data.get("user_id", "1"))
    query = data.get("query", "").strip()
    
    if not query:
        return jsonify({
            "status": "error",
            "message": "'query' is required"
        }), 400
    
    try:
        insight = handle_spend_insight(user_id, query)
        response = format_spend_response(insight)
        
        return jsonify(response), 200
    except Exception as e:
        logger.exception("Spend endpoint failed")
        return jsonify({
            "status": "error",
            "message": f"Spend analysis failed: {e}"
        }), 500


@app.route("/faq", methods=["POST"])
def faq():
    """
    Get FAQ answers.
    
    Request:
        {"user_id": 1, "query": "How do I reset my password?"}
    
    Response:
        {"status": "ok", "answer": "...", "sources": [...]}
    """
    data = request.json or {}
    user_id = str(data.get("user_id", "1"))
    query = data.get("query", "").strip()
    
    if not query:
        return jsonify({
            "status": "error",
            "message": "'query' is required"
        }), 400
    
    try:
        result = handle_faq(user_id, query)
        return jsonify(result), 200
    except Exception as e:
        logger.exception("FAQ endpoint failed")
        return jsonify({
            "status": "error",
            "message": f"FAQ lookup failed: {e}"
        }), 500


@app.route("/offers", methods=["POST"])
def offers():
    """
    Get current offers.
    
    Request:
        {"user_id": 1, "query": "Show me offers"}
    
    Response:
        {"status": "ok", "offers": [...]}
    """
    data = request.json or {}
    user_id = str(data.get("user_id", "1"))
    query = data.get("query", "Show me offers").strip()
    
    try:
        result = handle_offers(user_id, query)
        return jsonify(result), 200
    except Exception as e:
        logger.exception("Offers endpoint failed")
        return jsonify({
            "status": "error",
            "message": f"Offers retrieval failed: {e}"
        }), 500


# ============================================================================
# USER MANAGEMENT (Optional)
# ============================================================================

@app.route("/user/reset", methods=["POST"])
def reset_user():
    """
    Reset user state.
    
    Request:
        {"user_id": 1}
    
    Response:
        {"status": "ok", "message": "State reset"}
    """
    data = request.json or {}
    user_id = str(data.get("user_id", "1"))
    
    try:
        reset_user_state(user_id)
        logger.info("User state reset for user %s", user_id)
        
        return jsonify({
            "status": "ok",
            "message": "User state has been reset"
        }), 200
    except Exception as e:
        logger.exception("User reset failed")
        return jsonify({
            "status": "error",
            "message": f"Reset failed: {e}"
        }), 500


@app.route("/user/state", methods=["GET"])
def get_state():
    """
    Get current user state (for debugging).
    
    Query params:
        ?user_id=1
    
    Response:
        {"status": "ok", "state": {...}}
    """
    user_id = str(request.args.get("user_id", "1"))
    
    try:
        user_state = get_user_state(user_id)
        
        # Convert non-serializable objects to strings
        safe_state = {
            k: str(v) if not isinstance(v, (str, int, float, bool, list, dict, type(None))) else v
            for k, v in user_state.items()
        }
        
        return jsonify({
            "status": "ok",
            "state": safe_state
        }), 200
    except Exception as e:
        logger.exception("Get state failed")
        return jsonify({
            "status": "error",
            "message": f"Get state failed: {e}"
        }), 500


# ============================================================================
# ERROR HANDLERS
# ============================================================================

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors."""
    return jsonify({
        "status": "error",
        "message": "Endpoint not found"
    }), 404


@app.errorhandler(500)
def server_error(error):
    """Handle 500 errors."""
    logger.exception("Server error occurred")
    return jsonify({
        "status": "error",
        "message": "Internal server error"
    }), 500


# ============================================================================
# MAIN
# ============================================================================

if __name__ == "__main__":
    logger.info("Starting Virtual Financial Assistant API")
    logger.info("LangGraph initialized with transfer flow isolation")
    app.run(debug=True, host="0.0.0.0", port=3009)
