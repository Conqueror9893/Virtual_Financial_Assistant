# langgraph_flow/nodes/intent_classifier.py
from typing import Dict

def classify_intent(state: Dict) -> Dict:
    user_input = state["input"].lower()
    
    if any(keyword in user_input for keyword in ["balance", "send", "transfer", "pay"]):
        intent = "money_transfer"
    elif any(keyword in user_input for keyword in ["spent", "expense", "spending", "category"]):
        intent = "spend_check"
    else:
        intent = "faq"

    state["intent"] = intent
    return state
