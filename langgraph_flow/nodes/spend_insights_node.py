# langgraph_flow/nodes/spend_insights_node.py
from typing import Dict
import pandas as pd

def handle_spend_insight(state: Dict) -> Dict:
    df = pd.read_excel("data/spends.xlsx")
    total_spend = df["Amount"].sum()
    top_categories = df.groupby("Category")["Amount"].sum().nlargest(3)

    output = f"Total spend: ₹{total_spend:.2f}\nTop categories:\n"
    for cat, amt in top_categories.items():
        output += f"- {cat}: ₹{amt:.2f}\n"

    state["output"] = output
    return state