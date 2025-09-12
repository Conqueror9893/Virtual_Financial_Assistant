# langgraph_flow/nodes/output_formatter.py
def format_spend_response(insight: dict) -> dict:
    details = insight.get("details", {})
    result = insight.get("result", {})

    if "total_spend_category" in result:
        text = f"You spent ₹{result['total_spend_category']:.2f} on {details['category']}."
        if result.get("top_merchants"):
            merchants = ", ".join([f"{m['genify_clean_description']} (₹{m['amount']:.2f})"
                                   for m in result["top_merchants"]])
            text += f" Top merchants: {merchants}"
    elif "total_spend_merchant" in result:
        text = f"You spent ₹{result['total_spend_merchant']:.2f} at {details['merchant']}."
    else:
        text = f"Your total spend was ₹{result['total_spend']:.2f}."
        if result.get("breakdown"):
            breakdown = ", ".join([f"{b['genify_category']}: ₹{b['amount']:.2f}"
                                   for b in result["breakdown"]])
            text += f" Breakdown: {breakdown}"

    return {"text": text, "raw": insight}