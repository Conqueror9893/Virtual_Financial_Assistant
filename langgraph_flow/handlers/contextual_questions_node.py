# langgraph_flow/nodes/contextual_questions_node.py
from typing import Dict, Any, List
from utils.llm_connector import run_llm
from utils.logger import get_logger

logger = get_logger("ContextualQuestionsNode")


def generate_static_suggestions(response_text: str) -> List[str]:
    """
    Fallback static suggestions based on keywords in the response.
    """
    suggestions = []
    text = response_text.lower()
    
    if "spent" in text or "spending" in text:
        suggestions = [
            "Show me last month's spend",
            "Breakdown by category",
            "Top merchants I spent at"
        ]
    elif "transfer" in text:
        suggestions = [
            "Check transfer status",
            "Initiate another transfer",
            "Cancel my last transfer"
        ]
    elif "balance" in text:
        suggestions = [
            "Show account balance history",
            "Compare balance month over month",
            "Check minimum balance requirement"
        ]
    else:
        suggestions = [
            "Show me offers",
            "FAQ related to my account",
            "Help me with spending insights"
        ]
    
    return suggestions


def handle_contextual_questions_node(user_id: int, last_query: str, last_response: str, state: Dict[str, Any] = None) -> Dict[str, Any]:
    """
    Generates contextual questions for the user to select after any query response.

    Returns:
        Dict with keys:
        - 'contextual_questions': List[str]
        - 'raw': Original inputs for debugging/logging
    """
    logger.info("Generating contextual questions for user_id=%s", user_id)

    # Build prompt for LLM
    prompt = f"""
You are a helpful banking assistant.

The user asked: "{last_query}"
The last response you gave: "{last_response}"

Your task:
- Suggest 3-5 concise follow-up questions the user might want to ask next.
- Questions should be relevant to the previous response and actionable.
- Format as a JSON array of strings only.
- Keep tone friendly and professional.
"""

    contextual_questions: List[str] = []

    try:
        llm_output = run_llm(prompt)
        if llm_output:
            # Attempt to parse JSON array from LLM output
            import json
            try:
                parsed = json.loads(llm_output)
                if isinstance(parsed, list) and all(isinstance(q, str) for q in parsed):
                    contextual_questions = parsed
            except json.JSONDecodeError:
                logger.warning("LLM output is not valid JSON. Falling back to static suggestions.")
                contextual_questions = generate_static_suggestions(last_response)
        else:
            contextual_questions = generate_static_suggestions(last_response)
    except Exception as e:
        logger.exception("Failed to generate LLM contextual questions")
        contextual_questions = generate_static_suggestions(last_response)

    logger.info("Contextual questions generated: %s", contextual_questions)

    return {
        "contextual_questions": contextual_questions,
        "raw": {
            "user_id": user_id,
            "last_query": last_query,
            "last_response": last_response,
            "state": state
        }
    }


# Example usage:
if __name__ == "__main__":
    result = handle_contextual_questions_node(
        user_id=1,
        last_query="Show me my coffee spending last month",
        last_response="You spent ₹7.58 in total at Coffee shops."
    )
    print(result)
