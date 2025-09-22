# # langraph_flow/langgraph_flow.py
# from langgraph.graph import StateGraph, END
# from langchain.schema import HumanMessage, AIMessage
# from typing import TypedDict, Literal, Optional, Dict
# import json
# # Import your usecase handlers
# from .nodes.spend_insights_node import handle_spend_insight
# from .nodes.faq_node import handle_faq
# from .nodes.offers_node import handle_offers
# from .nodes.transfer_node import handle_transfer
# from utils.llm_connector import run_llm


# # ---------- State Definition ----------
# class AgentState(TypedDict):
#     user_input: str
#     intent: Literal["spend", "faq", "offers", "transfer", "otp", "confirmation", "unknown"]
#     result: str
#     awaiting_otp: bool
#     otp_attempts: int  
#     pending_transfer: Optional[Dict]  # stores original transfer query/details
#     awaiting_confirmation: bool
#     confirmation_context: Optional[Dict]

# # ---------- Intent Classification Node ----------
# def classify_intent(state: AgentState) -> AgentState:
#     if state.get("awaiting_otp"):
#         state["intent"] = "otp"
#         return state
#     if state.get("awaiting_confirmation"):
#         state["intent"] = "confirmation"
#         return state

#     prompt = f"""
#     Classify the user query into one of these intents:
#     - spend (transactional/spending insights)
#     - faq (banking related Q&A)
#     - offers (discounts, deals, promotions)
#     - transfer (fund transfer request)
#     - unknown (none of the above)

#     User query: "{state['user_input']}"
#     Return only the intent label.
#     """
#     raw = run_llm(prompt)
#     intent = raw.lower().strip()
#     if intent not in ["spend", "faq", "offers", "transfer"]:
#         intent = "unknown"
#     state["intent"] = intent
#     return state


# # ---------- Handlers ----------
# def spends_node(state: AgentState) -> AgentState:
#     user_id = 0  # or retrieve actual user_id from context if available
#     state["result"] = handle_spend_insight(user_id, state["user_input"])
#     return state

# def faq_node(state: AgentState) -> AgentState:
#     user_id = 0  # or retrieve actual user_id from context if available
#     state["result"] = handle_faq(user_id, state["user_input"])
#     return state

# def offers_node(state: AgentState) -> AgentState:
#     user_id = 0  # or retrieve actual user_id from context if available
#     state["result"] = handle_offers(user_id, state["user_input"])
#     return state

# def transfer_node(state: AgentState) -> AgentState:
#     user_id = 0
#     user_input_str = state["user_input"].strip()

#     # Redirect OTP input mistakenly routed here to otp node
#     if state.get("awaiting_otp") and user_input_str.isdigit():
#         state["intent"] = "otp"
#         state["result"] = {"status": "error", "message": "Redirecting input to OTP validation."}
#         return state

#     otp = None
#     transfer_result = handle_transfer(user_id, user_input_str, otp)

#     state["result"] = transfer_result

#     if isinstance(transfer_result, dict) and transfer_result.get("status") == "otp_required":
#         # Save parsed transfer details returned from handle_transfer
#         # You must modify handle_transfer to return parsed details in the response, e.g., under key "transfer_details"
#         parsed_details = transfer_result.get("transfer_details")
#         state["awaiting_otp"] = True
#         state["pending_transfer"] = {
#             "query": user_input_str,
#             "other": transfer_result,
#             "transfer_details": parsed_details
#         }
#         state["intent"] = "otp"
#     else:
#         state["awaiting_otp"] = False
#         state["pending_transfer"] = None

#     return state


# # ---------- OTP Node ----------
# def otp_node(state: AgentState) -> AgentState:
#     user_id = 0
#     otp = state["user_input"].strip()
#     pending = state.get("pending_transfer") or {}

#     # Init attempts if not present
#     if "otp_attempts" not in state or state["otp_attempts"] is None:
#         state["otp_attempts"] = 0

#     parsed_transfer_details = pending.get("transfer_details")
#     if not parsed_transfer_details:
#         state["result"] = {"status": "error", "message": "No pending transfer details found for OTP. Please restart transfer."}
#         state["awaiting_otp"] = False
#         state["pending_transfer"] = None
#         state["otp_attempts"] = 0
#         return state
    
#     if isinstance(parsed_transfer_details, str):
#         try:
#             parsed_transfer_details = json.loads(parsed_transfer_details)
#         except Exception as e:
#             state["result"] = {"status": "error", "message": f"Failed to parse transfer details: {e}"}
#             state["awaiting_otp"] = False
#             state["pending_transfer"] = None
#             state["otp_attempts"] = 0
#             return state

#     transfer_result = handle_transfer(user_id, parsed_transfer_details, otp)

#     # If OTP is incorrect
#     if transfer_result.get("status") == "otp_incorrect":
#         state["otp_attempts"] += 1
#         if state["otp_attempts"] >= 3:
#             state["result"] = {"status": "failed", "message": "Maximum OTP attempts reached. Transfer cancelled."}
#             state["awaiting_otp"] = False
#             state["pending_transfer"] = None
#             state["otp_attempts"] = 0
#         else:
#             remaining = 3 - state["otp_attempts"]
#             state["result"] = {"status": "error", "message": f"Incorrect OTP. You have {remaining} attempt(s) left."}
#             state["awaiting_otp"] = True
#         return state

#     # OTP is correct or other result
#     state["result"] = transfer_result
#     state["awaiting_otp"] = False
#     state["pending_transfer"] = None
#     state["otp_attempts"] = 0

#     if transfer_result.get("status") == "success" and transfer_result.get("recommendation"):
#         state["awaiting_confirmation"] = True
#         state["confirmation_context"] = {
#             "action": "setup_monthly_transfer",
#             "details": transfer_result
#         }
#     else:
#         state["awaiting_confirmation"] = False
#         state["confirmation_context"] = None

#     return state


# def confirmation_node(state: AgentState) -> AgentState:
#     user_input = state["user_input"].strip().lower()
#     if not state.get("awaiting_confirmation"):
#         state["result"] = "No pending confirmation. How can I assist you?"
#         return state

#     if user_input == "yes":
#         # Implement actual monthly transfer setup logic here
#         # For demo, just return a success message
#         confirmation_result = {
#             "status": "success",
#             "message": "Monthly transfer setup successful. Your transfer will recur monthly."
#         }
#         state["result"] = confirmation_result
#     elif user_input == "no":
#         state["result"] = "Okay, monthly transfer not set up."
#     else:
#         state["result"] = "Please reply with 'yes' or 'no'."

#     # Clear confirmation state after handling
#     if user_input in ["yes", "no"]:
#         state["awaiting_confirmation"] = False
#         state["confirmation_context"] = None

#     return state


# def unknown_node(state: AgentState) -> AgentState:
#     state["result"] = "Sorry, I didn't understand your request. Could you rephrase?"
#     return state


# def build_flow():
#     workflow = StateGraph(AgentState)

#     # Nodes
#     workflow.add_node("classify_intent", classify_intent)
#     workflow.add_node("spend", spends_node)
#     workflow.add_node("faq", faq_node)
#     workflow.add_node("offers", offers_node)
#     workflow.add_node("transfer", transfer_node)
#     workflow.add_node("otp", otp_node)
#     workflow.add_node("confirmation", confirmation_node)
#     workflow.add_node("unknown", unknown_node)

#     # Edges
#     workflow.set_entry_point("classify_intent")
#     workflow.add_conditional_edges(
#         "classify_intent",
#         lambda state: state["intent"],
#         {
#             "spend": "spend",
#             "faq": "faq",
#             "offers": "offers",
#             "transfer": "transfer",
#             "otp": "otp",
#             "confirmation": "confirmation",
#             "unknown": "unknown",
#         },
#     )

#     # Exit edges
#     workflow.add_edge("spend", END)
#     workflow.add_edge("faq", END)
#     workflow.add_edge("offers", END)
#     workflow.add_edge("transfer", END)
#     workflow.add_edge("otp", END)
#     workflow.add_edge("confirmation", END)
#     workflow.add_edge("unknown", END)

#     return workflow.compile()


# if __name__ == "__main__":
#     graph = build_flow()
#     state = {
#         "user_input": "",
#         "intent": "unknown",
#         "result": "",
#         "awaiting_otp": False,
#         "pending_transfer": None,
#         "awaiting_confirmation": False,
#         "confirmation_context": None,
#     }

#     while True:
#         user_input = input("You: ").strip()
#         if user_input.lower() in ["quit", "exit"]:
#             break
#         state["user_input"] = user_input

#         # Override intent when awaiting OTP or confirmation
#         if state.get("awaiting_otp"):
#             state["intent"] = "otp"
#         elif state.get("awaiting_confirmation"):
#             state["intent"] = "confirmation"
#         else:
#             state["intent"] = "unknown"

#         result = graph.invoke(state)
#         print("Bot:", result["result"])
#         state.update(result)

# # langraph_flow/langgraph_flow.py
# from langgraph.graph import StateGraph, END
# from langchain.schema import HumanMessage, AIMessage
# from typing import TypedDict, Literal, Optional, Dict
# import json
# # Import your usecase handlers
# from .nodes.spend_insights_node import handle_spend_insight
# from .nodes.faq_node import handle_faq
# from .nodes.offers_node import handle_offers
# from .nodes.transfer_node import handle_transfer, confirm_recommendation
# from utils.logger import get_logger
# from utils.llm_connector import run_llm

# logger = get_logger("LangGraphFlow")

# # ---------- State Definition ----------
# class AgentState(TypedDict):
#     user_input: str
#     intent: Literal["spend", "faq", "offers", "transfer", "otp", "confirmation", "unknown"]
#     result: str
#     awaiting_otp: bool
#     otp_attempts: int  
#     pending_transfer: Optional[Dict]  # stores original transfer query/details
#     awaiting_confirmation: bool
#     confirmation_context: Optional[Dict]

# # ---------- Intent Classification Node ----------
# def classify_intent(state: AgentState) -> AgentState:
#     if state.get("awaiting_otp"):
#         state["intent"] = "otp"
#         return state
#     if state.get("awaiting_confirmation"):
#         state["intent"] = "confirmation"
#         return state

#     prompt = f"""
#     Classify the user query into one of these intents:
#     - spend (transactional/spending insights)
#     - faq (banking related Q&A)
#     - offers (discounts, deals, promotions)
#     - transfer (fund transfer request)
#     - unknown (none of the above)

#     User query: "{state['user_input']}"
#     Return only the intent label.
#     """
#     raw = run_llm(prompt)
#     intent = raw.lower().strip()
#     if intent not in ["spend", "faq", "offers", "transfer"]:
#         intent = "unknown"
#     state["intent"] = intent
#     return state


# # ---------- Handlers ----------
# def spends_node(state: AgentState) -> AgentState:
#     user_id = 0  # or retrieve actual user_id from context if available
#     state["result"] = handle_spend_insight(user_id, state["user_input"])
#     return state

# def faq_node(state: AgentState) -> AgentState:
#     user_id = 0  # or retrieve actual user_id from context if available
#     state["result"] = handle_faq(user_id, state["user_input"])
#     return state

# def offers_node(state: AgentState) -> AgentState:
#     user_id = 0  # or retrieve actual user_id from context if available
#     state["result"] = handle_offers(user_id, state["user_input"])
#     return state

# def transfer_node(state: AgentState) -> AgentState:
#     user_id = 0
#     user_input_str = state["user_input"].strip()

#     # Redirect OTP input mistakenly routed here to otp node
#     if state.get("awaiting_otp") and user_input_str.isdigit():
#         state["intent"] = "otp"
#         state["result"] = {"status": "error", "message": "Redirecting input to OTP validation."}
#         return state

#     otp = None
#     transfer_result = handle_transfer(user_id, user_input_str, otp)

#     state["result"] = transfer_result

#     if isinstance(transfer_result, dict) and transfer_result.get("status") == "otp_required":
#         # Save parsed transfer details returned from handle_transfer
#         # You must modify handle_transfer to return parsed details in the response, e.g., under key "transfer_details"
#         parsed_details = transfer_result.get("transfer_details")
#         state["awaiting_otp"] = True
#         state["pending_transfer"] = {
#             "query": user_input_str,
#             "other": transfer_result,
#             "transfer_details": parsed_details
#         }
#         state["intent"] = "otp"
#     else:
#         state["awaiting_otp"] = False
#         state["pending_transfer"] = None

#     return state


# # ---------- OTP Node ----------
# def otp_node(state: AgentState) -> AgentState:
#     user_id = 0
#     otp = state["user_input"].strip()
#     pending = state.get("pending_transfer") or {}

#     # Init attempts if not present
#     if "otp_attempts" not in state or state["otp_attempts"] is None:
#         state["otp_attempts"] = 0

#     parsed_transfer_details = pending.get("transfer_details")
#     if not parsed_transfer_details:
#         state["result"] = {"status": "error", "message": "No pending transfer details found for OTP. Please restart transfer."}
#         state["awaiting_otp"] = False
#         state["pending_transfer"] = None
#         state["otp_attempts"] = 0
#         return state
    
#     if isinstance(parsed_transfer_details, str):
#         try:
#             parsed_transfer_details = json.loads(parsed_transfer_details)
#         except Exception as e:
#             state["result"] = {"status": "error", "message": f"Failed to parse transfer details: {e}"}
#             state["awaiting_otp"] = False
#             state["pending_transfer"] = None
#             state["otp_attempts"] = 0
#             return state

#     transfer_result = handle_transfer(user_id, parsed_transfer_details, otp)

#     # If OTP is incorrect
#     if transfer_result.get("status") == "otp_incorrect":
#         state["otp_attempts"] += 1
#         if state["otp_attempts"] >= 3:
#             state["result"] = {"status": "failed", "message": "Maximum OTP attempts reached. Transfer cancelled."}
#             state["awaiting_otp"] = False
#             state["pending_transfer"] = None
#             state["otp_attempts"] = 0
#         else:
#             remaining = 3 - state["otp_attempts"]
#             state["result"] = {"status": "error", "message": f"Incorrect OTP. You have {remaining} attempt(s) left."}
#             state["awaiting_otp"] = True
#         return state

#     # OTP is correct or other result
#     state["result"] = transfer_result
#     state["awaiting_otp"] = False
#     state["pending_transfer"] = None
#     state["otp_attempts"] = 0

#     if transfer_result.get("status") == "success" and transfer_result.get("recommendation"):
#         state["awaiting_confirmation"] = True
#         state["confirmation_context"] = {
#             "action": "confirm_recommendation",
#             "details": transfer_result
#         }
#     else:
#         state["awaiting_confirmation"] = False
#         state["confirmation_context"] = None

#     return state

# def confirmation_node(state: AgentState) -> AgentState:
#     user_input = state["user_input"].strip().lower()
#     if not state.get("awaiting_confirmation"):
#         state["result"] = "No pending confirmation. How can I assist you?"
#         return state
    
#     ctx = state.get("confirmation_context") or {}
#     if ctx.get("action") == "confirm_recommendation":
#         details = ctx.get("details", {})
#         beneficiary_id = details.get("beneficiary_id")
#         recommendation_id = details.get("recommendation_id")
        
#         # Build body as required for confirm_recommendation
#         body = {
#             "user_id": state.get("user_id", "1"),  # use actual user_id if available
#             "query": user_input
#         }

#         # Call new confirm_recommendation
#         confirmation_result = confirm_recommendation(beneficiary_id, recommendation_id, body)
#         state["result"] = confirmation_result
#         state["awaiting_confirmation"] = False
#         state["confirmation_context"] = None
#         return state

#     # This should not happen, but just in case
#     state["result"] = "Unexpected confirmation request. Please try again."
#     state["awaiting_confirmation"] = False
#     state["confirmation_context"] = None
#     return state


# def unknown_node(state: AgentState) -> AgentState:
#     state["result"] = "Sorry, I didn't understand your request. Could you rephrase?"
#     return state


# def build_flow():
#     workflow = StateGraph(AgentState)

#     # Nodes
#     workflow.add_node("classify_intent", classify_intent)
#     workflow.add_node("spend", spends_node)
#     workflow.add_node("faq", faq_node)
#     workflow.add_node("offers", offers_node)
#     workflow.add_node("transfer", transfer_node)
#     workflow.add_node("otp", otp_node)
#     workflow.add_node("confirmation", confirmation_node)
#     workflow.add_node("unknown", unknown_node)

#     # Edges
#     workflow.set_entry_point("classify_intent")
#     workflow.add_conditional_edges(
#         "classify_intent",
#         lambda state: state["intent"],
#         {
#             "spend": "spend",
#             "faq": "faq",
#             "offers": "offers",
#             "transfer": "transfer",
#             "otp": "otp",
#             "confirmation": "confirmation",
#             "unknown": "unknown",
#         },
#     )

#     # Exit edges
#     workflow.add_edge("spend", END)
#     workflow.add_edge("faq", END)
#     workflow.add_edge("offers", END)
#     workflow.add_edge("transfer", END)
#     workflow.add_edge("otp", END)
#     workflow.add_edge("confirmation", END)
#     workflow.add_edge("unknown", END)

#     return workflow.compile()


# if __name__ == "__main__":
#     graph = build_flow()
#     state = {
#         "user_input": "",
#         "intent": "unknown",
#         "result": "",
#         "awaiting_otp": False,
#         "pending_transfer": None,
#         "awaiting_confirmation": False,
#         "confirmation_context": None,
#     }

#     while True:
#         user_input = input("You: ").strip()
#         if user_input.lower() in ["quit", "exit"]:
#             break
#         state["user_input"] = user_input

#         # Override intent when awaiting OTP or confirmation
#         if state.get("awaiting_otp"):
#             state["intent"] = "otp"
#         elif state.get("awaiting_confirmation"):
#             state["intent"] = "confirmation"
#         else:
#             state["intent"] = "unknown"

#         result = graph.invoke(state)
#         print("Bot:", result["result"])
#         state.update(result)



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

# ---------- State Definition ----------
class AgentState(TypedDict, total=False):
    user_input: str
    intent: Literal["spend", "faq", "offers", "transfer", "otp", "confirmation", "unknown"]
    result: Any
    phase: ConversationPhase
    otp_attempts: int
    pending_transfer: Optional[Dict]
    confirmation_context: Optional[Dict]
    user_id: str

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
    # Defensive defaulting
    ensure_state_defaults(state)
    phase = to_phase(state.get("phase"))

    if phase == ConversationPhase.OTP:
        state["intent"] = "otp"
        return state
    if phase == ConversationPhase.CONFIRMATION:
        state["intent"] = "confirmation"
        return state

    prompt = f"""
    Classify the user query into: spend, faq, offers, transfer, or unknown.
    Query: "{state.get('user_input', '')}"
    Return only the label.
    """
    try:
        raw = run_llm(prompt)
        raw_label = (raw or "").strip().lower()
        state["intent"] = raw_label if raw_label in VALID_INTENTS else "unknown"
    except Exception as e:
        logger.exception("LLM intent classification failed")
        # fallback simple keyword heuristics as safety-net:
        ui = state.get("user_input", "").lower()
        if "transfer" in ui or "send" in ui:
            state["intent"] = "transfer"
        elif "spend" in ui or "transactions" in ui:
            state["intent"] = "spend"
        elif "offer" in ui or "discount" in ui:
            state["intent"] = "offers"
        elif "how" in ui or "what" in ui or "faq" in ui:
            state["intent"] = "faq"
        else:
            state["intent"] = "unknown"
    return state

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
        # transfer_details should be returned as dict by handle_transfer — if string, try to parse
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

# ---------- Unknown Node ----------
def unknown_node(state: AgentState) -> AgentState:
    ensure_state_defaults(state)
    state["result"] = "Sorry, I didn't understand your request. Could you rephrase?"
    return state

# ---------- Flow Builder ----------
def build_flow():
    workflow = StateGraph(AgentState)

    workflow.add_node("classify_intent", classify_intent)
    workflow.add_node("spend", spends_node)
    workflow.add_node("faq", faq_node)
    workflow.add_node("offers", offers_node)
    workflow.add_node("transfer", transfer_node)
    workflow.add_node("otp", otp_node)
    workflow.add_node("confirmation", confirmation_node)
    workflow.add_node("unknown", unknown_node)

    workflow.set_entry_point("classify_intent")

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
            "unknown": "unknown",
        },
    )

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