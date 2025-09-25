
# langraph_flow/langraph_flow.py
from langgraph.graph import StateGraph, END
from typing import TypedDict, Literal, Optional, Dict, Any
from enum import Enum
import json
import logging

# Import your usecase handlers
from .nodes.spend_insights_node import handle_spend_insight
from .nodes.faq_node import handle_faq
from .nodes.offers_node import handle_offers
from .nodes.transfer_node import handle_transfer, confirm_recommendation
from utils.logger import get_logger
from utils.llm_connector import run_llm

logger = get_logger("LangGraphFlow")
# Fall back to std logging if custom logger misconfigured
if not logger:
    logger = logging.getLogger("LangGraphFlow")
    logging.basicConfig(level=logging.INFO)

# ---------- Conversation Phase Enum ----------
class ConversationPhase(str, Enum):
    NORMAL = "normal"
    OTP = "otp"
    CONFIRMATION = "confirmation"
    INTERRUPTION_CONFIRMATION = "interruption_confirmation"

# ---------- State Definition ----------
class AgentState(TypedDict, total=False):
    user_input: str
    intent: Literal["spend", "faq", "offers", "transfer", "otp", "confirmation", "unknown", "interruption_confirmation"]
    result: Any
    phase: ConversationPhase
    otp_attempts: int
    pending_transfer: Optional[Dict]
    confirmation_context: Optional[Dict]
    user_id: str
    interrupted_state: Optional[Dict]

# ---------- Helpers ----------
VALID_INTENTS = {"spend", "faq", "offers", "transfer"}
CONFIRMATION_HANDLERS = {
    "confirm_recommendation": confirm_recommendation,
}

def to_phase(value: Any) -> ConversationPhase:
    """Normalize phase whether it's a string or ConversationPhase."""
    if isinstance(value, ConversationPhase):
        return value
    if isinstance(value, str):
        v = value.lower()
        if v == "otp":
            return ConversationPhase.OTP
        if v == "confirmation":
            return ConversationPhase.CONFIRMATION
        return ConversationPhase.NORMAL
    return ConversationPhase.NORMAL

def ensure_state_defaults(state: Dict[str, Any]) -> Dict[str, Any]:
    """Make sure required keys exist with sane defaults. Mutates and returns state."""
    state.setdefault("user_input", "")
    state.setdefault("intent", "unknown")
    state.setdefault("result", "")
    state.setdefault("phase", ConversationPhase.NORMAL)  # may be overwritten below
    # Accept string phase from external callers (e.g., API), normalize it
    state["phase"] = to_phase(state.get("phase", ConversationPhase.NORMAL))
    state.setdefault("otp_attempts", 0)
    # Ensure numeric attempts
    try:
        state["otp_attempts"] = int(state.get("otp_attempts", 0))
    except Exception:
        state["otp_attempts"] = 0
    state.setdefault("pending_transfer", None)
    state.setdefault("confirmation_context", None)
    state.setdefault("user_id", str(state.get("user_id", "1")))
    return state

def run_handler(state: AgentState, handler_fn) -> AgentState:
    user_id = state.get("user_id", "0")
    try:
        state["result"] = handler_fn(user_id, state.get("user_input", ""))
    except Exception as e:
        logger.exception("Handler %s raised an exception", handler_fn.__name__)
        state["result"] = {"status": "error", "message": str(e)}
    return state

# ---------- Intent Classification Node ----------
def classify_intent(state: AgentState) -> AgentState:
    """
    Classifies intent and handles interruptions in sensitive phases.
    """
    ensure_state_defaults(state)
    phase = to_phase(state.get("phase"))
    user_input = state.get("user_input", "").lower().strip()

    # --- Interruption Detection ---
    is_interruption = False
    if phase == ConversationPhase.OTP and not user_input.isdigit():
        is_interruption = True
    elif phase == ConversationPhase.CONFIRMATION and user_input not in ["yes", "no"]:
        is_interruption = True

    if is_interruption:
        # Classify the new, interrupting query
        new_intent = classify_new_query(user_input)
        if new_intent != "unknown":
            # It's a valid, different intent. Trigger interruption confirmation.
            state["phase"] = ConversationPhase.INTERRUPTION_CONFIRMATION
            state["intent"] = "interruption_confirmation"
            # Save the state before this interruption
            state["interrupted_state"] = {
                "phase": phase,
                "pending_transfer": state.get("pending_transfer"),
                "confirmation_context": state.get("confirmation_context"),
                "otp_attempts": state.get("otp_attempts"),
                "new_intent": new_intent, # Store the intent of the interrupting query
            }
            return state
        # If the new intent is "unknown", treat it as irrelevant input for the current phase
        # and let the respective node handle it (e.g., re-prompt for OTP).

    # --- Standard Intent Classification ---
    if phase == ConversationPhase.INTERRUPTION_CONFIRMATION:
        state["intent"] = "interruption_confirmation"
    elif phase == ConversationPhase.OTP:
        state["intent"] = "otp"
    elif phase == ConversationPhase.CONFIRMATION:
        state["intent"] = "confirmation"
    elif phase == ConversationPhase.NORMAL:
        state["intent"] = classify_new_query(user_input)
    else: # Should not happen, but as a fallback
        state["intent"] = "unknown"

    return state

def classify_new_query(user_input: str) -> str:
    """
    Classifies a new user query using LLM with a fallback.
    Returns one of: spend, faq, offers, transfer, unknown.
    """
    prompt = f"""
    Classify the user query into: spend, faq, offers, transfer, or unknown.
    Query: "{user_input}"
    Return only the label.
    """
    try:
        raw = run_llm(prompt)
        raw_label = (raw or "").strip().lower()
        return raw_label if raw_label in VALID_INTENTS else "unknown"
    except Exception as e:
        logger.exception("LLM intent classification failed")
        # Fallback to simple keyword heuristics
        if "transfer" in user_input or "send" in user_input:
            return "transfer"
        elif "spend" in user_input or "transactions" in user_input:
            return "spend"
        elif "offer" in user_input or "discount" in user_input:
            return "offers"
        elif "how" in user_input or "what" in user_input or "faq" in user_input:
            return "faq"
        else:
            return "unknown"

# ---------- Handlers ----------
def spends_node(state: AgentState) -> AgentState:
    ensure_state_defaults(state)
    return run_handler(state, handle_spend_insight)

def faq_node(state: AgentState) -> AgentState:
    ensure_state_defaults(state)
    return run_handler(state, handle_faq)

def offers_node(state: AgentState) -> AgentState:
    ensure_state_defaults(state)
    return run_handler(state, handle_offers)

def transfer_node(state: AgentState) -> AgentState:
    ensure_state_defaults(state)
    user_id = state.get("user_id", "0")
    user_input_str = (state.get("user_input") or "").strip()

    # If we're already in OTP phase and someone routes digits here, redirect
    if to_phase(state.get("phase")) == ConversationPhase.OTP and user_input_str.isdigit():
        state["intent"] = "otp"
        state["result"] = {"status": "error", "message": "Redirecting input to OTP validation."}
        return state

    try:
        transfer_result = handle_transfer(user_id, user_input_str, otp=None)
    except Exception as e:
        logger.exception("handle_transfer raised")
        state["result"] = {"status": "error", "message": str(e)}
        # keep in NORMAL to avoid deadlocking OTP expectations
        state["phase"] = ConversationPhase.NORMAL
        state["pending_transfer"] = None
        return state

    state["result"] = transfer_result or {}

    if isinstance(transfer_result, dict) and transfer_result.get("status") == "otp_required":
        # transfer_details should be returned as dict by handle_transfer â€” if string, try to parse
        parsed = transfer_result.get("transfer_details", {})
        if isinstance(parsed, str):
            try:
                parsed = json.loads(parsed)
            except Exception:
                logger.warning("transfer_details was a string and failed JSON parse; keeping raw")
                # keep as-is
        state["phase"] = ConversationPhase.OTP
        state["pending_transfer"] = parsed or {}
        state["otp_attempts"] = 0
        state["intent"] = "otp"
    else:
        state["phase"] = ConversationPhase.NORMAL
        state["pending_transfer"] = None

    return state

# ---------- OTP Node ----------
def otp_node(state: AgentState) -> AgentState:
    ensure_state_defaults(state)
    user_id = state.get("user_id", "0")
    otp = (state.get("user_input") or "").strip()
    details = state.get("pending_transfer") or {}

    if not details:
        state.update({
            "result": {"status": "error", "message": "No pending transfer found for OTP. Please restart transfer."},
            "phase": ConversationPhase.NORMAL,
            "otp_attempts": 0,
            "pending_transfer": None,
        })
        return state

    try:
        transfer_result = handle_transfer(user_id, details, otp)
    except Exception as e:
        logger.exception("handle_transfer (OTP validation) raised")
        state.update({
            "result": {"status": "error", "message": str(e)},
            "phase": ConversationPhase.NORMAL,
            "otp_attempts": 0,
            "pending_transfer": None,
        })
        return state

    if transfer_result.get("status") == "otp_incorrect":
        state["otp_attempts"] = int(state.get("otp_attempts", 0)) + 1
        if state["otp_attempts"] >= 3:
            state.update({
                "result": {"status": "failed", "message": "Maximum OTP attempts reached. Transfer cancelled."},
                "phase": ConversationPhase.NORMAL,
                "pending_transfer": None,
                "otp_attempts": 0,
            })
        else:
            remaining = 3 - state["otp_attempts"]
            state.update({
                "result": {"status": "error", "message": f"Incorrect OTP. {remaining} attempt(s) left."},
                "phase": ConversationPhase.OTP,
            })
        return state

    # OTP validated (or other final result)
    state.update({
        "result": transfer_result,
        "phase": ConversationPhase.NORMAL,
        "pending_transfer": None,
        "otp_attempts": 0,
    })

    if transfer_result.get("status") == "success" and transfer_result.get("recommendation"):
        state["phase"] = ConversationPhase.CONFIRMATION
        state["confirmation_context"] = {
            "action": "confirm_recommendation",
            "details": transfer_result,
        }
    else:
        state["confirmation_context"] = None

    return state

# ---------- Confirmation Node ----------
def confirmation_node(state: AgentState) -> AgentState:
    ensure_state_defaults(state)
    if to_phase(state.get("phase")) != ConversationPhase.CONFIRMATION:
        state["result"] = "No pending confirmation. How can I assist you?"
        return state

    ctx = state.get("confirmation_context") or {}
    action, details = ctx.get("action"), ctx.get("details", {})
    handler = CONFIRMATION_HANDLERS.get(action)

    if handler:
        try:
            result = handler(
                details.get("beneficiary_id"),
                details.get("recommendation_id"),
                {"user_id": state.get("user_id", "1"), "query": state.get("user_input", "")}
            )
            state.update({
                "result": result,
                "phase": ConversationPhase.NORMAL,
                "confirmation_context": None,
            })
        except Exception as e:
            logger.exception("confirm handler failed")
            state.update({
                "result": {"status": "error", "message": str(e)},
                "phase": ConversationPhase.NORMAL,
                "confirmation_context": None,
            })
    else:
        state.update({
            "result": "Unexpected confirmation request.",
            "phase": ConversationPhase.NORMAL,
            "confirmation_context": None,
        })
    return state

# ---------- Interruption Confirmation Node ----------
def interruption_confirmation_node(state: AgentState) -> AgentState:
    """Handles the interruption confirmation flow."""
    ensure_state_defaults(state)
    user_input = state.get("user_input", "").lower().strip()
    interrupted_state = state.get("interrupted_state")

    if user_input == "yes":
        # User wants to abandon the old task and start the new one.
        # The new intent is stored in the interrupted_state.
        new_intent = interrupted_state.get("new_intent", "unknown")
        state["intent"] = new_intent
        state["phase"] = ConversationPhase.NORMAL
        # Clear all context from the interrupted task
        state["pending_transfer"] = None
        state["confirmation_context"] = None
        state["otp_attempts"] = 0
        state["interrupted_state"] = None
        # The graph will now route to the node for the `new_intent`.
        # We don't set a result here, as the next node will do it.

    elif user_input == "no":
        # User wants to continue the old task.
        # Restore the previous phase and context.
        state["phase"] = to_phase(interrupted_state.get("phase"))
        state["intent"] = str(state["phase"]) # intent should match the phase, e.g., "otp"
        state["pending_transfer"] = interrupted_state.get("pending_transfer")
        state["confirmation_context"] = interrupted_state.get("confirmation_context")
        state["otp_attempts"] = interrupted_state.get("otp_attempts", 0)
        state["interrupted_state"] = None
        # Provide a message to guide the user back to the task
        if state["phase"] == ConversationPhase.OTP:
            state["result"] = "Ok, let's continue with the transfer. Please provide the OTP."
        elif state["phase"] == ConversationPhase.CONFIRMATION:
            state["result"] = "Alright, let's continue. Please reply with 'yes' or 'no' to the recommendation."
        else: # Fallback
            state["result"] = "Resuming your previous action."

    else:
        # The user's response was not a clear 'yes' or 'no'.
        # Re-prompt for confirmation.
        state["result"] = "Please answer with 'yes' to start a new task or 'no' to continue with the current one."
        # Keep the phase as INTERRUPTION_CONFIRMATION so this node is hit again
        state["phase"] = ConversationPhase.INTERRUPTION_CONFIRMATION
        state["intent"] = "interruption_confirmation"

    return state

# ---------- Unknown Node ----------
def unknown_node(state: AgentState) -> AgentState:
    ensure_state_defaults(state)
    state["result"] = "Sorry, I didn't understand your request. Could you rephrase?"
    return state

# ---------- Flow Builder ----------
def build_flow():
    workflow = StateGraph(AgentState)

    # --- Add Nodes ---
    workflow.add_node("classify_intent", classify_intent)
    workflow.add_node("spend", spends_node)
    workflow.add_node("faq", faq_node)
    workflow.add_node("offers", offers_node)
    workflow.add_node("transfer", transfer_node)
    workflow.add_node("otp", otp_node)
    workflow.add_node("confirmation", confirmation_node)
    workflow.add_node("interruption_confirmation", interruption_confirmation_node)
    workflow.add_node("unknown", unknown_node)

    # --- Add Edges ---
    workflow.set_entry_point("classify_intent")

    # This is the main router of the graph
    workflow.add_conditional_edges(
        "classify_intent",
        lambda state: state.get("intent", "unknown"),
        {
            "spend": "spend",
            "faq": "faq",
            "offers": "offers",
            "transfer": "transfer",
            "otp": "otp",
            "confirmation": "confirmation",
            "interruption_confirmation": "interruption_confirmation",
            "unknown": "unknown",
        },
    )

    # After handling an interruption, the graph should re-evaluate the new state
    workflow.add_edge("interruption_confirmation", "classify_intent")

    # All other terminal nodes end the flow for the current turn
    for node in ["spend", "faq", "offers", "transfer", "otp", "confirmation", "unknown"]:
        workflow.add_edge(node, END)

    return workflow.compile()

# ---------- CLI Runner ----------
if __name__ == "__main__":
    graph = build_flow()
    state: AgentState = {
        "user_input": "",
        "intent": "unknown",
        "result": "",
        "phase": ConversationPhase.NORMAL,
        "otp_attempts": 0,
        "pending_transfer": None,
        "confirmation_context": None,
        "user_id": "1",
    }

    while True:
        user_input = input("You: ").strip()
        if user_input.lower() in ["quit", "exit"]:
            break
        state["user_input"] = user_input
        state["intent"] = "unknown"
        # ensure defaults each loop
        ensure_state_defaults(state)
        result = graph.invoke(state)
        # result may be a mutated state dict from the framework; print the 'result' field
        print("Bot:", result.get("result") if isinstance(result, dict) else result)
        # update local state safely
        if isinstance(result, dict):
            state.update(result)