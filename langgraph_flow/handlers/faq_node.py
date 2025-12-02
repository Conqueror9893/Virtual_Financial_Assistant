# langgraph_flow/nodes/faq_node.py
from tools.faq_tool import search_faq
from utils.logger import get_logger
from contextual_questions_node import handle_contextual_questions_node

logger = get_logger("FAQNode")


def handle_faq(user_id: int, query: str) -> dict:
    logger.info("FAQ query: %s", query)
    contextual_questions = handle_contextual_questions_node(
        user_id=user_id,
        last_query=query,
        last_response="",
    ).get("contextual_questions", [])
    result = search_faq(query)
    return {
        "query": query,
        "answer": result["answer"],
        "confidence": result["confidence"],
        "sources": result["sources"],
        "contextual_questions": contextual_questions,
    }
