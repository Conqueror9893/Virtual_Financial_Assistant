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
1. Amount can appear as INR100, Rs 100, $100, 100 or even just a number - extract numeric value only.
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


INTENT_CLASSIFICATION_PROMPT = """Classify the following user query into exactly one of these categories:
- spend: User wants to analyze or view past spending or transaction insights.
- faq: User is asking a question about banking procedures, products, policies, or general information.
- offers: User is inquiring about current offers, promotions, deals, or discounts from the bank.
- transfer: User wants to transfer money or asks about moving funds between accounts.
- unknown: The intention of the query does not match any category above.

Query: "{user_input}"

Return ONLY the single-word category label from: spend, faq, offers, transfer, unknown. No other text.
"""

FAQ_ANSWERING_PROMPT = """
    You are a helpful and concise banking FAQ assistant for the bank "XAC Bank".
    Customer Support number is 1800-1888.
    The user asked: "{query}".
    Based strictly on the information provided below, give a clear and direct answer.
    Do NOT mention documents, sources, file names, or any references. Do NOT provide document names or links.
    Only provide the factual answer.

    Context:
    {context}

    Return only the answer, without repeating the question.
    """
