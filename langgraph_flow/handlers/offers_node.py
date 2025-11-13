# langgraph_flow/nodes/offers_node.py
from tools.offers_tool import get_offers
from utils.logger import get_logger

logger = get_logger("OffersNode")

def handle_offers(user_id: int, query: str) -> dict:
    logger.info("Offers query: %s", query)
    offers = get_offers(user_id)
    return {"offers": offers}
