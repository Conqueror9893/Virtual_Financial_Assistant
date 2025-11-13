# langgraph_flow/nodes/faq_node.py
from tools.faq_tool import search_faq
from utils.logger import get_logger

logger = get_logger("FAQNode")

def handle_faq(user_id: int, query: str) -> dict:
    logger.info("FAQ query: %s", query)
    result = search_faq(query)
    return {"query": query, "answer": result["answer"], "confidence": result["confidence"], "sources": result["sources"]}
