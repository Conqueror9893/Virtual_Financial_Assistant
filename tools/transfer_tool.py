# tools/transfer_tool.py

import json
import os
import random
from datetime import datetime
from utils.logger import get_logger

logger = get_logger("TransferTool")
BENEFICIARIES_PATH = "data/beneficiaries.json"

# Structure: { user_id: { "otp": "123456", "attempts": 0, "max_attempts": 3 } }
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
        logger.info(
            "Successfully loaded beneficiaries data with %d records",
            len(data) if isinstance(data, list) else 1,
        )
        return data
    except json.JSONDecodeError as e:
        logger.error("Error decoding JSON from %s: %s", BENEFICIARIES_PATH, str(e))
        return []
    except Exception as e:
        logger.error(
            "Unexpected error loading beneficiaries from %s: %s",
            BENEFICIARIES_PATH,
            str(e),
        )
        return []


def resolve_beneficiary(nickname: str):
    for b in load_beneficiaries():
        if b["nickname"].lower() == nickname.lower():
            return b
    return None


def generate_otp(user_id: int) -> str:
    otp = str(random.randint(100000, 999999))
    OTP_STORE[user_id] = {"otp": otp, "attempts": 0, "max_attempts": 3}
    logger.info("Generated OTP for user %s: %s", user_id, otp)
    return otp


def validate_otp(user_id, otp: str) -> (bool, int):
    """
    Returns (is_valid, attempts_left)
    """
    # Ensure consistent type for user_id
    user_id = int(user_id)
    otp = otp.strip()

    record = OTP_STORE.get(user_id)
    if not record:
        return False, 0

    if record["otp"] == otp:
        OTP_STORE.pop(user_id, None)
        return True, record["max_attempts"] - record["attempts"]

    record["attempts"] += 1
    attempts_left = record["max_attempts"] - record["attempts"]
    if attempts_left <= 0:
        OTP_STORE.pop(user_id, None)
        return False, max(0, attempts_left)

    return False, attempts_left



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


def confirm_recommendation(beneficiary_id, recommendation_id, body):
    """
    Confirm the monthly transfer recommendation.

    Parameters:
    - beneficiary_id: str
    - recommendation_id: str
    - body: dict containing {"user_id": ..., "query": "yes"|"no"}

    Returns:
    - Flat dict with status, message, and optional trigger flag for frontend.
    """
    user_reply = body.get("query", "").strip().lower()
    if user_reply not in ["yes", "no"]:
        return {
            "status": "error",
            "message": "Invalid confirmation. Please reply with 'yes' or 'no'.",
            "show_transfer_form": False,
        }

    if user_reply == "yes":
        return {
            "status": "success",
            "message": "Monthly transfer setup successful. Please fill in the transfer form to complete your transaction.",
            "beneficiary_id": beneficiary_id,
            "recommendation_id": recommendation_id,
            "show_transfer_form": True,  # 👈 Frontend flag to open the form
        }
    else:
        return {
            "status": "success",
            "message": "Monthly transfer not set up.",
            "beneficiary_id": beneficiary_id,
            "recommendation_id": recommendation_id,
            "show_transfer_form": False,
        }
