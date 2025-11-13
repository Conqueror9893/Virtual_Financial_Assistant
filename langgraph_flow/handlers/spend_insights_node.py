# langgraph_flow/nodes/spend_insights_node.py
import difflib
import re
import json
from dateutil.relativedelta import relativedelta
from utils.llm_connector import run_llm
from tools import spend_insights
from utils.logger import get_logger
from datetime import datetime, date, timedelta
from zoneinfo import ZoneInfo

logger = get_logger("SpendInsightsNode")

import difflib
import re

# Canonical categories
CATEGORIES = [
    "Other services",
    "Unknown expense",
    "Food delivery",
    "Beauty and care",
    "Parking",
    "Coffeeshop",
    "Restaurant",
    "Other food",
    "Hotel and accommodation",
    "Fuel, e-charging",
    "Non-profit organization",
    "Vehicle purchase, maintenance",
    "Ride-hailing, taxi",
    "Money transfers between accounts",
    "Electronics",
    "Money transfers to others",
    "Doctors and hospital",
    "Tobacco and alcohol",
    "Financial services",
    "Supermarket",
    "Salary",
    "Home improvement",
    "Other leisure",
    "Telephone and internet",
    "Other shopping",
    "Pharmacy",
    "Government",
    "Government fees",
    "Opera house",
    "Sport activities",
    "Nightlife",
    "Clothes",
    "Children",
    "Plane",
    "Education",
    "Utilities",
    "Furniture",
    "Department stores",
    "Arts and culture",
    "Dhahran Saudi Arabia",
    "Cash withdrawals",
    "Online services",
    "Shooting range",
    "Software and apps",
    "Other travel expenses",
    "Hobbies",
]

# ✅ Add keyword alias map for semantic hints
CATEGORY_ALIASES = {
    # Food & beverage
    "coffee": "Coffeeshop",
    "cafe": "Coffeeshop",
    "espresso": "Coffeeshop",
    "tea": "Coffeeshop",
    "restaurant": "Restaurant",
    "dining": "Restaurant",
    "food": "Restaurant",
    "lunch": "Restaurant",
    "dinner": "Restaurant",
    "breakfast": "Restaurant",
    "delivery": "Food delivery",
    "zomato": "Food delivery",
    "swiggy": "Food delivery",
    # Groceries
    "supermarket": "Supermarket",
    "grocery": "Supermarket",
    "groceries": "Supermarket",
    # Travel
    "taxi": "Ride-hailing, taxi",
    "uber": "Ride-hailing, taxi",
    "ola": "Ride-hailing, taxi",
    "flight": "Plane",
    "airline": "Plane",
    # Fuel
    "fuel": "Fuel, e-charging",
    "gas": "Fuel, e-charging",
    "petrol": "Fuel, e-charging",
    "diesel": "Fuel, e-charging",
    # Health
    "medicine": "Pharmacy",
    "doctor": "Doctors and hospital",
    "hospital": "Doctors and hospital",
    # Misc
    "salary": "Salary",
    "transfer": "Money transfers to others",
    "shopping": "Other shopping",
}


def match_category(user_category: str) -> str | None:
    if not user_category:
        return None

    # Normalize input
    user_category = user_category.lower().strip()
    user_category = re.sub(r"[^a-z\s]", "", user_category)

    # 1️⃣ Check for direct alias keyword match
    for keyword, category in CATEGORY_ALIASES.items():
        if keyword in user_category:
            return category

    # 2️⃣ Fallback to fuzzy string similarity
    matches = difflib.get_close_matches(user_category, CATEGORIES, n=1, cutoff=0.5)
    if matches:
        return matches[0]

    # 3️⃣ No match found
    return None


# Enhanced date parser
NUM_WORDS = {
    "one": 1,
    "two": 2,
    "three": 3,
    "four": 4,
    "five": 5,
    "six": 6,
    "seven": 7,
    "eight": 8,
    "nine": 9,
    "ten": 10,
    "eleven": 11,
    "twelve": 12,
}


def parse_relative_dates(query: str):
    q = (query or "").lower()
    today = datetime.now(ZoneInfo("Asia/Kolkata")).date()

    # "past N days/months/years"
    m = re.search(r"(past|last)\s+(\d+|\w+)\s+(day|days|month|months|year|years)\b", q)
    if m:
        num = m.group(2)
        unit = m.group(3)
        if num.isdigit():
            n = int(num)
        else:
            n = NUM_WORDS.get(num, 0)
        if n < 1:
            return None, None
        if "day" in unit:
            start = today - timedelta(days=n - 1)
        elif "month" in unit:
            start = today.replace(day=1) - relativedelta(months=n - 1)
        elif "year" in unit:
            start = today.replace(month=1, day=1) - relativedelta(years=n - 1)
        return start.isoformat(), today.isoformat()

    return None, None


def compute_date_range_from_query(user_query: str):
    start, end = parse_relative_dates(user_query)
    if start and end:
        return start, end
    # existing phrases
    q = (user_query or "").lower()
    today = datetime.now(ZoneInfo("Asia/Kolkata")).date()
    # this month
    if re.search(r"\bthis month\b", q):
        start = today.replace(day=1)
        return start.isoformat(), today.isoformat()
    # last month
    if re.search(r"\blast month\b", q):
        first_of_this = today.replace(day=1)
        last_of_prev = first_of_this - timedelta(days=1)
        start = last_of_prev.replace(day=1)
        end = last_of_prev
        return start.isoformat(), end.isoformat()
    # last N days
    m = re.search(r"\blast\s+(\d{1,3})\s+days\b", q)
    if m:
        n = int(m.group(1))
        start = today - timedelta(days=n - 1)
        return start.isoformat(), today.isoformat()
    # year-to-date / this year
    if re.search(r"\b(year to date|ytd|this year)\b", q):
        start = date(today.year, 1, 1)
        return start.isoformat(), today.isoformat()
    return None, None


# Update handle_spend_insight to use fuzzy category and top merchants
def handle_spend_insight(user_id: int, query: str) -> dict:
    details = extract_spend_query_details(query)
    user_category = details.get("category")
    canonical_category = match_category(user_category)
    details["category"] = canonical_category

    start_date = details.get("start_date")
    end_date = details.get("end_date")
    merchant = details.get("merchant")

    logger.info("Parsed spend query: %s", details)
    # Fetch data based on parsed details
    result = {}
    if canonical_category:
        result["total_spend_category"] = spend_insights.get_category_spend(
            canonical_category, start_date, end_date
        )
        result["top_merchants"] = spend_insights.get_top_merchants(
            canonical_category, start_date, end_date
        )[:3]
    elif merchant:
        txns = spend_insights.filter_transactions(
            start_date, end_date, merchant=merchant
        )
        result["total_spend_merchant"] = txns["amount"].sum()
    else:
        result["total_spend"] = spend_insights.get_total_spend(start_date, end_date)
        result["breakdown"] = spend_insights.get_spend_breakdown(start_date, end_date)

    # 🧠 New: Build structured analysis
    structured = _build_structured_spend_summary(query, details, result)

    return {
        "query": query,
        "details": details,
        "result": result,
        "structured_summary": structured,
    }


def _build_structured_spend_summary(
    user_query: str, details: dict, result: dict
) -> dict:
    """Create structured summary for UI (chart + merchants + trends)."""
    today = datetime.now(ZoneInfo("Asia/Kolkata")).date()
    start = details.get("start_date")
    end = details.get("end_date")

    # Compute date title (like "September & October 2025")
    if start and end:
        start_dt = datetime.fromisoformat(start).date()
        end_dt = datetime.fromisoformat(end).date()

        if start_dt.year == end_dt.year:
            if start_dt.month != end_dt.month:
                title = f"Spending summary - {start_dt.strftime('%B')} to {end_dt.strftime('%B %Y')}"
            else:
                title = f"Spending summary - {end_dt.strftime('%B %Y')}"
        else:
            title = f"Spending summary - {start_dt.strftime('%b %Y')} to {end_dt.strftime('%b %Y')}"
    else:
        title = f"Spending summary - {today.strftime('%B %Y')}"

    # Compute total
    total = (
        result.get("total_spend_category")
        or result.get("total_spend_merchant")
        or result.get("total_spend")
    )
    total_fmt = _format_amount(total) if total else "N/A"

    # Merchant breakdown
    merchants = result.get("top_merchants", [])
    breakdown = [
        {
            "merchant": m["genify_clean_description"],
            "amount": _format_amount(m["TXN_AMOUNT_LCY"]),
        }
        for m in merchants
    ]

    # Chart data for frontend visualization
    chart_data = [
        {"label": m["genify_clean_description"], "value": float(m["TXN_AMOUNT_LCY"])}
        for m in merchants
    ]

    # Trend insights (simple heuristic now; can be extended with AI later)
    trend_insights = []
    if total:
        trend_insights.append(f"Spent {total_fmt} in total.")
    if merchants:
        top_merchant = merchants[0]["genify_clean_description"]
        trend_insights.append(f"Most spent in {top_merchant}.")
    if len(merchants) > 1:
        trend_insights.append(
            f"Other top merchants: {', '.join([m['genify_clean_description'] for m in merchants[1:]])}."
        )
    trend_insights.append("Would you like the full breakdown?")

    return {
        "summary_title": title,
        "total_spent": total_fmt,
        "breakdown_merchants": breakdown,
        "trend_insights": trend_insights,
        "chart_data": chart_data,
    }


def extract_spend_query_details(user_query: str) -> dict:
    """
    Use LLM to extract category, time range, merchant.
    Post-process relative-date hints locally for reliability.
    """
    today_str = datetime.now(ZoneInfo("Asia/Kolkata")).strftime("%Y-%m-%d")
    prompt = f"""
Extract spend analytics query details from the user query.
Assume today's date is {today_str}.
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

The currency is USD and return the amounts in USD.

Query: "{user_query}"
"""
    response = run_llm(prompt)
    logger.info("LLM spend query extraction response: %s", response)
    try:
        # 🩹 Clean common LLM artifacts
        cleaned = response.strip()

        # Remove wrapping text like "Output JSON:" or code block fences
        cleaned = re.sub(
            r"^[^\{]*\{", "{", cleaned, count=1
        )  # remove text before first '{'
        cleaned = re.sub(
            r"\}[^}]*$", "}", cleaned, count=1
        )  # remove text after last '}'
        cleaned = cleaned.strip("` \n")

        details = json.loads(cleaned)
    except Exception as e:
        logger.error("Failed to parse LLM response: %s | Raw: %r", str(e), response)
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
        return f"$ {float(amount):,.2f}"
    except Exception:
        return str(amount)


def _summarize_spend_for_chat(user_query: str, details: dict, result: dict) -> str:
    """
    Ask the LLM to produce a short chat-friendly summary (1-3 sentences).
    If LLM fails, fall back to a small programmatic summary.
    Includes top 3 merchants if category is specified.
    """
    payload = {
        "query": user_query,
        "details": details,
        "result_keys": list(result.keys()),
    }

    prompt = f"""
You are a concise financial assistant. The user asked: "{user_query}"

We have this spend analysis result (JSON keys: {', '.join(result.keys())}).
Provide a short chat-friendly reply (maximum 2-3 sentences, one paragraph) that:
  - States the total spend (if available).
  - Lists the top 2-3 categories or top 3 merchants if the query is for a category.
  - Ends with a short CTA like "Would you like the full breakdown?" or "Want more detail?"

Return ONLY the short reply (plain text). Do not return JSON or internal debug info.
The currency is USD and return the amount ONLY in USD. 
Do not start with "As an AI language model" or greetings like "Hi" or "Hello".

Here is the analysis JSON:
{json.dumps(result, indent=2)}
"""
    try:
        out = run_llm(prompt)
        if out and out.strip():
            return out.strip()
    except Exception:
        logger.exception("LLM summarization failed")

    # Fallback programmatic summary
    total = (
        result.get("total_spend")
        or result.get("total_spend_category")
        or result.get("total_spend_merchant")
    )
    breakdown = result.get("breakdown", {}) or {}
    top_merchants = result.get("top_merchants", [])

    total_text = _format_amount(total) if total else None
    top_text = None

    if details.get("category") and top_merchants:
        top_text = "; ".join(
            [f"{m['merchant']} - {_format_amount(m['amount'])}" for m in top_merchants]
        )
    elif breakdown:
        top = sorted(breakdown.items(), key=lambda kv: kv[1], reverse=True)[:3]
        top_text = "; ".join([f"{k} - {_format_amount(v)}" for k, v in top])

    parts = []
    if total_text:
        parts.append(f"You spent {total_text}.")
    else:
        parts.append("I couldn't compute total spend from the data.")

    if top_text:
        if details.get("category"):
            parts.append(f"Top merchants for {details['category']}: {top_text}.")
        else:
            parts.append(f"Top categories: {top_text}.")

    parts.append("Would you like the full breakdown?")

    return " ".join(parts)
