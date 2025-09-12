# langgraph_flow/nodes/transfer_node.py
import json
from utils.llm_connector import run_llm
from tools import transfer_tool
from utils.logger import get_logger

logger = get_logger("TransferNode")

def extract_transfer_details(query: str) -> dict:
    prompt = f"""
    Extract transfer details from this query: "{query}"

    Return JSON with keys:
      - amount (number)
      - beneficiary (name or nickname)
      - frequency (one-time / recurring / null)
    Example:
    {{"amount": 100, "beneficiary": "mom", "frequency": "one-time"}}
    """
    response = run_llm(prompt)
    try:
        parsed = json.loads(response)
        # Ensure required keys exist
        return {
            "amount": parsed.get("amount"),
            "beneficiary": parsed.get("beneficiary"),
            "frequency": parsed.get("frequency", "one-time")
        }
    except Exception as e:
        logger.error("Failed to parse transfer details from LLM response=%s, error=%s", response, str(e))
        return {}


def handle_transfer(user_id: int, query_or_details, otp: str = None) -> dict:
    """
    Main transfer handler.

    Parameters:
    - user_id: int
    - query_or_details: str (raw query) if otp=None,
                        or dict (parsed transfer details) if otp is provided
    - otp: str or None

    Returns a dict with transfer status, messages, OTP requests, etc.
    """

    if otp is None:
        # First step: parse raw query string to extract details
        details = extract_transfer_details(query_or_details)
    else:
        # OTP validation step: use existing parsed details directly
        details = query_or_details

    amount = details.get("amount")
    nickname = details.get("beneficiary")
    frequency = details.get("frequency", "one-time")

    beneficiary = transfer_tool.resolve_beneficiary(nickname)
    if not beneficiary:
        return {"status": "error", "message": f"Beneficiary '{nickname}' not found."}

    if otp is None:
        # Generate and send OTP to user
        otp_code = transfer_tool.generate_otp(user_id)
        return {
            "status": "otp_required",
            "message": f"OTP sent to registered mobile for transfer of ₹{amount} to {beneficiary['name']}.",
            "otp_debug": otp_code, # Remove debug info in production!
            "transfer_details": details
        }
    else:
        # Validate OTP entered by user
        if not transfer_tool.validate_otp(user_id, otp):
            return {"status": "otp_incorrect", "message": "Invalid OTP.", "awaiting_otp": True, "otp_incorrect": True}

        # Perform the transfer action
        result = transfer_tool.perform_transfer(user_id, beneficiary, amount)

        recommendation = f"You sent ₹{amount} to {beneficiary['name']} today. Would you like to make this a monthly transfer?"

        return {
            "status": "success",
            "transfer": result,
            "recommendation": recommendation
        }

