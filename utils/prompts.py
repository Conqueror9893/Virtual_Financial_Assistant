# utils/prompts.py
def extraction_prompt(query: str) -> str:
    return f"""
You are a precise information extraction engine.
Extract structured transfer details from the following user query:

"{query}"

Return ONLY a valid JSON object (no text before or after) with exactly these keys:
- amount: number or null
- to_beneficiary: string or null
- from_account: "Savings", "Current", or null
- frequency: "one-time", "recurring", or null

Rules:
1. Amount can appear as ₹100, Rs 100, $100, or just 100 - extract numeric value only.
2. to_beneficiary is the recipient name/nickname (e.g., "mom", "john").
3. from_account: 
   - If the text mentions "savings", return "Savings".
   - If it mentions "current", return "Current".
   - Otherwise return null.
4. frequency:
   - If the text has "monthly", "every month", or "recurring", return "recurring".
   - Otherwise return "one-time".
5. Respond ONLY with a valid JSON object - no lists, no explanations, no labels.

Example format (single object, not a list):

{{
  "amount": 200,
  "to_beneficiary": "amy",
  "from_account": "Current",
  "frequency": "recurring"
}}
"""
