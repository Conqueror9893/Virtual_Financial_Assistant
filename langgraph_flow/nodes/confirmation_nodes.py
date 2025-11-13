# langraph_flow/nodes/confirmation_nodes.py

"""
Confirmation and Interruption Nodes

Handles:
- Confirmation phase (yes/no responses after transfer)
- Interruption confirmation (user wants to switch tasks)
"""

import logging
from typing import Dict, Any
from ..core.state import StateManager
from ..core.constants import ConversationPhase, IntentType, STATUS_ERROR
from ..core.routing import IntentRouter
from ..flows.transfer_flow import TransferFlowHandler


logger = logging.getLogger(__name__)


def confirmation_node(state: Dict[str, Any]) -> Dict[str, Any]:
    """
    Handle user confirmation (yes/no to recommendations).
    
    Extracts normalized confirmation response and routes to
    TransferFlowHandler for processing.
    """
    StateManager.ensure_defaults(state)
    
    # Delegate to transfer flow handler
    return TransferFlowHandler.confirm_recommendation(state)


def interruption_confirmation_node(state: Dict[str, Any]) -> Dict[str, Any]:
    """
    Handle interruption confirmation flow.
    
    User can choose to:
    - 'yes': Abandon current task and start new one
    - 'no': Continue with current task
    
    Handles state restoration and phase transitions.
    """
    StateManager.ensure_defaults(state)
    
    user_input = state.get("user_input", "").lower().strip()
    interrupted_state = state.get("interrupted_state")
    
    if not interrupted_state:
        state["result"] = "No interrupted task found."
        return state
    
    # --- USER CHOOSES TO SWITCH TASKS ---
    if user_input == "yes":
        # Abandon old task and start new one
        new_intent = interrupted_state.get("new_intent", IntentType.UNKNOWN)
        state["intent"] = new_intent
        state["phase"] = ConversationPhase.NORMAL
        
        # Clear transfer/confirmation context
        state["pending_transfer"] = None
        state["otp_attempts"] = 0
        state["confirmation_context"] = None
        state["interrupted_state"] = None
        
        state["result"] = f"Starting new task: {new_intent}"
        # Graph will route to the new intent's node next turn
    
    # --- USER CHOOSES TO CONTINUE CURRENT TASK ---
    elif user_input == "no":
        # Restore previous state
        prev_phase = StateManager._normalize_phase(interrupted_state.get("phase"))
        state["phase"] = prev_phase
        
        # Restore transfer context if in transfer flow
        state["pending_transfer"] = interrupted_state.get("pending_transfer")
        state["confirmation_context"] = interrupted_state.get("confirmation_context")
        state["otp_attempts"] = interrupted_state.get("otp_attempts", 0)
        
        # Restore appropriate intent based on phase
        if prev_phase == ConversationPhase.OTP:
            state["intent"] = IntentType.OTP
            state["result"] = "Continuing with transfer. Please provide the OTP."
        elif prev_phase == ConversationPhase.CONFIRMATION:
            state["intent"] = IntentType.CONFIRMATION
            state["result"] = "Continuing with confirmation. Please reply 'yes' or 'no'."
        else:
            state["intent"] = IntentType.UNKNOWN
            state["result"] = "Resuming previous task."
        
        state["interrupted_state"] = None
    
    # --- USER RESPONSE NOT CLEAR ---
    else:
        state["result"] = (
            "Please answer 'yes' to start a new task or 'no' to continue with the current one."
        )
        state["phase"] = ConversationPhase.INTERRUPTION_CONFIRMATION
        state["intent"] = IntentType.INTERRUPTION_CONFIRMATION
    
    return state
