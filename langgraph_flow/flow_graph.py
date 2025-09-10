from langgraph.graph import StateGraph
from langgraph.pregel import Pregel
from langgraph_flow.nodes.intent_classifier import classify_intent
from langgraph_flow.nodes.faq_node import handle_faq
from langgraph_flow.nodes.spend_insights_node import handle_spend_insight
from langgraph_flow.nodes.transfer_node import handle_transfer
from langgraph_flow.nodes.output_formatter import format_response

def build_graph():
    graph = StateGraph()

    graph.add_node("IntentClassifier", classify_intent)
    graph.add_node("FAQNode", handle_faq)
    graph.add_node("SpendNode", handle_spend_insight)
    graph.add_node("TransferNode", handle_transfer)
    graph.add_node("OutputFormatter", format_response)

    graph.set_entry_point("IntentClassifier")

    graph.add_conditional_edges(
        "IntentClassifier",
        lambda state: state["intent"],
        {
            "faq": "FAQNode",
            "spend_check": "SpendNode",
            "money_transfer": "TransferNode"
        }
    )

    graph.add_edge("FAQNode", "OutputFormatter")
    graph.add_edge("SpendNode", "OutputFormatter")
    graph.add_edge("TransferNode", "OutputFormatter")
    graph.set_finish_point("OutputFormatter")

    return graph.compile()
