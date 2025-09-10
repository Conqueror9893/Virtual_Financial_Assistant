# langgraph_flow/nodes/transfer_node.py
from typing import Dict
import random

# Simulated balance
USER_BALANCE = 50000

# Simulate extracting amount (basic)
def extract_amount(user_input: str) -> int:
    import re
    match = re.search(r"\d+", user_input)
    return int(match.group()) if match else 0

def handle_transfer(state: Dict) -> Dict:
    user_input = state["input"]
    amount = extract_amount(user_input)
    global USER_BALANCE

    if amount <= 0:
        response = "Could not determine transfer amount."
    elif amount > USER_BALANCE:
        response = f"Insufficient balance. Your balance is ₹{USER_BALANCE}."
    else:
        USER_BALANCE -= amount
        response = f"Transferred ₹{amount}. New balance is ₹{USER_BALANCE}."

    state["output"] = response
    return state