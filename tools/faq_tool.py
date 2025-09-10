import fitz  # PyMuPDF
import re
from utils.logger import get_logger

logger = get_logger("FAQTool")

FAQ_PATH = "data/faqs.pdf"

def load_faqs():
    """
    Parse PDF and extract Q&A pairs.
    Assumes questions end with '?' and next line is answer.
    """
    faqs = []
    try:
        doc = fitz.open(FAQ_PATH)
        text = ""
        for page in doc:
            text += page.get_text("text") + "\n"
        doc.close()

        lines = [line.strip() for line in text.splitlines() if line.strip()]
        i = 0
        while i < len(lines):
            if lines[i].endswith("?"):
                q = lines[i]
                a = lines[i+1] if i+1 < len(lines) else ""
                faqs.append({"question": q, "answer": a})
                i += 2
            else:
                i += 1
        logger.info("Loaded %d FAQs", len(faqs))
    except Exception as e:
        logger.exception("Error loading FAQs: %s", str(e))
    return faqs

FAQS = load_faqs()

def search_faq(query: str):
    """
    Use Ollama to find the most relevant FAQ.
    """
    from ..ollama_runner import run_llm
    if not FAQS:
        return {"question": None, "answer": "No FAQs available."}

    faq_text = "\n".join([f"Q: {f['question']}\nA: {f['answer']}" for f in FAQS])
    prompt = f"""
    You are a banking FAQ assistant. Given the query: "{query}", 
    find the most relevant question and return its answer.

    FAQs:
    {faq_text}

    Respond with only the best matching answer.
    """
    answer = run_llm(prompt)
    return {"answer": answer.strip()}
