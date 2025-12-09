# Add these fields to your AgentState (in your core/state.py file)

# Existing AgentState fields...
{
    "user_input": str,              # Original user input
    "user_input_en": str,           # NEW: English translation of user input
    "input_language": str,          # NEW: Detected language code (e.g., 'hi', 'es', 'en')
    "original_user_input": str,     # NEW: Store original for reference
    "intent": str,
    "result": dict | str,
    "phase": str,
    "otp_attempts": int,
    "pending_transfer": dict | None,
    "confirmation_context": dict | None,
    "user_id": str,
    # ... other existing fields
}

# Example of how to add to your TypedDict or dataclass:

from typing import Optional, TypedDict

class AgentState(TypedDict):
    """Complete agent state including language translation support."""
    
    # Language fields (NEW)
    user_input: str
    user_input_en: str  # English version for processing
    input_language: str  # Detected language code
    original_user_input: str
    
    # Existing fields
    intent: str
    result: dict | str
    phase: str
    otp_attempts: int
    pending_transfer: Optional[dict]
    confirmation_context: Optional[dict]
    user_id: str
    contextual_questions: list
    # ... other existing fields
