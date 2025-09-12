# tools/transfer_tool.py
import json, os, random
from datetime import datetime
from utils.logger import get_logger

logger = get_logger("TransferTool")

BENEFICIARIES_PATH = "data/beneficiaries.json"
OTP_STORE = {}
logger.info("Current working directory: %s", os.getcwd())

def load_beneficiaries():
    if not os.path.exists(BENEFICIARIES_PATH):
        logger.warning("Beneficiaries file not found at %s", BENEFICIARIES_PATH)
        return []
    logger.info("Beneficiaries file found. Attempting to load...")
    try:
        with open(BENEFICIARIES_PATH, "r") as f:
            data = json.load(f)
            logger.info("Successfully loaded beneficiaries data with %d records", len(data) if isinstance(data, list) else 1)
            return data
    except json.JSONDecodeError as e:
        logger.error("Error decoding JSON from %s: %s", BENEFICIARIES_PATH, str(e))
        return []
    except Exception as e:
        logger.error("Unexpected error loading beneficiaries from %s: %s", BENEFICIARIES_PATH, str(e))
        return []
    
        


def resolve_beneficiary(nickname: str):
    for b in load_beneficiaries():
        if b["nickname"].lower() == nickname.lower():
            return b
    return None


def generate_otp(user_id: int) -> str:
    otp = str(random.randint(100000, 999999))
    OTP_STORE[user_id] = otp
    logger.info("Generated OTP for user %s: %s", user_id, otp)
    return otp


def validate_otp(user_id: int, otp: str) -> bool:
    return OTP_STORE.get(user_id) == otp


def perform_transfer(user_id: int, beneficiary: dict, amount: float) -> dict:
    logger.info("Performing transfer of %.2f to %s", amount, beneficiary["name"])
    return {
        "status": "success",
        "amount": amount,
        "to": beneficiary["name"],
        "account": beneficiary["account_number"],
        "ifsc": beneficiary["ifsc"],
        "timestamp": datetime.now().isoformat(),
    }
