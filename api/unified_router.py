from flask import Blueprint, request, jsonify
from threading import Lock
from langgraph_flow.langgraph_flow import build_flow, ConversationPhase, ensure_state_defaults

# Simple in-memory store for conversation state keyed by user_id
user_states = {}
state_lock = Lock()
graph = build_flow()

unified_api = Blueprint('unified_api', __name__)

def get_user_state(user_id):
    """Gets or creates a default state for a user."""
    with state_lock:
        if user_id not in user_states:
            # Use the same default structure as your graph expects
            user_states[user_id] = {
                "user_id": str(user_id),
                "phase": ConversationPhase.NORMAL,
            }
        # Ensure all defaults are present on every load
        return ensure_state_defaults(user_states[user_id].copy())

def save_user_state(user_id, state):
    """Saves the state for a user."""
    with state_lock:
        user_states[user_id] = state

@unified_api.route("/chat", methods=["POST"])
def unified_query():
    """Single entry point for all user queries."""
    data = request.json or {}
    user_id = str(data.get("user_id", "1"))
    query = data.get("query")

    if not query:
        return jsonify({"status": "error", "message": "'query' is required"}), 400

    # Get the current state for the user
    current_state = get_user_state(user_id)

    # Update state with the new user input
    current_state["user_input"] = query

    # Invoke the langgraph flow
    # The graph will handle everything: intent classification, interruptions, state transitions
    next_state = graph.invoke(current_state)

    # Save the updated state
    save_user_state(user_id, next_state)

    # The 'result' key in the state should contain the response for the user
    response_data = next_state.get("result", "Sorry, something went wrong.")

    return jsonify({
        "status": "ok",
        "response": response_data,
        "state": {k: v for k, v in next_state.items() if k != 'result'} # For debugging
    })
