# langraph_flow/nodes/main_nodes.py

"""
Main Handler Nodes

Spend, FAQ, Offers, Voice, and Unknown intent handlers.
Each enriched with contextual questions.
"""

import logging
from typing import Dict, Any
from ..core.state import StateManager
from ..core.constants import RESPONSE_FIELD, STATUS_FIELD, MESSAGE_FIELD
from ..handlers.spend_insights_node import handle_spend_insight
from ..handlers.faq_node import handle_faq
from ..handlers.offers_node import handle_offers
from ..handlers.voice_node import handle_voice_interaction
from ..handlers.contextual_questions_node import handle_contextual_questions_node


logger = logging.getLogger(__name__)


def _get_response_text(result: Any) -> str:
    """Extract readable response text from result."""
    return StateManager.extract_response_text(result)


def _enrich_with_contextual_questions(
    state: Dict[str, Any],
    handler_fn,
    last_response: str
) -> None:
    """
    Helper to enrich state with contextual questions.
    
    Args:
        state: Agent state
        handler_fn: The handler that was called
        last_response: Response text from handler
    """
    user_id = int(state.get("user_id", 1))
    user_input = state.get("user_input", "")
    
    try:
        suggestions = handle_contextual_questions_node(
            user_id=user_id,
            last_query=user_input,
            last_response=last_response,
        )
        state["contextual_questions"] = suggestions.get("contextual_questions", [])
    except Exception as e:
        logger.warning(f"Failed to get contextual questions: {e}")
        state["contextual_questions"] = []


def spend_node(state: Dict[str, Any]) -> Dict[str, Any]:
    """Handle spend/transaction insights."""
    StateManager.ensure_defaults(state)
    
    user_id = state.get("user_id", "0")
    user_input = state.get("user_input", "")
    
    try:
        state["result"] = handle_spend_insight(user_id, user_input)
    except Exception as e:
        logger.exception("spend_insight handler failed")
        state["result"] = {
            STATUS_FIELD: "error",
            MESSAGE_FIELD: str(e)
        }
    
    # Enrich with contextual questions
    response_text = _get_response_text(state.get("result"))
    _enrich_with_contextual_questions(state, handle_spend_insight, response_text)
    
    return state


def faq_node(state: Dict[str, Any]) -> Dict[str, Any]:
    """Handle FAQ/help queries."""
    StateManager.ensure_defaults(state)
    
    user_id = state.get("user_id", "0")
    user_input = state.get("user_input", "")
    
    try:
        state["result"] = handle_faq(user_id, user_input)
    except Exception as e:
        logger.exception("faq handler failed")
        state["result"] = {
            STATUS_FIELD: "error",
            MESSAGE_FIELD: str(e)
        }
    
    # Enrich with contextual questions
    response_text = _get_response_text(state.get("result"))
    _enrich_with_contextual_questions(state, handle_faq, response_text)
    
    return state


def offers_node(state: Dict[str, Any]) -> Dict[str, Any]:
    """Handle offers/promotions queries."""
    StateManager.ensure_defaults(state)
    
    user_id = state.get("user_id", "0")
    user_input = state.get("user_input", "")
    
    try:
        state["result"] = handle_offers(user_id, user_input)
    except Exception as e:
        logger.exception("offers handler failed")
        state["result"] = {
            STATUS_FIELD: "error",
            MESSAGE_FIELD: str(e)
        }
    
    # Enrich with contextual questions
    response_text = _get_response_text(state.get("result"))
    _enrich_with_contextual_questions(state, handle_offers, response_text)
    
    return state


def voice_node(state: Dict[str, Any]) -> Dict[str, Any]:
    """Handle voice interaction."""
    StateManager.ensure_defaults(state)
    
    user_id = state.get("user_id", "1")
    user_input = state.get("user_input", "")
    
    try:
        state["result"] = handle_voice_interaction(user_id, user_input)
    except Exception as e:
        logger.exception("voice handler failed")
        state["result"] = {
            STATUS_FIELD: "error",
            MESSAGE_FIELD: str(e)
        }
    
    return state


def unknown_node(state: Dict[str, Any]) -> Dict[str, Any]:
    """Handle unknown intents."""
    StateManager.ensure_defaults(state)
    state["result"] = (
        "Sorry, I didn't understand your request. Could you please rephrase that? "
        "You can ask me about spending, transfers, offers, or other financial questions."
    )
    return state
