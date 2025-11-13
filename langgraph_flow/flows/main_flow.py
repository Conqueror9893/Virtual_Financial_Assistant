# langraph_flow/flows/main_flow.py

"""
Main LangGraph Flow Orchestration

Clean separation between:
- Main flow (spend, faq, offers, unknown, voice)
- Transfer sub-graph (handled by TransferFlowHandler)
- Interruption detection and confirmation

Entry point for building the complete agent graph.
"""

import logging
from langgraph.graph import StateGraph, END
from typing import Dict, Any
from ..core.state import AgentState, StateManager
from ..core.constants import ConversationPhase, IntentType, MAX_OTP_ATTEMPTS
from ..core.routing import IntentRouter, PhaseRouter
from ..flows.transfer_flow import TransferFlowHandler
from ..core.constants import TRANSFER_FLOW_PHASES
from ..services.intent_classifier import IntentClassifier
from ..nodes.main_nodes import (
    spend_node, faq_node, offers_node, unknown_node, voice_node
)
from ..nodes.confirmation_nodes import confirmation_node, interruption_confirmation_node


logger = logging.getLogger(__name__)


# ============================================================================
# MAIN FLOW NODES
# ============================================================================

def classify_intent_node(state: Dict[str, Any]) -> Dict[str, Any]:
    """
    Intent classification with interruption detection.
    
    Handles:
    - Standard intent classification
    - Interruption detection in ALL transfer phases (NEW)
    - Routing to appropriate nodes
    """
    StateManager.ensure_defaults(state)
    phase = StateManager.get_phase(state)
    user_input = state.get("user_input", "").lower().strip()
    
    # Check for interruptions in ANY transfer phase (NEW)
    if phase in TRANSFER_FLOW_PHASES:
        is_interruption, new_intent = _detect_interruption(phase, user_input)
        
        if is_interruption:
            state["phase"] = ConversationPhase.INTERRUPTION_CONFIRMATION
            state["intent"] = IntentType.INTERRUPTION_CONFIRMATION
            state["interrupted_state"] = {
                "phase": phase,
                "pending_transfer": state.get("pending_transfer"),
                "confirmation_context": state.get("confirmation_context"),
                "otp_attempts": state.get("otp_attempts"),
                "selection_attempts": state.get("selection_attempts"),  # NEW
                "new_intent": new_intent,
            }
            return state
    
    # Standard classification for NORMAL phase
    if phase == ConversationPhase.NORMAL:
        state["intent"] = IntentClassifier.classify(user_input)
    elif phase == ConversationPhase.BENEFICIARY_SELECTION:  # NEW
        state["intent"] = IntentType.TRANSFER
    elif phase == ConversationPhase.ACCOUNT_SELECTION:  # NEW
        state["intent"] = IntentType.TRANSFER
    elif phase == ConversationPhase.TRANSFER_SUMMARY:  # NEW
        state["intent"] = IntentType.TRANSFER
    elif phase == ConversationPhase.OTP:
        state["intent"] = IntentType.OTP
    elif phase == ConversationPhase.CONFIRMATION:
        state["intent"] = IntentType.CONFIRMATION
    
    return state



def transfer_node(state: Dict[str, Any]) -> Dict[str, Any]:
    """Route to transfer sub-graph."""
    return TransferFlowHandler.initiate_transfer(state)


def beneficiary_selection_node(state: Dict[str, Any]) -> Dict[str, Any]:
    """Handle beneficiary selection phase."""
    return TransferFlowHandler.handle_beneficiary_selection(state)


def account_selection_node(state: Dict[str, Any]) -> Dict[str, Any]:
    """Handle account selection phase."""
    return TransferFlowHandler.handle_account_selection(state)


def transfer_summary_node(state: Dict[str, Any]) -> Dict[str, Any]:
    """Handle transfer summary confirmation phase."""
    return TransferFlowHandler.handle_transfer_summary_confirmation(state)


def transfer_otp_node(state: Dict[str, Any]) -> Dict[str, Any]:
    """Handle OTP validation for transfer."""
    return TransferFlowHandler.validate_otp(state)


def transfer_confirmation_node(state: Dict[str, Any]) -> Dict[str, Any]:
    """Handle recurring transfer confirmation."""
    return TransferFlowHandler.confirm_recurring_transfer(state)

# ============================================================================
# MAIN FLOW ROUTING
# ============================================================================

def route_from_classify_intent(state: Dict[str, Any]) -> str:
    """Route based on classified intent."""
    return state.get("intent", IntentType.UNKNOWN)


def _detect_interruption(phase: ConversationPhase, user_input: str) -> tuple:
    """
    Detect if current input interrupts a sensitive phase.
    
    Returns:
        (is_interruption: bool, new_intent: str)
    """
    # OTP phase: non-digit input that's a valid intent
    if phase == ConversationPhase.OTP:
        if not user_input.strip().isdigit():
            new_intent = IntentClassifier.classify(user_input)
            if new_intent != IntentType.UNKNOWN:
                return True, new_intent
    
    # CONFIRMATION phase: response other than yes/no that's a valid intent
    if phase == ConversationPhase.CONFIRMATION:
        if user_input not in ("yes", "no"):
            new_intent = IntentClassifier.classify(user_input)
            if new_intent != IntentType.UNKNOWN:
                return True, new_intent
    
    return False, IntentType.UNKNOWN

def _route_from_transfer(state: Dict[str, Any]) -> str:
    """
    Route based on transfer phase.
    
    Determines which transfer phase node to invoke next.
    """
    result = state.get("result", {})
    phase = StateManager.get_phase(state)
    status = result.get("status", "")
    
    if status == "multiple_matches":
        return "beneficiary_selection"
    elif phase == ConversationPhase.BENEFICIARY_SELECTION:
        return "account_selection"
    elif phase == ConversationPhase.ACCOUNT_SELECTION:
        return "transfer_summary"
    elif phase == ConversationPhase.TRANSFER_SUMMARY:
        if status == "otp_required":
            return "transfer_otp"
        return "end"
    
    return "end"



# ============================================================================
# GRAPH BUILDER
# ============================================================================

def build_main_flow():
    """
    Build and compile the main LangGraph flow with enhanced transfer support.
    
    Structure:
    1. classify_intent (entry point)
    2. Intent-specific nodes (spend, faq, offers, transfer)
    3. Transfer sub-graph nodes (beneficiary, account, summary, otp)
    4. Confirmation nodes (confirmation, interruption_confirmation)
    5. Fallback (unknown, voice)
    """
    workflow = StateGraph(AgentState, config={"recursion_limit": 50})
    
    # -----------------------------------------------------------------------
    # ADD NODES
    # -----------------------------------------------------------------------
    
    # Intent classification
    workflow.add_node("classify_intent", classify_intent_node)
    
    # Main flow nodes
    workflow.add_node("spend", spend_node)
    workflow.add_node("faq", faq_node)
    workflow.add_node("offers", offers_node)
    workflow.add_node("unknown", unknown_node)
    workflow.add_node("voice", voice_node)
    
    # Transfer flow nodes (UPDATED with new phases)
    workflow.add_node("transfer", transfer_node)
    workflow.add_node("beneficiary_selection", beneficiary_selection_node)  # NEW
    workflow.add_node("account_selection", account_selection_node)          # NEW
    workflow.add_node("transfer_summary", transfer_summary_node)            # NEW
    workflow.add_node("transfer_otp", transfer_otp_node)                    # NEW (renamed)
    
    # Confirmation nodes
    workflow.add_node("confirmation", transfer_confirmation_node)
    workflow.add_node("interruption_confirmation", interruption_confirmation_node)
    
    # -----------------------------------------------------------------------
    # SET ENTRY POINT
    # -----------------------------------------------------------------------
    workflow.set_entry_point("classify_intent")
    
    # -----------------------------------------------------------------------
    # ADD EDGES
    # -----------------------------------------------------------------------
    
    # Main routing from classify_intent
    workflow.add_conditional_edges(
        "classify_intent",
        route_from_classify_intent,
        {
            IntentType.SPEND: "spend",
            IntentType.FAQ: "faq",
            IntentType.OFFERS: "offers",
            IntentType.TRANSFER: "transfer",
            IntentType.OTP: "transfer_otp",  # UPDATED (was "otp")
            IntentType.CONFIRMATION: "confirmation",
            IntentType.INTERRUPTION_CONFIRMATION: "interruption_confirmation",
            IntentType.UNKNOWN: "unknown",
        },
    )
    
    # Transfer flow conditional routing (NEW)
    workflow.add_conditional_edges(
        "transfer",
        lambda state: _route_from_transfer(state),
        {
            "beneficiary_selection": "beneficiary_selection",
            "account_selection": "account_selection",
            "transfer_summary": "transfer_summary",
            "transfer_otp": "transfer_otp",
            "end": END,
        }
    )
    
    # Transfer phase terminal edges (NEW)
    workflow.add_edge("beneficiary_selection", END)
    workflow.add_edge("account_selection", END)
    workflow.add_edge("transfer_summary", END)
    workflow.add_edge("transfer_otp", END)
    
    # All other terminal nodes end the flow
    for node in ["spend", "faq", "offers", "confirmation",
                 "interruption_confirmation", "unknown", "voice"]:
        workflow.add_edge(node, END)
    
    # Compile and return
    return workflow.compile()


# ============================================================================
# CLI RUNNER (for testing)
# ============================================================================

def run_cli():
    """Simple CLI for testing the flow."""
    graph = build_main_flow()
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
    
    print("=== Virtual Financial Assistant ===")
    print("Type 'quit' or 'exit' to stop\n")
    
    while True:
        try:
            user_input = input("You: ").strip()
            
            if user_input.lower() in ["quit", "exit"]:
                print("Goodbye!")
                break
            
            if not user_input:
                continue
            
            # Reset intent for new input
            state["user_input"] = user_input
            state["intent"] = IntentType.UNKNOWN
            StateManager.ensure_defaults(state)
            
            # Invoke graph
            result = graph.invoke(state)
            
            # Extract and display result
            bot_response = result.get("result", "No response")
            if isinstance(bot_response, dict):
                bot_response = bot_response.get("message", str(bot_response))
            
            print(f"Bot: {bot_response}\n")
            
            # Update state for next iteration
            if isinstance(result, dict):
                state.update(result)
        
        except KeyboardInterrupt:
            print("\nInterrupted by user")
            break
        except Exception as e:
            logger.exception("Error in CLI loop")
            print(f"Error: {str(e)}\n")


if __name__ == "__main__":
    run_cli()
