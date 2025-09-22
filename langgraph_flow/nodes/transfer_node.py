# langgraph_flow/nodes/transfer_node.py
import json
from utils.llm_connector import run_llm
from tools import transfer_tool
from tools.transfer_tool import confirm_recommendation
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
    - Step 1: Parse transfer request (otp=None, query string).
    - Step 2: Validate OTP and perform transfer (otp != None, transfer details dict).
    - Step 3: Confirm recommendation (query_or_details with action=confirm_recommendation).
    """
    # --- Step 3: Recommendation confirmation flow ---
    if isinstance(query_or_details, dict) and query_or_details.get("action") == "confirm_recommendation":
        beneficiary_id = query_or_details.get("beneficiary_id")
        recommendation_id = query_or_details.get("recommendation_id")
        return confirm_recommendation(beneficiary_id, recommendation_id, otp)

    # --- Step 1: Initial transfer request (query string, otp not provided) ---
    if otp is None and isinstance(query_or_details, str):
        details = extract_transfer_details(query_or_details)

        amount = details.get("amount")
        nickname = details.get("beneficiary")
        frequency = details.get("frequency", "one-time")

        beneficiary = transfer_tool.resolve_beneficiary(nickname)
        if not beneficiary:
            return {"status": "error", "message": f"Beneficiary '{nickname}' not found."}

        otp_code = transfer_tool.generate_otp(user_id)
        return {
            "status": "otp_required",
            "message": f"OTP sent to registered mobile for transfer of ₹{amount} to {beneficiary['name']}.",
            "otp_debug": otp_code,  # remove later
            "transfer_details": details
        }

    # --- Step 2: OTP validation and transfer execution ---
    if otp is not None and isinstance(query_or_details, dict):
        details = query_or_details.get("transfer_details", query_or_details)
        amount = details.get("amount")
        nickname = details.get("nickname") or details.get("beneficiary")

        if not nickname:
            return {"status": "error", "message": "Beneficiary is missing."}

        beneficiary = transfer_tool.resolve_beneficiary(nickname)
        if not beneficiary:
            return {"status": "error", "message": f"Beneficiary '{nickname}' not found."}

        if not transfer_tool.validate_otp(user_id, otp):
            return {
                "status": "otp_incorrect",
                "message": "Invalid OTP.",
                "awaiting_otp": True,
                "otp_incorrect": True
            }

        result = transfer_tool.perform_transfer(user_id, beneficiary, amount)
        recommendation = f"You sent ₹{amount} to {beneficiary['name']} today. Would you like to make this a monthly transfer?"

        return {
            "status": "success",
            "transfer": result,
            "recommendation": recommendation,
            "beneficiary_id": beneficiary.get("id", beneficiary.get("account_number")),
            "recommendation_id": f"rec-{user_id}-{beneficiary.get('account_number')}"
        }

    return {"status": "error", "message": "Invalid transfer request format."}
