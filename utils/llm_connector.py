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


# # utils/llm_connector.py
# from unsloth import FastLanguageModel
# import subprocess
# import json
# import torch
# from transformers import (
#     AutoModelForCausalLM,
#     AutoTokenizer,
#     StoppingCriteria,
#     StoppingCriteriaList,
#     TextIteratorStreamer,
# )
# from threading import Thread

# from .logger import get_logger

# logger = get_logger("LLMConnector")

# # Global variables for Mongolian model (lazy initialization)
# _mongolian_model = None
# _mongolian_tokenizer = None
# _mongolian_device = None


# def _load_mongolian_model():
#     """Load Mongolian Llama3 model on first use"""
#     global _mongolian_model, _mongolian_tokenizer, _mongolian_device

#     if _mongolian_model is not None:
#         return

#     try:
#         max_seq_length = 2048
#         load_in_4bit = True

#         model, tokenizer = FastLanguageModel.from_pretrained(
#             model_name="Dorjzodovsuren/Mongolian_Llama3-v1.1",
#             max_seq_length=max_seq_length,
#             dtype=None,
#             load_in_4bit=load_in_4bit,
#         )

#         FastLanguageModel.for_inference(model)

#         _mongolian_device = "cuda" if torch.cuda.is_available() else "cpu"
#         model = model.to(_mongolian_device)

#         _mongolian_model = model
#         _mongolian_tokenizer = tokenizer

#         logger.info("Mongolian Llama3 model loaded successfully")

#     except Exception as e:
#         logger.error("Failed to load Mongolian model: %s", str(e))
#         _mongolian_model = None


# alpaca_prompt = """Below is an instruction that describes a task, paired with an input that provides further context. Write a response that appropriately completes the request.

# ### Instruction:
# {}

# ### Input:
# {}

# ### Response:
# {}"""


# class StopOnTokens(StoppingCriteria):
#     def __call__(
#         self, input_ids: torch.LongTensor, scores: torch.FloatTensor, **kwargs
#     ) -> bool:
#         stop_ids = [29, 0]  # EOS tokens
#         for stop_id in stop_ids:
#             if input_ids[0][-1] == stop_id:
#                 return True
#         return False


# def detect_mongolian(text: str) -> bool:
#     """Simple heuristic to detect Mongolian script (Unicode range U+1800-U+18AF)"""
#     return any(0x1800 <= ord(char) <= 0x18AF for char in text)


# def run_mongolian_llm(prompt: str, timeout: int = 60) -> str:
#     """
#     Run Mongolian Llama3 model for Mongolian language inputs.
#     Returns generated response or empty string on error.
#     """
#     if not detect_mongolian(prompt):
#         logger.debug("Input not detected as Mongolian, skipping Mongolian model")
#         return ""
    

#     _load_mongolian_model()

#     if _mongolian_model is None:
#         logger.error("Mongolian model not available")
#         return ""

#     try:
#         stop = StopOnTokens()
#         messages = alpaca_prompt.format(prompt, "", "")

#         model_inputs = _mongolian_tokenizer([messages], return_tensors="pt").to(
#             _mongolian_device
#         )

#         streamer = TextIteratorStreamer(
#             _mongolian_tokenizer,
#             timeout=timeout,
#             skip_prompt=True,
#             skip_special_tokens=True,
#         )

#         generate_kwargs = dict(
#             model_inputs,
#             streamer=streamer,
#             max_new_tokens=1024,
#             temperature=0.7,
#             top_p=0.9,
#             top_k=50,
#             do_sample=True,
#             stopping_criteria=StoppingCriteriaList([stop]),
#         )

#         # Run generation in thread
#         t = Thread(target=_mongolian_model.generate, kwargs=generate_kwargs)
#         t.start()

#         # Collect streamed output
#         response = ""
#         for new_token in streamer:
#             if new_token != "<":
#                 response += new_token

#         logger.debug("Mongolian model generated %d chars", len(response))
#         return response.strip()

#     except subprocess.TimeoutExpired:
#         logger.error("Mongolian LLM call timed out after %ds", timeout)
#         return ""
#     except Exception as e:
#         logger.exception("Error in Mongolian LLM: %s", str(e))
#         return ""


# def run_llm(prompt: str, timeout: int = 60) -> str:
#     """
#     Main LLM function: detects Mongolian input and routes to appropriate model.
#     Uses Mongolian Llama3 for Mongolian text, falls back to Ollama openchat for others.
#     """
#     # First try Mongolian model
#     mongolian_response = run_mongolian_llm(prompt, timeout)
#     if mongolian_response:
#         return mongolian_response

#     # Fallback to original Ollama implementation
#     try:
#         result = subprocess.run(
#             ["ollama", "run", "openchat:latest"],
#             input=prompt.encode("utf-8"),
#             stdout=subprocess.PIPE,
#             stderr=subprocess.PIPE,
#             timeout=timeout,
#         )

#         if result.returncode != 0:
#             logger.error("Ollama error: %s", result.stderr.decode("utf-8"))
#             return ""

#         output = result.stdout.decode("utf-8").strip()
#         return output

#     except subprocess.TimeoutExpired:
#         logger.error("Ollama call timed out after %ds", timeout)
#         return ""
#     except Exception as e:
#         logger.exception("Unexpected error in run_llm: %s", str(e))
#         return ""
