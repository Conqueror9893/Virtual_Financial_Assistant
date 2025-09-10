import json
import os
from utils.logger import get_logger

logger = get_logger("OffersTool")

OFFERS_PATH = "data/offers.json"

def load_offers():
    try:
        if not os.path.exists(OFFERS_PATH):
            return []
        with open(OFFERS_PATH, "r") as f:
            offers = json.load(f)
        logger.info("Loaded %d offers", len(offers))
        return offers
    except Exception as e:
        logger.exception("Error loading offers: %s", str(e))
        return []

def get_offers(user_id: int):
    offers = load_offers()
    return offers if offers else [{"title": "No offers available", "details": "", "image": ""}]
