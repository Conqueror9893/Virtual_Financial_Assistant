# langgraph_flow/nodes/faq_node.py
from typing import Dict
import ollama

def handle_faq(state: Dict) -> Dict:
    user_input = state["input"]
    response = ollama.chat(
        model="openchat:latest",
        messages=[
            {"role": "system", "content": "You are a helpful banking assistant."},
            {"role": "user", "content": user_input},
        ]
    )
    state["output"] = response["message"]["content"]
    return state