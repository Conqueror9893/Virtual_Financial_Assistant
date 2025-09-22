# langgraph_flow/nodes/intent_classifier.py
from typing import Dict
import json
from utils.llm_connector import run_llm

# List of supported intents
INTENTS = [
    "fund_transfer",
    "balance_check",
    "spends_check"
]

def classify_intent(state: Dict) -> Dict:
    user_input = state["input"].strip()

    # LLM prompt template
    prompt = (
        "Given the following user message, predict which one of these intents best matches the message: "
        f"{', '.join(INTENTS)}. "
        "Also return a confidence score (between 0 and 1) for your prediction.\n"
        "Respond in JSON with keys: 'intent' and 'confidence'.\n"
        "User message: \"" + user_input + "\""
    )

    raw_output = run_llm(prompt)
    try:
        # Expecting: {"intent": "fund_transfer", "confidence": 0.97}
        result = json.loads(raw_output)
        # Assign detected intent and confidence score
        state["intent"] = result.get("intent", "faq")
        state["confidence"] = result.get("confidence", 0.0)
    except Exception:
        # Fallback in case of LLM failure or malformed output
        state["intent"] = "faq"
        state["confidence"] = 0.0
    return state
