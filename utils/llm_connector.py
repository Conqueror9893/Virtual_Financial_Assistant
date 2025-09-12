# utils/llm_connector.py
import subprocess
import json
from .logger import get_logger

logger = get_logger("LLMConnector")


def run_llm(prompt: str, timeout: int = 60) -> str:
    """
    Call ollama with openchat:latest and return its output as string.
    """
    try:
      
        result = subprocess.run(
            ["ollama", "run", "openchat:latest"],
            input=prompt.encode("utf-8"),
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=timeout,
        )
        
        
        if result.returncode != 0:
            logger.error("LLM error: %s", result.stderr.decode("utf-8"))
            return ""
        output = result.stdout.decode("utf-8").strip()
  
        return output
    except subprocess.TimeoutExpired:
        logger.error("LLM call timed out after %ds", timeout)
        return ""
    except Exception as e:
        logger.exception("Unexpected error in run_llm: %s", str(e))
        return ""
