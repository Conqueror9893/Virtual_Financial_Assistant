# langgraph_flow/nodes/offers_node.py
from tools.offers_tool import get_offers
from utils.logger import get_logger
from contextual_questions_node import handle_contextual_questions_node


logger = get_logger("OffersNode")


def handle_offers(user_id: int, query: str) -> dict:
    contextual_questions = handle_contextual_questions_node(
        user_id=user_id,
        last_query=query,
        last_response="",
    ).get("contextual_questions", [])
    logger.info("Offers query: %s", query)
    offers = get_offers(user_id)
    return {"offers": offers, "contextual_questions": contextual_questions}
