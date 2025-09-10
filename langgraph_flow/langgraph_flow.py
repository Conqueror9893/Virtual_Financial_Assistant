# langgraph_flow.py
from langgraph.graph import StateGraph, END
from langchain.schema import HumanMessage, AIMessage
from typing import TypedDict, Literal

# Import your usecase handlers
from nodes.spend_insights_node import handle_spends
from nodes.faq_node import handle_faq
from nodes.offers_node import handle_offers
from nodes.transfer_node import handle_transfer
from utils.llm_connector import run_llm


# ---------- State Definition ----------
class AgentState(TypedDict):
    user_input: str
    intent: Literal["spend", "faq", "offers", "transfer", "unknown"]
    result: str


# ---------- Intent Classification Node ----------
def classify_intent(state: AgentState) -> AgentState:
    prompt = f"""
    Classify the user query into one of these intents:
    - spend (transactional/spending insights)
    - faq (banking related Q&A)
    - offers (discounts, deals, promotions)
    - transfer (fund transfer request)
    - unknown (none of the above)

    User query: "{state['user_input']}"
    Return only the intent label.
    """
    raw = run_llm(prompt)
    intent = raw.lower().strip()
    if intent not in ["spend", "faq", "offers", "transfer"]:
        intent = "unknown"
    state["intent"] = intent
    return state


# ---------- Handlers ----------
def spends_node(state: AgentState) -> AgentState:
    state["result"] = handle_spends(state["user_input"])
    return state

def faq_node(state: AgentState) -> AgentState:
    state["result"] = handle_faq(state["user_input"])
    return state

def offers_node(state: AgentState) -> AgentState:
    state["result"] = handle_offers(state["user_input"])
    return state

def transfer_node(state: AgentState) -> AgentState:
    state["result"] = handle_transfer(state["user_input"])
    return state

def unknown_node(state: AgentState) -> AgentState:
    state["result"] = "Sorry, I didn’t understand your request. Could you rephrase?"
    return state


def build_flow():
    workflow = StateGraph(AgentState)

    # Nodes
    workflow.add_node("classify_intent", classify_intent)
    workflow.add_node("spend", spends_node)
    workflow.add_node("faq", faq_node)
    workflow.add_node("offers", offers_node)
    workflow.add_node("transfer", transfer_node)
    workflow.add_node("unknown", unknown_node)

    # Edges
    workflow.set_entry_point("classify_intent")
    workflow.add_conditional_edges(
        "classify_intent",
        lambda state: state["intent"],
        {
            "spend": "spend",
            "faq": "faq",
            "offers": "offers",
            "transfer": "transfer",
            "unknown": "unknown",
        },
    )

    # Exit edges
    workflow.add_edge("spend", END)
    workflow.add_edge("faq", END)
    workflow.add_edge("offers", END)
    workflow.add_edge("transfer", END)
    workflow.add_edge("unknown", END)

    return workflow.compile()


if __name__ == "__main__":
    graph = build_flow()

    while True:
        user_input = input("You: ")
        if user_input.lower() in ["quit", "exit"]:
            break
        state = {"user_input": user_input, "intent": "unknown", "result": ""}
        result = graph.invoke(state)
        print("Bot:", result["result"])
