# langgraph_flow/nodes/spend_insights_node.py
import datetime
import json
import re
from datetime import datetime, date, timedelta
from zoneinfo import ZoneInfo

from utils.llm_connector import run_llm
from tools import spend_insights
from utils.logger import get_logger

logger = get_logger("SpendInsightsNode")


def compute_date_range_from_query(user_query: str):
    """
    Compute sensible start_date/end_date for common relative phrases.
    Returns (start_iso, end_iso) or (None, None) if no match.
    Uses Asia/Kolkata timezone for "today".
    """
    q = (user_query or "").lower()
    today = datetime.now(ZoneInfo("Asia/Kolkata")).date()

    # this month -> first of current month .. today
    if re.search(r"\bthis month\b", q):
        start = today.replace(day=1)
        return start.isoformat(), today.isoformat()

    # last month -> first..last day of previous month
    if re.search(r"\blast month\b", q):
        first_of_this = today.replace(day=1)
        last_of_prev = first_of_this - timedelta(days=1)
        start = last_of_prev.replace(day=1)
        end = last_of_prev
        return start.isoformat(), end.isoformat()

    # last N days -> inclusive window ending today
    m = re.search(r"\blast\s+(\d{1,3})\s+days\b", q)
    if m:
        n = int(m.group(1))
        if n >= 1:
            start = today - timedelta(days=n - 1)
            return start.isoformat(), today.isoformat()

    # year-to-date / ytd / this year -> Jan 1 .. today
    if re.search(r"\b(year to date|ytd|this year)\b", q):
        start = date(today.year, 1, 1)
        return start.isoformat(), today.isoformat()

    # fallback
    return None, None


def extract_spend_query_details(user_query: str) -> dict:
    """
    Use LLM to extract category, time range, merchant.
    Post-process relative-date hints locally for reliability.
    """
    prompt = f"""
Extract spend analytics query details from the user query.
Return a JSON object with keys:
  - category (string or null)
  - start_date (YYYY-MM-DD or null)   # If the user gave explicit dates put them here; otherwise null.
  - end_date (YYYY-MM-DD or null)
  - merchant (string or null)

Examples:
  Input: "How much did I spend in groceries in August 2025?"
  Output JSON: {{ "category": "Groceries", "start_date": "2025-08-01", "end_date": "2025-08-31", "merchant": null }}

  Input: "Show me my spends this month"
  Output JSON: {{ "category": null, "start_date": null, "end_date": null, "merchant": null }}
    # For relative phrases like "this month" we'll compute concrete dates locally.

The currency is INR and return the amounts in INR.

Query: "{user_query}"
"""
    response = run_llm(prompt)
    logger.info("LLM spend query extraction response: %s", response)
    try:
        details = json.loads(response)
    except Exception as e:
        logger.error("Failed to parse LLM response: %s", str(e))
        details = {}

    # If user used a relative phrase override the dates with deterministic logic
    try:
        start_date, end_date = compute_date_range_from_query(user_query)
        if start_date and end_date:
            # always prefer computed dates for explicit relative phrases
            details["start_date"] = start_date
            details["end_date"] = end_date
        else:
            # If no relative phrase and LLM returned explicit dates, keep them.
            # If LLM returned 'All' or invalid values, clear them.
            sd = details.get("start_date")
            ed = details.get("end_date")
            if sd in ("All", "", "null"):
                details["start_date"] = None
            if ed in ("All", "", "null"):
                details["end_date"] = None
    except Exception:
        logger.exception("Error while normalizing dates")

    return details


def _format_amount(amount):
    try:
        return f"Rs{float(amount):,.2f}"
    except Exception:
        return str(amount)


def _summarize_spend_for_chat(user_query: str, details: dict, result: dict) -> str:
    """
    Ask the LLM to produce a short chat-friendly summary (1-3 sentences).
    If LLM fails, fall back to a small programmatic summary.
    """
    # Prepare a compact payload for the LLM
    payload = {
        "query": user_query,
        "details": details,
        "result_keys": list(result.keys()),
    }

    # Build a tight prompt that asks for a very short response
    prompt = f"""
You are a concise financial assistant. The user asked: "{user_query}"

We have this spend analysis result (JSON keys: {', '.join(result.keys())}).
Provide a short chat-friendly reply (maximum 2-3 sentences, one paragraph) that:
  - States the total spend (if available).
  - Lists the top 2-3 categories with amounts (comma-separated).
  - Ends with a short CTA like "Would you like the full breakdown?" or "Want more detail?"

Return ONLY the short reply (plain text). Do not return JSON or internal debug info.
The currency is INR and return the amount ONLY in INR. 
DO not start the response with "As an AI language model" or with greetings like "Hi" or "Hello".
Here is the analysis JSON (use it to craft the summary):
{json.dumps(result, indent=2)}
"""
    try:
        out = run_llm(prompt)
        if out and out.strip():
            # safety: strip very long responses
            return out.strip()
    except Exception:
        logger.exception("LLM summarization failed")

    # Fallback: programmatic summary
    total = result.get("total_spend") or result.get("total_spend_category")
    breakdown = result.get("breakdown", {}) or {}
    if total:
        total_text = _format_amount(total)
    else:
        total_text = None

    top = sorted(breakdown.items(), key=lambda kv: kv[1], reverse=True)[:3]
    top_text = (
        "; ".join([f"{k} - {_format_amount(v)}" for k, v in top]) if top else None
    )

    parts = []
    if total_text:
        parts.append(f"You spent {total_text}.")
    else:
        parts.append("I couldn't compute total spend from the data.")

    if top_text:
        parts.append(f"Top categories: {top_text}.")
    parts.append("Would you like the full breakdown?")

    return " ".join(parts)


def handle_spend_insight(user_id: int, query: str) -> dict:
    """
    Main entry for spend insights.
    Returns a dict containing:
      - query
      - details (extracted)
      - result (raw numeric results / breakdown)
      - chat_message (short conversational text suitable for chat UI)
    """
    details = extract_spend_query_details(query)
    category = details.get("category")
    start_date = details.get("start_date")
    end_date = details.get("end_date")
    merchant = details.get("merchant")

    logger.info("Parsed spend query: %s", details)

    result = {}
    if category:
        result["total_spend_category"] = spend_insights.get_category_spend(
            category, start_date, end_date
        )
        result["top_merchants"] = spend_insights.get_top_merchants(
            category, start_date, end_date
        )
    elif merchant:
        txns = spend_insights.filter_transactions(
            start_date, end_date, merchant=merchant
        )
        result["total_spend_merchant"] = txns["amount"].sum()
    else:
        result["total_spend"] = spend_insights.get_total_spend(start_date, end_date)
        result["breakdown"] = spend_insights.get_spend_breakdown(start_date, end_date)

    # create a compact chat-friendly summary using LLM (with a safe fallback)
    chat_message = _summarize_spend_for_chat(query, details, result)

    return {
        "query": query,
        "details": details,
        "result": result,
        "chat_message": chat_message,
    }
