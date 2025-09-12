# langraph_flow/langgraph_flow.py
from langgraph.graph import StateGraph, END
from langchain.schema import HumanMessage, AIMessage
from typing import TypedDict, Literal, Optional, Dict
import json
# Import your usecase handlers
from .nodes.spend_insights_node import handle_spend_insight
from .nodes.faq_node import handle_faq
from .nodes.offers_node import handle_offers
from .nodes.transfer_node import handle_transfer
from utils.llm_connector import run_llm


# ---------- State Definition ----------
class AgentState(TypedDict):
    user_input: str
    intent: Literal["spend", "faq", "offers", "transfer", "otp", "confirmation", "unknown"]
    result: str
    awaiting_otp: bool
    otp_attempts: int  
    pending_transfer: Optional[Dict]  # stores original transfer query/details
    awaiting_confirmation: bool
    confirmation_context: Optional[Dict]

# ---------- Intent Classification Node ----------
def classify_intent(state: AgentState) -> AgentState:
    if state.get("awaiting_otp"):
        state["intent"] = "otp"
        return state
    if state.get("awaiting_confirmation"):
        state["intent"] = "confirmation"
        return state

    prompt = f"""
    Classify the user query into one of these intents:
    - spend (transactional/spending insights)
    - faq (banking related Q&A)
    - offers (discounts, deals, promotions)
    - transfer (fund transfer request)
    - unknown (none of the above)

    User query: "{state['user_input']}"
    Return only the intent label.
    """
    raw = run_llm(prompt)
    intent = raw.lower().strip()
    if intent not in ["spend", "faq", "offers", "transfer"]:
        intent = "unknown"
    state["intent"] = intent
    return state


# ---------- Handlers ----------
def spends_node(state: AgentState) -> AgentState:
    user_id = 0  # or retrieve actual user_id from context if available
    state["result"] = handle_spend_insight(user_id, state["user_input"])
    return state

def faq_node(state: AgentState) -> AgentState:
    user_id = 0  # or retrieve actual user_id from context if available
    state["result"] = handle_faq(user_id, state["user_input"])
    return state

def offers_node(state: AgentState) -> AgentState:
    user_id = 0  # or retrieve actual user_id from context if available
    state["result"] = handle_offers(user_id, state["user_input"])
    return state

def transfer_node(state: AgentState) -> AgentState:
    user_id = 0
    user_input_str = state["user_input"].strip()

    # Redirect OTP input mistakenly routed here to otp node
    if state.get("awaiting_otp") and user_input_str.isdigit():
        state["intent"] = "otp"
        state["result"] = {"status": "error", "message": "Redirecting input to OTP validation."}
        return state

    otp = None
    transfer_result = handle_transfer(user_id, user_input_str, otp)

    state["result"] = transfer_result

    if isinstance(transfer_result, dict) and transfer_result.get("status") == "otp_required":
        # Save parsed transfer details returned from handle_transfer
        # You must modify handle_transfer to return parsed details in the response, e.g., under key "transfer_details"
        parsed_details = transfer_result.get("transfer_details")
        state["awaiting_otp"] = True
        state["pending_transfer"] = {
            "query": user_input_str,
            "other": transfer_result,
            "transfer_details": parsed_details
        }
        state["intent"] = "otp"
    else:
        state["awaiting_otp"] = False
        state["pending_transfer"] = None

    return state


# ---------- OTP Node ----------
def otp_node(state: AgentState) -> AgentState:
    user_id = 0
    otp = state["user_input"].strip()
    pending = state.get("pending_transfer") or {}

    # Init attempts if not present
    if "otp_attempts" not in state or state["otp_attempts"] is None:
        state["otp_attempts"] = 0

    parsed_transfer_details = pending.get("transfer_details")
    if not parsed_transfer_details:
        state["result"] = {"status": "error", "message": "No pending transfer details found for OTP. Please restart transfer."}
        state["awaiting_otp"] = False
        state["pending_transfer"] = None
        state["otp_attempts"] = 0
        return state
    
    if isinstance(parsed_transfer_details, str):
        try:
            parsed_transfer_details = json.loads(parsed_transfer_details)
        except Exception as e:
            state["result"] = {"status": "error", "message": f"Failed to parse transfer details: {e}"}
            state["awaiting_otp"] = False
            state["pending_transfer"] = None
            state["otp_attempts"] = 0
            return state

    transfer_result = handle_transfer(user_id, parsed_transfer_details, otp)

    # If OTP is incorrect
    if transfer_result.get("status") == "otp_incorrect":
        state["otp_attempts"] += 1
        if state["otp_attempts"] >= 3:
            state["result"] = {"status": "failed", "message": "Maximum OTP attempts reached. Transfer cancelled."}
            state["awaiting_otp"] = False
            state["pending_transfer"] = None
            state["otp_attempts"] = 0
        else:
            remaining = 3 - state["otp_attempts"]
            state["result"] = {"status": "error", "message": f"Incorrect OTP. You have {remaining} attempt(s) left."}
            state["awaiting_otp"] = True
        return state

    # OTP is correct or other result
    state["result"] = transfer_result
    state["awaiting_otp"] = False
    state["pending_transfer"] = None
    state["otp_attempts"] = 0

    if transfer_result.get("status") == "success" and transfer_result.get("recommendation"):
        state["awaiting_confirmation"] = True
        state["confirmation_context"] = {
            "action": "setup_monthly_transfer",
            "details": transfer_result
        }
    else:
        state["awaiting_confirmation"] = False
        state["confirmation_context"] = None

    return state


def confirmation_node(state: AgentState) -> AgentState:
    user_input = state["user_input"].strip().lower()
    if not state.get("awaiting_confirmation"):
        state["result"] = "No pending confirmation. How can I assist you?"
        return state

    if user_input == "yes":
        # Implement actual monthly transfer setup logic here
        # For demo, just return a success message
        confirmation_result = {
            "status": "success",
            "message": "Monthly transfer setup successful. Your transfer will recur monthly."
        }
        state["result"] = confirmation_result
    elif user_input == "no":
        state["result"] = "Okay, monthly transfer not set up."
    else:
        state["result"] = "Please reply with 'yes' or 'no'."

    # Clear confirmation state after handling
    if user_input in ["yes", "no"]:
        state["awaiting_confirmation"] = False
        state["confirmation_context"] = None

    return state


def unknown_node(state: AgentState) -> AgentState:
    state["result"] = "Sorry, I didn't understand your request. Could you rephrase?"
    return state


def build_flow():
    workflow = StateGraph(AgentState)

    # Nodes
    workflow.add_node("classify_intent", classify_intent)
    workflow.add_node("spend", spends_node)
    workflow.add_node("faq", faq_node)
    workflow.add_node("offers", offers_node)
    workflow.add_node("transfer", transfer_node)
    workflow.add_node("otp", otp_node)
    workflow.add_node("confirmation", confirmation_node)
    workflow.add_node("unknown", unknown_node)

    # Edges
    workflow.set_entry_point("classify_intent")
    workflow.add_conditional_edges(
        "classify_intent",
        lambda state: state["intent"],
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

    # Exit edges
    workflow.add_edge("spend", END)
    workflow.add_edge("faq", END)
    workflow.add_edge("offers", END)
    workflow.add_edge("transfer", END)
    workflow.add_edge("otp", END)
    workflow.add_edge("confirmation", END)
    workflow.add_edge("unknown", END)

    return workflow.compile()


if __name__ == "__main__":
    graph = build_flow()
    state = {
        "user_input": "",
        "intent": "unknown",
        "result": "",
        "awaiting_otp": False,
        "pending_transfer": None,
        "awaiting_confirmation": False,
        "confirmation_context": None,
    }

    while True:
        user_input = input("You: ").strip()
        if user_input.lower() in ["quit", "exit"]:
            break
        state["user_input"] = user_input

        # Override intent when awaiting OTP or confirmation
        if state.get("awaiting_otp"):
            state["intent"] = "otp"
        elif state.get("awaiting_confirmation"):
            state["intent"] = "confirmation"
        else:
            state["intent"] = "unknown"

        result = graph.invoke(state)
        print("Bot:", result["result"])
        state.update(result)