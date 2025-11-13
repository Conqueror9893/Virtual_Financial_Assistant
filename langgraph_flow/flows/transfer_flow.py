# # # langraph_flow/flows/transfer_flow.py

# # """
# # Isolated Fund Transfer Sub-Graph

# # This module contains the complete transfer flow including:
# # - Initial transfer handling
# # - OTP validation (up to 3 attempts)
# # - Recommendation confirmation
# # - Interruption handling during sensitive phases

# # This is completely separate from the main flow and can be
# # tested, modified, and debugged independently.
# # """

# # import json
# # import logging
# # from typing import Dict, Any, Optional
# # from ..core.state import StateManager
# # from ..core.constants import (
# #     ConversationPhase, IntentType, STATUS_OTP_REQUIRED, STATUS_OTP_INCORRECT,
# #     STATUS_ERROR, STATUS_SUCCESS, STATUS_FAILED, MAX_OTP_ATTEMPTS
# # )
# # from ..core.routing import IntentRouter
# # from ..handlers.transfer_node import handle_transfer, confirm_recommendation


# # logger = logging.getLogger(__name__)


# # class TransferFlowHandler:
# #     """Manages the complete transfer flow lifecycle."""
    
# #     @staticmethod
# #     def initiate_transfer(state: Dict[str, Any]) -> Dict[str, Any]:
# #         """
# #         Initiate a transfer request.
        
# #         Handles:
# #         - Initial transfer validation
# #         - OTP requirement detection
# #         - Phase transition to OTP if needed
# #         """
# #         StateManager.ensure_defaults(state)
# #         user_id = state.get("user_id", "0")
# #         user_input = (state.get("user_input") or "").strip()
        
# #         try:
# #             # Call transfer handler without OTP
# #             transfer_result = handle_transfer(user_id, user_input, otp=None)
# #         except Exception as e:
# #             logger.exception("Transfer initiation failed")
# #             state["result"] = {
# #                 STATUS_ERROR: True,
# #                 "message": f"Transfer initiation error: {str(e)}"
# #             }
# #             state["phase"] = ConversationPhase.NORMAL
# #             state["pending_transfer"] = None
# #             state["intent"] = IntentType.UNKNOWN
# #             return state
        
# #         state["result"] = transfer_result or {}
        
# #         # Check if OTP is required
# #         if isinstance(transfer_result, dict) and transfer_result.get("status") == STATUS_OTP_REQUIRED:
# #             TransferFlowHandler._transition_to_otp(state, transfer_result)
# #         else:
# #             # Transfer completed without OTP
# #             state["phase"] = ConversationPhase.NORMAL
# #             state["pending_transfer"] = None
            
# #             # Check for recommendation to confirm
# #             if isinstance(transfer_result, dict) and transfer_result.get("recommendation"):
# #                 TransferFlowHandler._transition_to_confirmation(state, transfer_result)
        
# #         return state
    
# #     @staticmethod
# #     def _transition_to_otp(state: Dict[str, Any], transfer_result: Dict) -> None:
# #         """Transition state to OTP phase."""
# #         state["phase"] = ConversationPhase.OTP
# #         state["intent"] = IntentType.OTP
        
# #         # Extract and parse transfer details
# #         transfer_details = transfer_result.get("transfer_details", {})
# #         if isinstance(transfer_details, str):
# #             try:
# #                 transfer_details = json.loads(transfer_details)
# #             except json.JSONDecodeError:
# #                 logger.warning("Failed to parse transfer_details JSON")
        
# #         state["pending_transfer"] = transfer_details or {}
# #         state["otp_attempts"] = 0
    
# #     @staticmethod
# #     def _transition_to_confirmation(state: Dict[str, Any], transfer_result: Dict) -> None:
# #         """Transition state to confirmation phase."""
# #         state["phase"] = ConversationPhase.CONFIRMATION
# #         state["intent"] = IntentType.CONFIRMATION
# #         state["confirmation_context"] = {
# #             "action": "confirm_recommendation",
# #             "details": transfer_result,
# #         }
    
# #     @staticmethod
# #     def validate_otp(state: Dict[str, Any]) -> Dict[str, Any]:
# #         """
# #         Validate OTP input.
        
# #         Handles:
# #         - OTP verification
# #         - Retry logic (max 3 attempts)
# #         - Phase transitions based on result
# #         """
# #         StateManager.ensure_defaults(state)
        
# #         # Validate we're in correct phase
# #         if StateManager.get_phase(state) != ConversationPhase.OTP:
# #             state["result"] = {
# #                 STATUS_ERROR: True,
# #                 "message": "No pending OTP validation. Please restart transfer."
# #             }
# #             return state
        
# #         user_id = state.get("user_id", "0")
# #         otp = (state.get("user_input") or "").strip()
# #         pending_transfer = state.get("pending_transfer") or {}
        
# #         if not pending_transfer:
# #             state["result"] = {
# #                 STATUS_ERROR: True,
# #                 "message": "Transfer details not found. Please restart transfer."
# #             }
# #             state["phase"] = ConversationPhase.NORMAL
# #             state["pending_transfer"] = None
# #             state["intent"] = IntentType.UNKNOWN
# #             return state
        
# #         try:
# #             transfer_result = handle_transfer(user_id, pending_transfer, otp)
# #         except Exception as e:
# #             logger.exception("OTP validation failed")
# #             TransferFlowHandler._handle_otp_max_attempts(state)
# #             return state
        
# #         state["result"] = transfer_result or {}
        
# #         # Check OTP result
# #         if transfer_result.get("status") == STATUS_OTP_INCORRECT:
# #             TransferFlowHandler._handle_otp_incorrect(state)
# #         elif transfer_result.get("status") == STATUS_SUCCESS:
# #             TransferFlowHandler._handle_transfer_success(state, transfer_result)
# #         else:
# #             # Other error status
# #             state["phase"] = ConversationPhase.NORMAL
# #             state["pending_transfer"] = None
# #             state["otp_attempts"] = 0
# #             state["intent"] = IntentType.UNKNOWN
        
# #         return state
    
# #     @staticmethod
# #     def _handle_otp_incorrect(state: Dict[str, Any]) -> None:
# #         """Handle incorrect OTP attempt."""
# #         state["otp_attempts"] = state.get("otp_attempts", 0) + 1
        
# #         if state["otp_attempts"] >= MAX_OTP_ATTEMPTS:
# #             TransferFlowHandler._handle_otp_max_attempts(state)
# #         else:
# #             # Allow retry
# #             attempts_left = MAX_OTP_ATTEMPTS - state["otp_attempts"]
# #             state["result"] = {
# #                 STATUS_ERROR: True,
# #                 "message": f"Incorrect OTP. {attempts_left} attempt(s) remaining."
# #             }
# #             state["phase"] = ConversationPhase.OTP
# #             state["intent"] = IntentType.OTP
    
# #     @staticmethod
# #     def _handle_otp_max_attempts(state: Dict[str, Any]) -> None:
# #         """Handle max OTP attempts exceeded."""
# #         state["result"] = {
# #             STATUS_FAILED: True,
# #             "message": "Maximum OTP attempts exceeded. Transfer cancelled."
# #         }
# #         state["phase"] = ConversationPhase.NORMAL
# #         state["pending_transfer"] = None
# #         state["otp_attempts"] = 0
# #         state["intent"] = IntentType.UNKNOWN
    
# #     @staticmethod
# #     def _handle_transfer_success(state: Dict[str, Any], transfer_result: Dict) -> None:
# #         """Handle successful transfer completion."""
# #         state["phase"] = ConversationPhase.NORMAL
# #         state["pending_transfer"] = None
# #         state["otp_attempts"] = 0
        
# #         # Check for recommendation to confirm
# #         if transfer_result.get("recommendation"):
# #             TransferFlowHandler._transition_to_confirmation(state, transfer_result)
# #             logger.info("Transitioned to confirmation phase after successful transfer.")
# #             logger.info(f"Confirmation context: {state.get('confirmation_context')}")
# #             logger.info(f"State after transfer success: {state}")
# #         else:
# #             state["intent"] = IntentType.UNKNOWN
    
# #     @staticmethod
# #     def confirm_recommendation(state: Dict[str, Any]) -> Dict[str, Any]:
# #         """
# #         Handle recommendation confirmation (yes/no).
        
# #         Called from confirmation phase after successful transfer.
# #         """
# #         StateManager.ensure_defaults(state)
        
# #         if StateManager.get_phase(state) != ConversationPhase.CONFIRMATION:
# #             state["result"] = "No pending confirmation."
# #             return state
        
# #         user_input = IntentRouter.normalize_confirmation_input(state.get("user_input"))
# #         logger.info(f"User confirmation input: {user_input}")
# #         state["user_input"] = user_input
# #         logger.info(f"Updated state user_input for confirmation: {state['user_input']}")
        
# #         ctx = state.get("confirmation_context") or {}
# #         logger.info(f"Confirmation context: {ctx}")
# #         details = ctx.get("details", {})
# #         logger.info(f"Confirmation details: {details}")
        
# #         try:
# #             result = confirm_recommendation(
# #                 details.get("beneficiary_id"),
# #                 details.get("recommendation_id"),
# #                 {
# #                     "user_id": state.get("user_id", "1"),
# #                     "action": user_input,
# #                 }
# #             )
# #             state["result"] = result
# #         except Exception as e:
# #             logger.exception("Confirmation handler failed")
# #             state["result"] = {
# #                 STATUS_ERROR: True,
# #                 "message": f"Confirmation error: {str(e)}"
# #             }
        
# #         # Reset to normal phase
# #         state["phase"] = ConversationPhase.NORMAL
# #         state["confirmation_context"] = None
# #         state["intent"] = IntentType.UNKNOWN
        
# #         return state


# # langraph_flow/flows/transfer_flow.py

# """
# Enhanced Fund Transfer Sub-Graph with Multiple Beneficiary Handling

# Flow:
# 1. TRANSFER → Parse query & extract details
# 2. BENEFICIARY_SELECTION → Handle multiple matches (if any)
# 3. ACCOUNT_SELECTION → Choose from/to account
# 4. TRANSFER_SUMMARY → Review & confirm
# 5. OTP → Validate OTP
# 6. CONFIRMATION → Handle recurring recommendation
# 7. NORMAL → Return to normal flow

# Handles interruptions in all phases.
# """

# import json
# import logging
# from typing import Dict, Any, Optional, List
# from ..core.state import StateManager
# from ..core.constants import (
#     ConversationPhase, IntentType, STATUS_OTP_REQUIRED, STATUS_OTP_INCORRECT,
#     STATUS_ERROR, STATUS_SUCCESS, STATUS_FAILED, MAX_OTP_ATTEMPTS,
#     MAX_INVALID_SELECTION_ATTEMPTS, STATUS_MULTIPLE_MATCHES, 
#     STATUS_INVALID_SELECTION, TRANSFER_FLOW_PHASES
# )
# from ..core.routing import IntentRouter
# from ..handlers.transfer_node import handle_transfer
# from tools import transfer_tool


# logger = logging.getLogger(__name__)


# class TransferFlowHandler:
#     """Manages the complete enhanced transfer flow lifecycle."""
    
#     # ========================================================================
#     # MAIN ENTRY POINT
#     # ========================================================================
    
#     @staticmethod
#     def initiate_transfer(state: Dict[str, Any]) -> Dict[str, Any]:
#         """
#         Initiate transfer flow.
        
#         Parse query and determine next phase:
#         - Multiple beneficiaries → BENEFICIARY_SELECTION
#         - Single beneficiary, need account → ACCOUNT_SELECTION
#         - All details provided → TRANSFER_SUMMARY
#         """
#         StateManager.ensure_defaults(state)
#         user_id = state.get("user_id", "0")
#         user_input = (state.get("user_input") or "").strip()
        
#         try:
#             # Extract transfer details from query
#             from ..handlers.transfer_node import extract_transfer_details
#             details = extract_transfer_details(user_input)
            
#             amount = details.get("amount")
#             beneficiary_nickname = details.get("beneficiary")
            
#             if not amount or not beneficiary_nickname:
#                 state["result"] = {
#                     STATUS_ERROR: True,
#                     "message": "Could not extract amount or beneficiary. Try: 'Send 500 to Amy'"
#                 }
#                 state["phase"] = ConversationPhase.NORMAL
#                 state["intent"] = IntentType.UNKNOWN
#                 return state
            
#             # Look up beneficiary
#             beneficiary_result = transfer_tool.resolve_beneficiary(beneficiary_nickname)
            
#             # Multiple matches found
#             if isinstance(beneficiary_result, dict) and beneficiary_result.get("status") == STATUS_MULTIPLE_MATCHES:
#                 state["phase"] = ConversationPhase.BENEFICIARY_SELECTION
#                 state["intent"] = IntentType.TRANSFER
#                 state["pending_transfer"] = {
#                     "amount": amount,
#                     "nickname": beneficiary_nickname,
#                     "frequency": details.get("frequency", "one-time"),
#                 }
#                 state["selection_attempts"] = 0
#                 state["result"] = beneficiary_result
#                 return state
            
#             # Single match or no match
#             if beneficiary_result is None:
#                 state["result"] = {
#                     STATUS_ERROR: True,
#                     "message": f"No beneficiary found with name '{beneficiary_nickname}'"
#                 }
#                 state["phase"] = ConversationPhase.NORMAL
#                 state["intent"] = IntentType.UNKNOWN
#                 return state
            
#             # Single beneficiary found - move to account selection
#             state["phase"] = ConversationPhase.ACCOUNT_SELECTION
#             state["intent"] = IntentType.TRANSFER
#             state["pending_transfer"] = {
#                 "amount": amount,
#                 "to_beneficiary": beneficiary_result,
#                 "nickname": beneficiary_nickname,
#                 "frequency": details.get("frequency", "one-time"),
#             }
#             state["selection_attempts"] = 0
#             state["result"] = {
#                 STATUS_SUCCESS: True,
#                 "message": f"Sending {amount} to {beneficiary_result.get('name')}. Which account? (Savings/Current)",
#                 "options": ["Savings", "Current"]
#             }
#             return state
        
#         except Exception as e:
#             logger.exception("Transfer initiation failed")
#             state["result"] = {
#                 STATUS_ERROR: True,
#                 "message": f"Transfer initiation error: {str(e)}"
#             }
#             state["phase"] = ConversationPhase.NORMAL
#             state["pending_transfer"] = None
#             return state
    
#     # ========================================================================
#     # BENEFICIARY SELECTION PHASE
#     # ========================================================================
    
#     @staticmethod
#     def handle_beneficiary_selection(state: Dict[str, Any]) -> Dict[str, Any]:
#         """
#         Handle beneficiary selection when multiple matches exist.
        
#         User input: "Amy Pareira" or "Amy Jones" (case-insensitive)
#         """
#         StateManager.ensure_defaults(state)
#         user_input = (state.get("user_input") or "").strip()
#         pending = state.get("pending_transfer", {})
#         options = state.get("result", {}).get("options", [])
        
#         if not user_input:
#             state["result"] = {
#                 STATUS_ERROR: True,
#                 "message": "Please select a beneficiary",
#                 "options": [opt.get("name") for opt in options]
#             }
#             return state
        
#         # Find matching beneficiary (case-insensitive)
#         selected = None
#         for opt in options:
#             if opt.get("name", "").lower() == user_input.lower():
#                 selected = opt
#                 break
        
#         if not selected:
#             attempts = state.get("selection_attempts", 0) + 1
#             state["selection_attempts"] = attempts
            
#             if attempts >= MAX_INVALID_SELECTION_ATTEMPTS:
#                 # Max attempts exceeded
#                 logger.warning("Max beneficiary selection attempts exceeded for user %s", state.get("user_id"))
#                 state["result"] = {
#                     STATUS_ERROR: True,
#                     "message": "Too many invalid selections. Transfer cancelled."
#                 }
#                 state["phase"] = ConversationPhase.NORMAL
#                 state["pending_transfer"] = None
#                 state["intent"] = IntentType.UNKNOWN
#                 return state
            
#             # Retry
#             remaining = MAX_INVALID_SELECTION_ATTEMPTS - attempts
#             state["result"] = {
#                 STATUS_INVALID_SELECTION: True,
#                 "message": f"Invalid selection. {remaining} attempt(s) remaining. Please select from:",
#                 "options": [opt.get("name") for opt in options]
#             }
#             state["phase"] = ConversationPhase.BENEFICIARY_SELECTION
#             return state
        
#         # Valid selection - move to account selection
#         state["pending_transfer"]["to_beneficiary"] = selected
#         state["phase"] = ConversationPhase.ACCOUNT_SELECTION
#         state["selection_attempts"] = 0
#         state["result"] = {
#             STATUS_SUCCESS: True,
#             "message": f"Selected {selected.get('name')}. Which account? (Savings/Current)",
#             "options": ["Savings", "Current"]
#         }
#         return state
    
#     # ========================================================================
#     # ACCOUNT SELECTION PHASE
#     # ========================================================================
    
#     @staticmethod
#     def handle_account_selection(state: Dict[str, Any]) -> Dict[str, Any]:
#         """
#         Handle account selection (Savings or Current).
        
#         User input: "Savings" or "Current" (case-insensitive)
#         """
#         StateManager.ensure_defaults(state)
#         user_input = (state.get("user_input") or "").strip()
#         pending = state.get("pending_transfer", {})
        
#         # Normalize account selection (case-insensitive)
#         user_account = user_input.lower()
#         if user_account not in ["savings", "current"]:
#             attempts = state.get("selection_attempts", 0) + 1
#             state["selection_attempts"] = attempts
            
#             if attempts >= MAX_INVALID_SELECTION_ATTEMPTS:
#                 logger.warning("Max account selection attempts exceeded for user %s", state.get("user_id"))
#                 state["result"] = {
#                     STATUS_ERROR: True,
#                     "message": "Too many invalid selections. Transfer cancelled."
#                 }
#                 state["phase"] = ConversationPhase.NORMAL
#                 state["pending_transfer"] = None
#                 state["intent"] = IntentType.UNKNOWN
#                 return state
            
#             remaining = MAX_INVALID_SELECTION_ATTEMPTS - attempts
#             state["result"] = {
#                 STATUS_INVALID_SELECTION: True,
#                 "message": f"Invalid account type. {remaining} attempt(s) remaining. Please select: Savings or Current"
#             }
#             state["phase"] = ConversationPhase.ACCOUNT_SELECTION
#             return state
        
#         # Valid selection - move to transfer summary
#         to_beneficiary = pending.get("to_beneficiary", {})
#         amount = pending.get("amount")
        
#         summary = {
#             "amount": amount,
#             "from_account": user_account.capitalize(),
#             "to_beneficiary": to_beneficiary.get("name"),
#             "to_account": to_beneficiary.get("account_number"),
#             "to_ifsc": to_beneficiary.get("ifsc"),
#         }
        
#         state["pending_transfer"]["from_account"] = user_account.capitalize()
#         state["pending_transfer"]["summary"] = summary
#         state["phase"] = ConversationPhase.TRANSFER_SUMMARY
#         state["selection_attempts"] = 0
#         state["result"] = {
#             STATUS_SUCCESS: True,
#             "message": f"Transfer Summary:\n"
#                       f"Amount: ₹{amount}\n"
#                       f"From: {user_account.capitalize()} Account\n"
#                       f"To: {to_beneficiary.get('name')}\n"
#                       f"Account: {to_beneficiary.get('account_number')}\n"
#                       f"\nConfirm? (yes/no)",
#             "summary": summary
#         }
#         return state
    
#     # ========================================================================
#     # TRANSFER SUMMARY PHASE
#     # ========================================================================
    
#     @staticmethod
#     def handle_transfer_summary_confirmation(state: Dict[str, Any]) -> Dict[str, Any]:
#         """
#         Handle confirmation of transfer summary.
        
#         User input: "yes" or "no" (case-insensitive)
#         """
#         StateManager.ensure_defaults(state)
#         user_input = (state.get("user_input") or "").strip().lower()
        
#         if user_input not in ("yes", "no"):
#             attempts = state.get("selection_attempts", 0) + 1
#             state["selection_attempts"] = attempts
            
#             if attempts >= MAX_INVALID_SELECTION_ATTEMPTS:
#                 logger.warning("Max confirmation attempts exceeded for user %s", state.get("user_id"))
#                 state["result"] = {
#                     STATUS_ERROR: True,
#                     "message": "Too many invalid responses. Transfer cancelled."
#                 }
#                 state["phase"] = ConversationPhase.NORMAL
#                 state["pending_transfer"] = None
#                 state["intent"] = IntentType.UNKNOWN
#                 return state
            
#             remaining = MAX_INVALID_SELECTION_ATTEMPTS - attempts
#             state["result"] = {
#                 STATUS_INVALID_SELECTION: True,
#                 "message": f"Please confirm with 'yes' or 'no'. {remaining} attempt(s) remaining."
#             }
#             state["phase"] = ConversationPhase.TRANSFER_SUMMARY
#             return state
        
#         if user_input == "no":
#             # User cancelled
#             state["result"] = {
#                 STATUS_FAILED: True,
#                 "message": "Transfer cancelled."
#             }
#             state["phase"] = ConversationPhase.NORMAL
#             state["pending_transfer"] = None
#             state["intent"] = IntentType.UNKNOWN
#             return state
        
#         # User confirmed - move to OTP phase
#         user_id = state.get("user_id", "0")
#         try:
#             otp_code = transfer_tool.generate_otp(int(user_id))
            
#             state["phase"] = ConversationPhase.OTP
#             state["intent"] = IntentType.OTP
#             state["otp_attempts"] = 0
#             state["result"] = {
#                 STATUS_OTP_REQUIRED: True,
#                 "message": f"OTP sent to your registered mobile. Please enter OTP to confirm transfer of ₹{state['pending_transfer'].get('amount')}"
#             }
#             return state
#         except Exception as e:
#             logger.exception("OTP generation failed")
#             state["result"] = {
#                 STATUS_ERROR: True,
#                 "message": f"Failed to send OTP: {str(e)}"
#             }
#             state["phase"] = ConversationPhase.NORMAL
#             state["pending_transfer"] = None
#             return state
    
#     # ========================================================================
#     # OTP VALIDATION PHASE
#     # ========================================================================
    
#     @staticmethod
#     def validate_otp(state: Dict[str, Any]) -> Dict[str, Any]:
#         """
#         Validate OTP input.
        
#         Handles:
#         - OTP verification
#         - Retry logic (max 3 attempts)
#         - Phase transitions based on result
#         """
#         StateManager.ensure_defaults(state)
        
#         if StateManager.get_phase(state) != ConversationPhase.OTP:
#             state["result"] = {
#                 STATUS_ERROR: True,
#                 "message": "No pending OTP validation."
#             }
#             return state
        
#         user_id = state.get("user_id", "0")
#         otp = (state.get("user_input") or "").strip()
#         pending_transfer = state.get("pending_transfer") or {}
        
#         if not pending_transfer:
#             state["result"] = {
#                 STATUS_ERROR: True,
#                 "message": "Transfer details not found. Please restart."
#             }
#             state["phase"] = ConversationPhase.NORMAL
#             state["pending_transfer"] = None
#             state["intent"] = IntentType.UNKNOWN
#             return state
        
#         try:
#             is_valid, attempts_left = transfer_tool.validate_otp(int(user_id), otp)
            
#             if not is_valid:
#                 state["otp_attempts"] = state.get("otp_attempts", 0) + 1
                
#                 if state["otp_attempts"] >= MAX_OTP_ATTEMPTS:
#                     logger.warning("Max OTP attempts exceeded for user %s", user_id)
#                     state["result"] = {
#                         STATUS_FAILED: True,
#                         "message": "Maximum OTP attempts exceeded. Transfer cancelled."
#                     }
#                     state["phase"] = ConversationPhase.NORMAL
#                     state["pending_transfer"] = None
#                     state["otp_attempts"] = 0
#                     state["intent"] = IntentType.UNKNOWN
#                     return state
                
#                 # Retry allowed
#                 remaining = MAX_OTP_ATTEMPTS - state["otp_attempts"]
#                 state["result"] = {
#                     STATUS_OTP_INCORRECT: True,
#                     "message": f"Invalid OTP. {remaining} attempt(s) remaining."
#                 }
#                 state["phase"] = ConversationPhase.OTP
#                 state["intent"] = IntentType.OTP
#                 return state
            
#             # OTP valid - perform transfer
#             to_beneficiary = pending_transfer.get("to_beneficiary", {})
#             amount = pending_transfer.get("amount")
            
#             transfer_result = transfer_tool.perform_transfer(
#                 int(user_id),
#                 to_beneficiary,
#                 amount
#             )
            
#             # Build recommendation
#             recommendation = (
#                 f"You sent ₹{amount} to {to_beneficiary.get('name')} today. "
#                 f"Would you like to make this a recurring monthly transfer?"
#             )
            
#             state["result"] = {
#                 STATUS_SUCCESS: True,
#                 "message": f"Transfer of ₹{amount} to {to_beneficiary.get('name')} successful!",
#                 "amount": amount,
#                 "beneficiary": to_beneficiary.get("name"),
#                 "account": to_beneficiary.get("account_number"),
#                 "ifsc": to_beneficiary.get("ifsc"),
#                 "timestamp": transfer_result.get("timestamp"),
#                 "recommendation": recommendation,
#                 "recommendation_id": f"rec-{user_id}-{to_beneficiary.get('id', 'unknown')}"
#             }
            
#             # Move to confirmation phase for recurring recommendation
#             state["phase"] = ConversationPhase.CONFIRMATION
#             state["intent"] = IntentType.CONFIRMATION
#             state["confirmation_context"] = {
#                 "action": "confirm_recurring_transfer",
#                 "details": state["result"],
#             }
#             state["otp_attempts"] = 0
#             state["pending_transfer"] = None
            
#             return state
        
#         except Exception as e:
#             logger.exception("OTP validation failed")
#             state["result"] = {
#                 STATUS_ERROR: True,
#                 "message": f"OTP validation error: {str(e)}"
#             }
#             state["phase"] = ConversationPhase.NORMAL
#             state["pending_transfer"] = None
#             state["otp_attempts"] = 0
#             return state
    
#     # ========================================================================
#     # CONFIRMATION PHASE (Recurring Transfer)
#     # ========================================================================
    
#     @staticmethod
#     def confirm_recurring_transfer(state: Dict[str, Any]) -> Dict[str, Any]:
#         """
#         Handle recommendation confirmation (yes/no for recurring transfer).
        
#         Called after successful transfer to ask about recurring setup.
#         """
#         StateManager.ensure_defaults(state)
        
#         if StateManager.get_phase(state) != ConversationPhase.CONFIRMATION:
#             state["result"] = "No pending confirmation."
#             return state
        
#         user_input = IntentRouter.normalize_confirmation_input(state.get("user_input"))
#         state["user_input"] = user_input
        
#         ctx = state.get("confirmation_context") or {}
#         details = ctx.get("details", {})
        
#         if user_input == "yes":
#             # Show transfer form for recurring setup
#             state["result"] = {
#                 STATUS_SUCCESS: True,
#                 "message": "Great! Let's set up your recurring transfer. Please provide frequency and start date.",
#                 "action": "show_transfer_form",
#                 "recommendation_id": details.get("recommendation_id"),
#                 "beneficiary_id": details.get("account"),  # Using account as ID for now
#             }
#         else:
#             # Don't set up recurring
#             state["result"] = {
#                 STATUS_SUCCESS: True,
#                 "message": "Recurring transfer not set up. Transfer completed successfully!",
#                 "action": "close_transfer_form"
#             }
        
#         # Return to normal phase
#         state["phase"] = ConversationPhase.NORMAL
#         state["confirmation_context"] = None
#         state["intent"] = IntentType.UNKNOWN
        
#         return state



# langraph_flow/flows/transfer_flow_enhanced_v2.py - UPDATED

"""
Enhanced Fund Transfer Sub-Graph v2 - Fixed Query-Based Phase Routing

Flow is NOW DYNAMIC based on query details:

Query: "transfer 100 to mom" (no from_account)
  → Single beneficiary? YES → ACCOUNT_SELECTION
  → Multiple beneficiaries? YES → BENEFICIARY_SELECTION

Query: "transfer 100 to mom from savings" (from_account specified)
  → Single beneficiary? YES → TRANSFER_SUMMARY (skip account selection)
  → Multiple beneficiaries? YES → BENEFICIARY_SELECTION

Then: TRANSFER_SUMMARY → OTP → CONFIRMATION → NORMAL
"""

import json
import logging
from typing import Dict, Any, Optional, List
from ..core.state import StateManager
from ..core.constants import (
    ConversationPhase, IntentType, STATUS_OTP_REQUIRED, STATUS_OTP_INCORRECT,
    STATUS_ERROR, STATUS_SUCCESS, STATUS_FAILED, MAX_OTP_ATTEMPTS,
    MAX_INVALID_SELECTION_ATTEMPTS, STATUS_MULTIPLE_MATCHES, 
    STATUS_INVALID_SELECTION, TRANSFER_FLOW_PHASES
)
from ..core.routing import IntentRouter
from tools import transfer_tool


logger = logging.getLogger(__name__)


class TransferFlowHandler:
    """Manages the complete enhanced transfer flow lifecycle."""
    
    @staticmethod
    def initiate_transfer(state: Dict[str, Any]) -> Dict[str, Any]:
        """
        Initiate transfer flow - FIXED to handle from_account extraction.
        
        Routes based on:
        1. If multiple beneficiaries → BENEFICIARY_SELECTION
        2. If from_account NOT specified → ACCOUNT_SELECTION
        3. If from_account specified → TRANSFER_SUMMARY
        """
        StateManager.ensure_defaults(state)
        user_id = state.get("user_id", "0")
        user_input = (state.get("user_input") or "").strip()
        
        try:
            # Extract transfer details from query
            from ..handlers.transfer_node import extract_transfer_details
            details = extract_transfer_details(user_input)
            
            amount = details.get("amount")
            to_beneficiary_name = details.get("to_beneficiary")
            from_account = details.get("from_account")  # Can be None
            frequency = details.get("frequency", "one-time")
            
            if not amount or not to_beneficiary_name:
                state["result"] = {
                    STATUS_ERROR: True,
                    "message": "Could not extract amount or beneficiary. Try: 'Transfer 500 to mom' or 'Send 100 to john from savings'"
                }
                state["phase"] = ConversationPhase.NORMAL
                state["intent"] = IntentType.UNKNOWN
                return state
            
            # Look up beneficiary
            beneficiary_result = transfer_tool.resolve_beneficiary(to_beneficiary_name)
            
            # Case 1: Multiple matches found
            if isinstance(beneficiary_result, dict) and beneficiary_result.get("status") == "multiple_matches":
                state["phase"] = ConversationPhase.BENEFICIARY_SELECTION
                state["intent"] = IntentType.TRANSFER
                state["pending_transfer"] = {
                    "amount": amount,
                    "to_beneficiary_name": to_beneficiary_name,
                    "from_account": from_account,  # Preserve if specified
                    "frequency": frequency,
                    "multiple_options": beneficiary_result.get("options"),
                }
                state["selection_attempts"] = 0
                state["result"] = beneficiary_result
                logger.info("Multiple beneficiaries found for '%s', transitioning to BENEFICIARY_SELECTION", to_beneficiary_name)
                return state
            
            # Case 2: No match found
            if beneficiary_result is None:
                state["result"] = {
                    STATUS_ERROR: True,
                    "message": f"No beneficiary found with name '{to_beneficiary_name}'"
                }
                state["phase"] = ConversationPhase.NORMAL
                state["intent"] = IntentType.UNKNOWN
                return state
            
            # Case 3: Single match found
            # Now check if from_account is specified
            if from_account is None:
                # from_account NOT specified - ask user to select
                state["phase"] = ConversationPhase.ACCOUNT_SELECTION
                state["intent"] = IntentType.TRANSFER
                state["pending_transfer"] = {
                    "amount": amount,
                    "to_beneficiary": beneficiary_result,
                    "to_beneficiary_name": to_beneficiary_name,
                    "frequency": frequency,
                }
                state["selection_attempts"] = 0
                state["result"] = {
                    STATUS_SUCCESS: True,
                    "message": f"Sending ₹{amount} to {beneficiary_result.get('name')}. Which account do you want to send from? (Savings/Current)",
                    "options": ["Savings", "Current"]
                }
                logger.info("Single beneficiary found, from_account not specified, transitioning to ACCOUNT_SELECTION")
                return state
            else:
                # from_account IS specified - skip to TRANSFER_SUMMARY
                summary = {
                    "amount": amount,
                    "from_account": from_account,
                    "to_beneficiary": beneficiary_result.get("name"),
                    "to_account": beneficiary_result.get("account_number"),
                    "to_ifsc": beneficiary_result.get("ifsc"),
                }
                
                state["phase"] = ConversationPhase.TRANSFER_SUMMARY
                state["intent"] = IntentType.TRANSFER
                state["pending_transfer"] = {
                    "amount": amount,
                    "to_beneficiary": beneficiary_result,
                    "to_beneficiary_name": to_beneficiary_name,
                    "from_account": from_account,
                    "frequency": frequency,
                    "summary": summary,
                }
                state["selection_attempts"] = 0
                state["result"] = {
                    STATUS_SUCCESS: True,
                    "message": f"Transfer Summary:\n"
                              f"Amount: ₹{amount}\n"
                              f"From: {from_account} Account\n"
                              f"To: {beneficiary_result.get('name')}\n"
                              f"Account: {beneficiary_result.get('account_number')}\n"
                              f"\nConfirm? (yes/no)",
                    "summary": summary
                }
                logger.info("Single beneficiary found, from_account specified, transitioning to TRANSFER_SUMMARY")
                return state
        
        except Exception as e:
            logger.exception("Transfer initiation failed")
            state["result"] = {
                STATUS_ERROR: True,
                "message": f"Transfer initiation error: {str(e)}"
            }
            state["phase"] = ConversationPhase.NORMAL
            state["pending_transfer"] = None
            return state
    
    # ========================================================================
    # BENEFICIARY SELECTION PHASE
    # ========================================================================
    
    @staticmethod
    def handle_beneficiary_selection(state: Dict[str, Any]) -> Dict[str, Any]:
        """
        Handle beneficiary selection when multiple matches exist.
        
        After selection, check if from_account was specified in original query:
        - If YES → ACCOUNT_SELECTION (still need to select account)
        - If NO → ACCOUNT_SELECTION (need to select account)
        
        Actually both cases go to ACCOUNT_SELECTION, so beneficiary selection
        always transitions to account selection.
        """
        StateManager.ensure_defaults(state)
        user_input = (state.get("user_input") or "").strip()
        pending = state.get("pending_transfer", {})
        options = state.get("result", {}).get("options", [])
        
        if not user_input:
            state["result"] = {
                STATUS_ERROR: True,
                "message": "Please select a beneficiary",
                "options": [opt.get("name") for opt in options]
            }
            return state
        
        # Find matching beneficiary (case-insensitive)
        selected = None
        for opt in options:
            if opt.get("name", "").lower() == user_input.lower():
                selected = opt
                break
        
        if not selected:
            attempts = state.get("selection_attempts", 0) + 1
            state["selection_attempts"] = attempts
            
            if attempts >= MAX_INVALID_SELECTION_ATTEMPTS:
                logger.warning("Max beneficiary selection attempts exceeded for user %s", state.get("user_id"))
                state["result"] = {
                    STATUS_ERROR: True,
                    "message": "Too many invalid selections. Transfer cancelled."
                }
                state["phase"] = ConversationPhase.NORMAL
                state["pending_transfer"] = None
                state["intent"] = IntentType.UNKNOWN
                return state
            
            remaining = MAX_INVALID_SELECTION_ATTEMPTS - attempts
            state["result"] = {
                STATUS_INVALID_SELECTION: True,
                "message": f"Invalid selection. {remaining} attempt(s) remaining. Please select from:",
                "options": [opt.get("name") for opt in options]
            }
            state["phase"] = ConversationPhase.BENEFICIARY_SELECTION
            return state
        
        # Valid selection - check if from_account was specified
        from_account = pending.get("from_account")
        
        if from_account is None:
            # from_account not specified - move to account selection
            state["pending_transfer"]["to_beneficiary"] = selected
            state["phase"] = ConversationPhase.ACCOUNT_SELECTION
            state["selection_attempts"] = 0
            state["result"] = {
                STATUS_SUCCESS: True,
                "message": f"Selected {selected.get('name')}. Which account do you want to send from? (Savings/Current)",
                "options": ["Savings", "Current"]
            }
            logger.info("Beneficiary selected: %s, from_account not specified, moving to ACCOUNT_SELECTION", selected.get("name"))
            return state
        else:
            # from_account was specified - skip to transfer summary
            summary = {
                "amount": pending.get("amount"),
                "from_account": from_account,
                "to_beneficiary": selected.get("name"),
                "to_account": selected.get("account_number"),
                "to_ifsc": selected.get("ifsc"),
            }
            
            state["pending_transfer"]["to_beneficiary"] = selected
            state["pending_transfer"]["summary"] = summary
            state["phase"] = ConversationPhase.TRANSFER_SUMMARY
            state["selection_attempts"] = 0
            state["result"] = {
                STATUS_SUCCESS: True,
                "message": f"Transfer Summary:\n"
                          f"Amount: ₹{summary['amount']}\n"
                          f"From: {from_account} Account\n"
                          f"To: {selected.get('name')}\n"
                          f"Account: {selected.get('account_number')}\n"
                          f"\nConfirm? (yes/no)",
                "summary": summary
            }
            logger.info("Beneficiary selected: %s, from_account specified, moving to TRANSFER_SUMMARY", selected.get("name"))
            return state
    
    # ========================================================================
    # ACCOUNT SELECTION PHASE
    # ========================================================================
    
    @staticmethod
    def handle_account_selection(state: Dict[str, Any]) -> Dict[str, Any]:
        """
        Handle account selection (Savings or Current).
        
        User input: "Savings" or "Current" (case-insensitive)
        """
        StateManager.ensure_defaults(state)
        user_input = (state.get("user_input") or "").strip()
        pending = state.get("pending_transfer", {})
        
        # Normalize account selection (case-insensitive)
        user_account = user_input.lower()
        if user_account not in ["savings", "current"]:
            attempts = state.get("selection_attempts", 0) + 1
            state["selection_attempts"] = attempts
            
            if attempts >= MAX_INVALID_SELECTION_ATTEMPTS:
                logger.warning("Max account selection attempts exceeded for user %s", state.get("user_id"))
                state["result"] = {
                    STATUS_ERROR: True,
                    "message": "Too many invalid selections. Transfer cancelled."
                }
                state["phase"] = ConversationPhase.NORMAL
                state["pending_transfer"] = None
                state["intent"] = IntentType.UNKNOWN
                return state
            
            remaining = MAX_INVALID_SELECTION_ATTEMPTS - attempts
            state["result"] = {
                STATUS_INVALID_SELECTION: True,
                "message": f"Invalid account type. {remaining} attempt(s) remaining. Please select: Savings or Current"
            }
            state["phase"] = ConversationPhase.ACCOUNT_SELECTION
            return state
        
        # Valid selection - move to transfer summary
        to_beneficiary = pending.get("to_beneficiary", {})
        amount = pending.get("amount")
        
        summary = {
            "amount": amount,
            "from_account": user_account.capitalize(),
            "to_beneficiary": to_beneficiary.get("name"),
            "to_account": to_beneficiary.get("account_number"),
            "to_ifsc": to_beneficiary.get("ifsc"),
        }
        
        state["pending_transfer"]["from_account"] = user_account.capitalize()
        state["pending_transfer"]["summary"] = summary
        state["phase"] = ConversationPhase.TRANSFER_SUMMARY
        state["selection_attempts"] = 0
        state["result"] = {
            STATUS_SUCCESS: True,
            "message": f"Transfer Summary:\n"
                      f"Amount: ₹{amount}\n"
                      f"From: {user_account.capitalize()} Account\n"
                      f"To: {to_beneficiary.get('name')}\n"
                      f"Account: {to_beneficiary.get('account_number')}\n"
                      f"\nConfirm? (yes/no)",
            "summary": summary
        }
        logger.info("Account selected: %s, moving to TRANSFER_SUMMARY", user_account.capitalize())
        return state
    
    # ========================================================================
    # TRANSFER SUMMARY PHASE
    # ========================================================================
    
    @staticmethod
    def handle_transfer_summary_confirmation(state: Dict[str, Any]) -> Dict[str, Any]:
        """
        Handle confirmation of transfer summary.
        
        User input: "yes" or "no" (case-insensitive)
        """
        StateManager.ensure_defaults(state)
        user_input = (state.get("user_input") or "").strip().lower()
        
        if user_input not in ("yes", "no"):
            attempts = state.get("selection_attempts", 0) + 1
            state["selection_attempts"] = attempts
            
            if attempts >= MAX_INVALID_SELECTION_ATTEMPTS:
                logger.warning("Max confirmation attempts exceeded for user %s", state.get("user_id"))
                state["result"] = {
                    STATUS_ERROR: True,
                    "message": "Too many invalid responses. Transfer cancelled."
                }
                state["phase"] = ConversationPhase.NORMAL
                state["pending_transfer"] = None
                state["intent"] = IntentType.UNKNOWN
                return state
            
            remaining = MAX_INVALID_SELECTION_ATTEMPTS - attempts
            state["result"] = {
                STATUS_INVALID_SELECTION: True,
                "message": f"Please confirm with 'yes' or 'no'. {remaining} attempt(s) remaining."
            }
            state["phase"] = ConversationPhase.TRANSFER_SUMMARY
            return state
        
        if user_input == "no":
            # User cancelled
            state["result"] = {
                STATUS_FAILED: True,
                "message": "Transfer cancelled."
            }
            state["phase"] = ConversationPhase.NORMAL
            state["pending_transfer"] = None
            state["intent"] = IntentType.UNKNOWN
            return state
        
        # User confirmed - move to OTP phase
        user_id = state.get("user_id", "0")
        try:
            otp_code = transfer_tool.generate_otp(int(user_id))
            
            state["phase"] = ConversationPhase.OTP
            state["intent"] = IntentType.OTP
            state["otp_attempts"] = 0
            state["result"] = {
                STATUS_OTP_REQUIRED: True,
                "message": f"OTP sent to your registered mobile. Please enter OTP to confirm transfer of ₹{state['pending_transfer'].get('amount')}"
            }
            logger.info("Transfer confirmed, OTP sent, moving to OTP phase")
            return state
        except Exception as e:
            logger.exception("OTP generation failed")
            state["result"] = {
                STATUS_ERROR: True,
                "message": f"Failed to send OTP: {str(e)}"
            }
            state["phase"] = ConversationPhase.NORMAL
            state["pending_transfer"] = None
            return state
    
    # ========================================================================
    # OTP VALIDATION PHASE
    # ========================================================================
    
    @staticmethod
    def validate_otp(state: Dict[str, Any]) -> Dict[str, Any]:
        """
        Validate OTP input and perform transfer.
        """
        StateManager.ensure_defaults(state)
        
        if StateManager.get_phase(state) != ConversationPhase.OTP:
            state["result"] = {
                STATUS_ERROR: True,
                "message": "No pending OTP validation."
            }
            return state
        
        user_id = state.get("user_id", "0")
        otp = (state.get("user_input") or "").strip()
        pending_transfer = state.get("pending_transfer") or {}
        
        if not pending_transfer:
            state["result"] = {
                STATUS_ERROR: True,
                "message": "Transfer details not found. Please restart."
            }
            state["phase"] = ConversationPhase.NORMAL
            state["pending_transfer"] = None
            state["intent"] = IntentType.UNKNOWN
            return state
        
        try:
            is_valid, attempts_left = transfer_tool.validate_otp(int(user_id), otp)
            
            if not is_valid:
                state["otp_attempts"] = state.get("otp_attempts", 0) + 1
                
                if state["otp_attempts"] >= MAX_OTP_ATTEMPTS:
                    logger.warning("Max OTP attempts exceeded for user %s", user_id)
                    state["result"] = {
                        STATUS_FAILED: True,
                        "message": "Maximum OTP attempts exceeded. Transfer cancelled."
                    }
                    state["phase"] = ConversationPhase.NORMAL
                    state["pending_transfer"] = None
                    state["otp_attempts"] = 0
                    state["intent"] = IntentType.UNKNOWN
                    return state
                
                remaining = MAX_OTP_ATTEMPTS - state["otp_attempts"]
                state["result"] = {
                    STATUS_OTP_INCORRECT: True,
                    "message": f"Invalid OTP. {remaining} attempt(s) remaining."
                }
                state["phase"] = ConversationPhase.OTP
                state["intent"] = IntentType.OTP
                return state
            
            # OTP valid - perform transfer
            to_beneficiary = pending_transfer.get("to_beneficiary", {})
            amount = pending_transfer.get("amount")
            
            transfer_result = transfer_tool.perform_transfer(
                int(user_id),
                to_beneficiary,
                amount
            )
            
            # Build recommendation
            recommendation = (
                f"You sent ₹{amount} to {to_beneficiary.get('name')} today. "
                f"Would you like to make this a recurring monthly transfer?"
            )
            
            state["result"] = {
                STATUS_SUCCESS: True,
                "message": f"Transfer of ₹{amount} to {to_beneficiary.get('name')} successful!",
                "amount": amount,
                "beneficiary": to_beneficiary.get("name"),
                "account": to_beneficiary.get("account_number"),
                "ifsc": to_beneficiary.get("ifsc"),
                "timestamp": transfer_result.get("timestamp"),
                "recommendation": recommendation,
                "recommendation_id": f"rec-{user_id}-{to_beneficiary.get('id', 'unknown')}"
            }
            
            # Move to confirmation phase for recurring recommendation
            state["phase"] = ConversationPhase.CONFIRMATION
            state["intent"] = IntentType.CONFIRMATION
            state["confirmation_context"] = {
                "action": "confirm_recurring_transfer",
                "details": state["result"],
            }
            state["otp_attempts"] = 0
            state["pending_transfer"] = None
            
            logger.info("OTP validated, transfer successful, moving to CONFIRMATION")
            return state
        
        except Exception as e:
            logger.exception("OTP validation failed")
            state["result"] = {
                STATUS_ERROR: True,
                "message": f"OTP validation error: {str(e)}"
            }
            state["phase"] = ConversationPhase.NORMAL
            state["pending_transfer"] = None
            state["otp_attempts"] = 0
            return state
    
    # ========================================================================
    # CONFIRMATION PHASE (Recurring Transfer)
    # ========================================================================
    
    @staticmethod
    def confirm_recurring_transfer(state: Dict[str, Any]) -> Dict[str, Any]:
        """
        Handle recommendation confirmation (yes/no for recurring transfer).
        """
        StateManager.ensure_defaults(state)
        
        if StateManager.get_phase(state) != ConversationPhase.CONFIRMATION:
            state["result"] = "No pending confirmation."
            return state
        
        user_input = IntentRouter.normalize_confirmation_input(state.get("user_input"))
        state["user_input"] = user_input
        
        ctx = state.get("confirmation_context") or {}
        details = ctx.get("details", {})
        
        if user_input == "yes":
            state["result"] = {
                STATUS_SUCCESS: True,
                "message": "Great! Let's set up your recurring transfer. Please provide frequency and start date.",
                "action": "show_transfer_form",
                "recommendation_id": details.get("recommendation_id"),
                "beneficiary_id": details.get("account"),
            }
        else:
            state["result"] = {
                STATUS_SUCCESS: True,
                "message": "Recurring transfer not set up. Transfer completed successfully!",
                "action": "close_transfer_form"
            }
        
        state["phase"] = ConversationPhase.NORMAL
        state["confirmation_context"] = None
        state["intent"] = IntentType.UNKNOWN
        
        logger.info("Recurring transfer decision made, returning to NORMAL")
        return state
