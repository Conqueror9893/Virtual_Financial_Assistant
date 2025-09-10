import json, os, random
from datetime import datetime
from utils.logger import get_logger

logger = get_logger("TransferTool")

BENEFICIARIES_PATH = "data/beneficiaries.json"
OTP_STORE = {}


def load_beneficiaries():
    if not os.path.exists(BENEFICIARIES_PATH):
        return []
    with open(BENEFICIARIES_PATH, "r") as f:
        return json.load(f)


def resolve_beneficiary(nickname: str):
    for b in load_beneficiaries():
        if b["nickname"].lower() == nickname.lower():
            return b
    return None


def generate_otp(user_id: int) -> str:
    otp = str(random.randint(100000, 999999))
    OTP_STORE[user_id] = otp
    logger.info("Generated OTP for user %d: %s", user_id, otp)
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
