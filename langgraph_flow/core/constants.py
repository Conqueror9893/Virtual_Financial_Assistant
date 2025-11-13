# langraph_flow/core/constants.py

from enum import Enum
from typing import Set, Dict, Callable


class ConversationPhase(str, Enum):
    """Represents different phases of conversation flow."""
    NORMAL = "normal"
    
    # Transfer flow phases (NEW)
    BENEFICIARY_SELECTION = "beneficiary_selection"
    ACCOUNT_SELECTION = "account_selection"
    TRANSFER_SUMMARY = "transfer_summary"
    
    # Transfer payment phases
    OTP = "otp"
    CONFIRMATION = "confirmation"
    
    # Interruption handling
    INTERRUPTION_CONFIRMATION = "interruption_confirmation"


class IntentType(str, Enum):
    """Valid user intents in the system."""
    SPEND = "spend"
    FAQ = "faq"
    OFFERS = "offers"
    TRANSFER = "transfer"
    OTP = "otp"
    CONFIRMATION = "confirmation"
    INTERRUPTION_CONFIRMATION = "interruption_confirmation"
    UNKNOWN = "unknown"


# Constants
VALID_INTENTS: Set[str] = {
    IntentType.SPEND,
    IntentType.FAQ,
    IntentType.OFFERS,
    IntentType.TRANSFER,
}

CLASSIFICATION_INTENTS: Set[str] = VALID_INTENTS | {
    IntentType.OTP,
    IntentType.CONFIRMATION,
    IntentType.INTERRUPTION_CONFIRMATION,
}

# Transfer flow phases that are sensitive to interruption
TRANSFER_FLOW_PHASES = {
    ConversationPhase.BENEFICIARY_SELECTION,
    ConversationPhase.ACCOUNT_SELECTION,
    ConversationPhase.TRANSFER_SUMMARY,
    ConversationPhase.OTP,
    ConversationPhase.CONFIRMATION,
}

# Max OTP attempts before cancellation
MAX_OTP_ATTEMPTS = 3

# Max invalid attempts for beneficiary/account selection
MAX_INVALID_SELECTION_ATTEMPTS = 2

# Maximum vertical movement in pixels
MAX_MOVE_UP_PIXELS = 20

# Transfer scale animation range
TRANSFER_SCALE_RANGE = (1.0, 10.0)

# Response field names
RESPONSE_FIELD = "response"
STATUS_FIELD = "status"
MESSAGE_FIELD = "message"

# Status messages
STATUS_OTP_REQUIRED = "otp_required"
STATUS_OTP_INCORRECT = "otp_incorrect"
STATUS_ERROR = "error"
STATUS_SUCCESS = "success"
STATUS_FAILED = "failed"
STATUS_MULTIPLE_MATCHES = "multiple_matches"
STATUS_INVALID_SELECTION = "invalid_selection"

# Default values
DEFAULT_USER_ID = "1"
DEFAULT_OTP_ATTEMPTS = 0
DEFAULT_SELECTION_ATTEMPTS = 0

# Account types
ACCOUNT_TYPES = ["Savings", "Current"]
