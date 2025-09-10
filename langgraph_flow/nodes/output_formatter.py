# langgraph_flow/nodes/output_formatter.py
from typing import Dict

def format_response(state: Dict) -> Dict:
    return {"response": state.get("output", "Sorry, I couldn't process that.")}