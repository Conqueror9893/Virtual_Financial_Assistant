# langraph_flow/core/state.py

from typing import TypedDict, Optional, Dict, Any, Literal
from .constants import ConversationPhase, IntentType, DEFAULT_USER_ID, DEFAULT_OTP_ATTEMPTS


class AgentState(TypedDict, total=False):
    """Central state definition for the entire conversation flow."""
    
    # Core conversation data
    user_input: str
    result: Any
    phase: ConversationPhase
    user_id: str
    
    # Intent and routing
    intent: str  # Uses IntentType values
    
    # Transfer-specific state
    pending_transfer: Optional[Dict]
    otp_attempts: int
    
    # Confirmation state
    confirmation_context: Optional[Dict]
    
    # Interruption handling
    interrupted_state: Optional[Dict]
    
    # Response enrichment
    contextual_questions: list


class StateManager:
    """Centralized state management with validation and defaults."""
    
    @staticmethod
    def ensure_defaults(state: Dict[str, Any]) -> Dict[str, Any]:
        """
        Ensure all required state fields have sane defaults.
        Mutates and returns the state dictionary.
        """
        # Core defaults
        state.setdefault("user_input", "")
        state.setdefault("intent", IntentType.UNKNOWN)
        state.setdefault("result", "")
        state.setdefault("phase", ConversationPhase.NORMAL)
        
        # Normalize phase if it's a string
        if isinstance(state.get("phase"), str):
            state["phase"] = StateManager._normalize_phase(state["phase"])
        
        # Transfer defaults
        state.setdefault("otp_attempts", DEFAULT_OTP_ATTEMPTS)
        state["otp_attempts"] = int(state.get("otp_attempts", 0))
        state.setdefault("pending_transfer", None)
        
        # Confirmation defaults
        state.setdefault("confirmation_context", None)
        
        # Interruption defaults
        state.setdefault("interrupted_state", None)
        
        # User defaults
        state.setdefault("user_id", DEFAULT_USER_ID)
        state["user_id"] = str(state.get("user_id", DEFAULT_USER_ID))
        
        # Response enrichment
        state.setdefault("contextual_questions", [])
        
        return state
    
    @staticmethod
    def _normalize_phase(value: Any) -> ConversationPhase:
        """Convert string or other types to ConversationPhase enum."""
        if isinstance(value, ConversationPhase):
            return value
        if isinstance(value, str):
            v = value.lower().strip()
            phase_map = {
                "otp": ConversationPhase.OTP,
                "confirmation": ConversationPhase.CONFIRMATION,
                "interruption_confirmation": ConversationPhase.INTERRUPTION_CONFIRMATION,
            }
            return phase_map.get(v, ConversationPhase.NORMAL)
        return ConversationPhase.NORMAL
    
    @staticmethod
    def get_phase(state: Dict[str, Any]) -> ConversationPhase:
        """Safely get current phase from state."""
        phase = state.get("phase", ConversationPhase.NORMAL)
        if isinstance(phase, str):
            return StateManager._normalize_phase(phase)
        return phase
    
    @staticmethod
    def set_phase(state: Dict[str, Any], phase: ConversationPhase) -> None:
        """Safely set phase in state."""
        state["phase"] = phase
    
    @staticmethod
    def is_in_transfer_flow(state: Dict[str, Any]) -> bool:
        """Check if currently in transfer-related flow."""
        phase = StateManager.get_phase(state)
        return phase in (ConversationPhase.OTP, ConversationPhase.CONFIRMATION)
    
    @staticmethod
    def reset_transfer_state(state: Dict[str, Any]) -> None:
        """Reset all transfer-related state fields."""
        state["pending_transfer"] = None
        state["otp_attempts"] = 0
        state["confirmation_context"] = None
    
    @staticmethod
    def extract_response_text(result: Any) -> str:
        """Extract readable text from handler result."""
        if isinstance(result, dict):
            return str(result.get("response", str(result)))
        return str(result)
