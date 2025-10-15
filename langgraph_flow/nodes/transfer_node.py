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
        amount = parsed.get("amount")
        if isinstance(amount, str) and amount.isdigit():
            amount = int(amount)
        return {
            "amount": amount,
            "beneficiary": parsed.get("beneficiary"),
            "frequency": parsed.get("frequency", "one-time")
        }
    except Exception as e:
        logger.error("Failed to parse transfer details from LLM response=%s, error=%s", response, str(e))
        return {}



def handle_transfer(user_id: int, query_or_details, otp: str = None) -> dict:
    """
    Main transfer handler.

    Steps:
      1. Parse transfer request (otp=None, query string)
      2. Validate OTP & perform transfer (otp != None)
      3. Confirm recommendation (query_or_details with action=confirm_recommendation)
    """

    # --- Step 3: Recommendation confirmation flow ---
    if isinstance(query_or_details, dict) and query_or_details.get("action") == "confirm_recommendation":
        beneficiary_id = query_or_details.get("beneficiary_id")
        recommendation_id = query_or_details.get("recommendation_id")

        # ✅ Fetch last successful transfer response if provided by frontend
        last_transfer_response = query_or_details.get("last_transfer_response")

        # ✅ Pass it to confirm_recommendation()
        return confirm_recommendation(
            beneficiary_id,
            recommendation_id,
            otp,  # this `otp` param here is reused as the body (user reply "yes"/"no")
            last_transfer_response=last_transfer_response
        )

    # --- Step 1: Initial transfer request (query string, otp not provided) ---
    if otp is None and isinstance(query_or_details, str):
        details = extract_transfer_details(query_or_details)

        amount = details.get("amount")
        nickname = details.get("beneficiary")
        frequency = details.get("frequency", "one-time")

        beneficiary = transfer_tool.resolve_beneficiary(nickname)
        # No matches
        if beneficiary is None:
            return {
                "status": "error",
                "message": f"No beneficiary found with the name '{nickname}'."
            }

        # Multiple matches (disambiguation)
        if isinstance(beneficiary, dict) and beneficiary.get("status") == "multiple_matches":
            return {
                "status": "multiple_matches",
                "message": beneficiary["message"],
                "options": beneficiary["options"]
            }


        otp_code = transfer_tool.generate_otp(user_id)
        return {
            "status": "otp_required",
            "message": f"OTP sent to registered mobile for transfer of ₹{amount} to {beneficiary['name']}.",
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

        # ✅ Updated OTP validation call (since validate_otp returns tuple)
        is_valid, _ = transfer_tool.validate_otp(user_id, otp)
        if not is_valid:
            return {
                "status": "otp_incorrect",
                "message": "Invalid OTP.",
                "awaiting_otp": True,
                "otp_incorrect": True
            }

        # Perform the actual transfer
        result = transfer_tool.perform_transfer(user_id, beneficiary, amount)

        recommendation = (
            f"You sent Rs {amount} to {beneficiary['name']} today. "
            f"Would you like to make this a monthly transfer?"
        )

        # Flattened, single-level response JSON
        transfer_response = {
            "status": "success",
            "message": f"Transfer of Rs {amount} to {beneficiary['name']} successful.",
            "amount": amount,
            "beneficiary": beneficiary["name"],
            "account": beneficiary.get("account_number"),
            "ifsc": beneficiary.get("ifsc"),
            "timestamp": result.get("timestamp"),
            "recommendation": recommendation,
            "recommendation_id": f"rec-{user_id}-{beneficiary.get('account_number')}"
        }

        return transfer_response

    return {"status": "error", "message": "Invalid transfer request format."}
