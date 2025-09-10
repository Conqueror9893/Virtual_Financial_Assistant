import json
from utils.llm_connector import run_llm
from tools import transfer_tool
from utils.logger import get_logger

logger = get_logger("TransferNode")

def extract_transfer_details(query: str) -> dict:
    """
    Use LLM to parse transfer amount, beneficiary, frequency.
    """
    prompt = f"""
    Extract transfer details from this query: "{query}"

    Return JSON with keys:
      - amount (number)
      - beneficiary (nickname or name)
      - frequency (one-time / recurring / null)
    """
    response = run_llm(prompt)
    try:
        return json.loads(response)
    except:
        return {}

def handle_transfer(user_id: int, query: str, otp: str = None) -> dict:
    """
    Main transfer handler. If OTP is not provided, start OTP flow.
    """
    details = extract_transfer_details(query)
    amount = details.get("amount")
    nickname = details.get("beneficiary")
    frequency = details.get("frequency")

    beneficiary = transfer_tool.resolve_beneficiary(nickname)
    if not beneficiary:
        return {"status": "error", "message": f"Beneficiary '{nickname}' not found."}

    if otp is None:
        otp_code = transfer_tool.generate_otp(user_id)
        return {
            "status": "otp_required",
            "message": f"OTP sent to registered mobile for transfer of ₹{amount} to {beneficiary['name']}.",
            "otp_debug": otp_code  # remove in production!
        }
    else:
        if not transfer_tool.validate_otp(user_id, otp):
            return {"status": "error", "message": "Invalid OTP."}

        result = transfer_tool.perform_transfer(user_id, beneficiary, amount)

        # Recommendation stub (future improvement: check transaction history)
        recommendation = f"You sent ₹{amount} to {beneficiary['name']} today. Would you like to make this a monthly transfer?"

        return {
            "status": "success",
            "transfer": result,
            "recommendation": recommendation
        }
