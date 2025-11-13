# langraph_flow/core/routing.py

from typing import Dict, Any
from .constants import ConversationPhase, IntentType
from .state import StateManager


class IntentRouter:
    """Handles routing logic based on intent classification."""
    
    @staticmethod
    def route_from_classify_intent(state: Dict[str, Any]) -> str:
        """
        Main router after intent classification.
        Routes to appropriate node based on intent.
        """
        intent = state.get("intent", IntentType.UNKNOWN)
        return intent or IntentType.UNKNOWN
    
    @staticmethod
    def route_after_handler(state: Dict[str, Any]) -> str:
        """
        Routes after a handler completes.
        Returns END to finish or next node name.
        """
        # All main handlers end the flow
        return "END"
    
    @staticmethod
    def is_valid_interruption(phase: ConversationPhase, user_input: str, new_intent: str) -> bool:
        """
        Determine if current input is a valid interruption in sensitive phases.
        
        Args:
            phase: Current conversation phase
            user_input: User's input text
            new_intent: Classification of new intent
        
        Returns:
            True if this should trigger interruption flow
        """
        # In OTP phase, non-digit input that classifies to different intent
        if phase == ConversationPhase.OTP:
            if not user_input.strip().isdigit() and new_intent != IntentType.UNKNOWN:
                return True
        
        # In CONFIRMATION phase, response other than yes/no that classifies to different intent
        if phase == ConversationPhase.CONFIRMATION:
            normalized = user_input.lower().strip()
            if normalized not in ("yes", "no") and new_intent != IntentType.UNKNOWN:
                return True
        
        return False
    
    @staticmethod
    def normalize_confirmation_input(user_input: str) -> str:
        """Normalize yes/no responses."""
        normalized = (user_input or "").strip().lower()
        yes_variants = ("confirm_yes", "confirm-yes", "y", "yes", "confirm", "ok", "proceed")
        no_variants = ("confirm_no", "confirm-no", "n", "no", "cancel", "abort", "stop")
        
        if normalized in yes_variants:
            return "yes"
        elif normalized in no_variants:
            return "no"
        return normalized


class PhaseRouter:
    """Handles phase-based routing logic."""
    
    @staticmethod
    def get_node_from_phase(phase: ConversationPhase) -> str:
        """Determine which node to route to based on current phase."""
        phase_node_map = {
            ConversationPhase.OTP: "otp",
            ConversationPhase.CONFIRMATION: "confirmation",
            ConversationPhase.INTERRUPTION_CONFIRMATION: "interruption_confirmation",
            ConversationPhase.NORMAL: "classify_intent",
        }
        return phase_node_map.get(phase, "unknown")
