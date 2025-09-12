# langgraph_flow/nodes/spend_insights_node.py
import json
from utils.llm_connector import run_llm
from tools import spend_insights
from utils.logger import get_logger

logger = get_logger("SpendInsightsNode")

def extract_spend_query_details(user_query: str) -> dict:
    """
    Use LLM to extract category, time range, merchant.
    """
    prompt = f"""
    Extract spend analytics query details from the user query:
    Query: "{user_query}"

    Return JSON with keys:
      - category (string or null)
      - start_date (YYYY-MM-DD or null)
      - end_date (YYYY-MM-DD or null)
      - merchant (string or null)
    """
    response = run_llm(prompt)
    try:
        return json.loads(response)
    except Exception as e:
        logger.error("Failed to parse LLM response: %s", str(e))
        return {}

def handle_spend_insight(user_id: int, query: str) -> dict:
    """
    Main entry for spend insights.
    """
    details = extract_spend_query_details(query)
    category = details.get("category")
    start_date = details.get("start_date")
    end_date = details.get("end_date")
    merchant = details.get("merchant")

    logger.info("Parsed spend query: %s", details)

    result = {}
    if category:
        result["total_spend_category"] = spend_insights.get_category_spend(category, start_date, end_date)
        result["top_merchants"] = spend_insights.get_top_merchants(category, start_date, end_date)
    elif merchant:
        txns = spend_insights.filter_transactions(start_date, end_date, merchant=merchant)
        result["total_spend_merchant"] = txns["amount"].sum()
    else:
        result["total_spend"] = spend_insights.get_total_spend(start_date, end_date)
        result["breakdown"] = spend_insights.get_spend_breakdown(start_date, end_date)

    return {
        "query": query,
        "details": details,
        "result": result
    }
