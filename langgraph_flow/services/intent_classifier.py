# langraph_flow/services/intent_classifier.py

from utils.logger import get_logger
from typing import Optional
from ..core.constants import IntentType, VALID_INTENTS
from utils.llm_connector import run_llm
from utils.prompts import INTENT_CLASSIFICATION_PROMPT

logger = get_logger(__name__)


class IntentClassifier:
    """Centralized intent classification service with fallback heuristics."""

    # Simple keyword-based fallback heuristics
    KEYWORD_FALLBACKS = {
        IntentType.TRANSFER: ["transfer", "send", "pay", "remit"],
        IntentType.SPEND: ["spend", "transactions", "spending", "expense"],
        # IntentType.OFFERS: ["offer", "discount", "promo", "deal", "coupon"],
        IntentType.FAQ: ["how", "what", "why", "when", "where", "faq", "help"],
    }

    @staticmethod
    def classify(user_input: str) -> str:
        """
        Classify user input to one of valid intents.

        Uses LLM with keyword fallback.
        Returns: One of VALID_INTENTS or IntentType.UNKNOWN
        """
        if not user_input or not user_input.strip():
            return IntentType.UNKNOWN

        # Try LLM classification first
        llm_result = IntentClassifier._classify_with_llm(user_input)
        logger.info(f"LLM result: {llm_result}")
        if llm_result and llm_result in VALID_INTENTS:
            logger.info(llm_result)
            return llm_result

        # Fallback to keyword heuristics
        return IntentClassifier._classify_with_keywords(user_input)

    @staticmethod
    def _classify_with_llm(user_input: str) -> Optional[str]:
        """Try to classify using LLM."""
        prompt = INTENT_CLASSIFICATION_PROMPT.format(user_input=user_input)

        try:
            raw = run_llm(prompt)
            if raw:
                label = raw.strip().lower()
                if label in VALID_INTENTS:
                    logger.info(f"LLM classified '{user_input[:30]}...' as {label}")
                    return label
        except Exception as e:
            logger.warning(f"LLM classification failed: {e}")

        return None

    @staticmethod
    def _classify_with_keywords(user_input: str) -> str:
        """Fallback keyword-based classification."""
        user_lower = user_input.lower()

        # Check keyword matches
        for intent, keywords in IntentClassifier.KEYWORD_FALLBACKS.items():
            if any(keyword in user_lower for keyword in keywords):
                logger.debug(
                    f"Keyword fallback classified '{user_input[:30]}...' as {intent}"
                )
                return intent

        return IntentType.UNKNOWN
