# langgraph_flow/handlers/transfer_node.py

import json
import re
from utils.llm_connector import run_llm
from tools import transfer_tool
from tools.transfer_tool import confirm_recommendation
from utils.logger import get_logger
from utils.prompts import extraction_prompt


logger = get_logger("TransferNode")


def extract_transfer_details(query: str) -> dict:
    """
    Extract transfer details from query.
    
    Returns dict with:
    - amount (number)
    - to_beneficiary (name or nickname)
    - from_account (Savings/Current or None if not specified)
    - frequency (one-time / recurring / null)
    """
    prompt = extraction_prompt(query)
    
    response = run_llm(prompt)
    try:
        parsed = json.loads(response)
        
        # Normalize amount
        amount = parsed.get("amount")
        if isinstance(amount, str) and amount.isdigit():
            amount = int(amount)
        
        # Normalize from_account (case-insensitive, then capitalize properly)
        from_account = parsed.get("from_account")
        if from_account:
            from_account_lower = from_account.lower().strip()
            if "saving" in from_account_lower:
                from_account = "Savings"
            elif "current" in from_account_lower:
                from_account = "Current"
            else:
                from_account = None
        
        # Normalize to_beneficiary (trim whitespace)
        to_beneficiary = parsed.get("to_beneficiary")
        if to_beneficiary:
            to_beneficiary = to_beneficiary.strip()
        
        return {
            "amount": amount,
            "to_beneficiary": to_beneficiary,
            "from_account": from_account,
            "frequency": parsed.get("frequency", "one-time"),
        }
    except Exception as e:
        logger.error("Failed to parse transfer details from LLM response=%s, error=%s", response, str(e))
        return {}


def handle_transfer(user_id: int, query_or_details, otp: str = None) -> dict:
    """
    Main transfer handler.
    
    Steps:
    1. Parse transfer request (otp=None, query string)
    2. Handle beneficiary selection if multiple matches
    3. Handle account selection if from_account not specified
    4. Show transfer summary
    5. Validate OTP & perform transfer
    6. Confirm recommendation
    """
    
    # --- Step 6: Recommendation confirmation flow ---
    if isinstance(query_or_details, dict) and query_or_details.get("action") == "confirm_recommendation":
        beneficiary_id = query_or_details.get("beneficiary_id")
        recommendation_id = query_or_details.get("recommendation_id")
        last_transfer_response = query_or_details.get("last_transfer_response")
        
        return confirm_recommendation(
            beneficiary_id,
            recommendation_id,
            otp,
            last_transfer_response=last_transfer_response
        )
    
    # --- Step 1: Initial transfer request (query string, otp not provided) ---
    if otp is None and isinstance(query_or_details, str):
        details = extract_transfer_details(query_or_details)
        
        amount = details.get("amount")
        to_beneficiary = details.get("to_beneficiary")
        from_account = details.get("from_account")
        frequency = details.get("frequency", "one-time")
        
        if not amount or not to_beneficiary:
            return {
                "status": "error",
                "message": "Could not extract amount or beneficiary. Try: 'Transfer 500 to mom' or 'Send 100 to john from savings'"
            }
        
        # Look up beneficiary
        beneficiary_result = transfer_tool.resolve_beneficiary(to_beneficiary)
        
        # Multiple matches - user needs to select
        if isinstance(beneficiary_result, dict) and beneficiary_result.get("status") == "multiple_matches":
            return {
                "status": "multiple_matches",
                "message": beneficiary_result.get("message"),
                "options": beneficiary_result.get("options"),
                "amount": amount,
                "from_account": from_account,  # Preserve from_account if specified
            }
        
        # No match found
        if beneficiary_result is None:
            return {
                "status": "error",
                "message": f"No beneficiary found with name '{to_beneficiary}'."
            }
        
        # Single match found - check if from_account specified
        if from_account is None:
            # from_account not specified - need to ask user to select
            return {
                "status": "account_selection_required",
                "message": f"Sending {amount} to {beneficiary_result.get('name')}. Which account? (Savings/Current)",
                "options": ["Savings", "Current"],
                "amount": amount,
                "to_beneficiary": beneficiary_result,
                "beneficiary_nickname": to_beneficiary,
                "frequency": frequency,
            }
        else:
            # from_account specified - proceed to OTP
            otp_code = transfer_tool.generate_otp(user_id)
            return {
                "status": "otp_required",
                "message": f"OTP sent to registered mobile for transfer of ₹{amount} from {from_account} to {beneficiary_result['name']}.",
                "transfer_details": {
                    "amount": amount,
                    "to_beneficiary": beneficiary_result,
                    "from_account": from_account,
                    "beneficiary_nickname": to_beneficiary,
                    "frequency": frequency,
                }
            }
    
    # --- Step 2: OTP validation and transfer execution ---
    if otp is not None and isinstance(query_or_details, dict):
        details = query_or_details.get("transfer_details", query_or_details)
        amount = details.get("amount")
        to_beneficiary = details.get("to_beneficiary", {})
        from_account = details.get("from_account")
        
        if not amount or not to_beneficiary:
            return {"status": "error", "message": "Transfer details missing."}
        
        # Validate OTP
        is_valid, _ = transfer_tool.validate_otp(user_id, otp)
        if not is_valid:
            return {
                "status": "otp_incorrect",
                "message": "Invalid OTP.",
                "awaiting_otp": True,
                "otp_incorrect": True
            }
        
        # Perform the actual transfer
        result = transfer_tool.perform_transfer(user_id, to_beneficiary, amount)
        
        recommendation = (
            f"You sent Rs {amount} to {to_beneficiary.get('name')} today. "
            f"Would you like to make this a monthly transfer?"
        )
        
        # Flattened, single-level response JSON
        transfer_response = {
            "status": "success",
            "message": f"Transfer of Rs {amount} to {to_beneficiary.get('name')} successful.",
            "amount": amount,
            "beneficiary": to_beneficiary.get("name"),
            "account": to_beneficiary.get("account_number"),
            "ifsc": to_beneficiary.get("ifsc"),
            "timestamp": result.get("timestamp"),
            "recommendation": recommendation,
            "recommendation_id": f"rec-{user_id}-{to_beneficiary.get('account_number')}"
        }
        
        return transfer_response
    
    return {"status": "error", "message": "Invalid transfer request format."}
