# langraph_flow/nodes/language_translation_node.py
"""
Language Detection and Translation Node - SYNCHRONOUS VERSION
Works perfectly with LangGraph (no async required)
"""

from typing import Dict, Any
import langdetect
from googletrans import Translator  # SYNCHRONOUS
from langdetect.lang_detect_exception import LangDetectException
from utils.logger import get_logger

logger = get_logger(__name__)
translator = Translator()  # SYNCHRONOUS translator

SUPPORTED_LANGUAGES = {
    'en': 'English', 'hi': 'Hindi', 'es': 'Spanish', 'fr': 'French',
    'de': 'German', 'pt': 'Portuguese', 'ja': 'Japanese', 'zh-cn': 'Chinese (Simplified)',
    'ar': 'Arabic', 'bn': 'Bengali', 'pa': 'Punjabi', 'ta': 'Tamil',
    'te': 'Telugu', 'ml': 'Malayalam', 'kn': 'Kannada', 'mn': 'Mongolian'
}

def language_translation_node(state: Dict[str, Any]) -> Dict[str, Any]:  # SYNCHRONOUS
    """Detects language, translates to English, stores original lang."""
    user_input = state.get('user_input', '').strip()
    
    # Initialize language fields
    state['input_language'] = 'en'
    state['user_input_en'] = user_input
    state['original_user_input'] = user_input
    
    if not user_input:
        logger.warning("Empty user input received")
        return state
    
    try:
        # Detect input language
        detected_lang = langdetect.detect(user_input)
        state['input_language'] = detected_lang
        logger.info(f"Detected language: {detected_lang} ({SUPPORTED_LANGUAGES.get(detected_lang, 'Unknown')})")
        
        # Translate to English if not already English (SYNCHRONOUS)
        if detected_lang != 'en':
            try:
                translated_result = translator.translate(user_input, src=detected_lang, dest='en')
                state['user_input_en'] = translated_result.text  # SYNCHRONOUS .text
                logger.info(f"Translated input from {detected_lang} to English")
                logger.debug(f"Original: {user_input}")
                logger.debug(f"Translated: {state['user_input_en']}")
            except Exception as trans_error:
                logger.warning(f"Translation failed: {trans_error}. Using original input.")
                state['user_input_en'] = user_input
        else:
            state['user_input_en'] = user_input
        
    except LangDetectException as e:
        logger.warning(f"Language detection failed: {e}. Defaulting to English.")
        state['input_language'] = 'en'
        state['user_input_en'] = user_input
    except Exception as e:
        logger.error(f"Unexpected error in language translation: {e}")
        state['input_language'] = 'en'
        state['user_input_en'] = user_input
    
    return state

def translate_response_to_user_language(state: Dict[str, Any]) -> Dict[str, Any]:  # SYNCHRONOUS
    """Translates bot response back to user's original language."""
    input_lang = state.get('input_language', 'en')
    result = state.get('result')
    
    # No translation needed for English
    if input_lang == 'en':
        return state
    
    try:
        # Handle dict result with 'message' or 'response' field
        if isinstance(result, dict):
            message = result.get('message') or result.get('response') or result.get('text')
            if message and isinstance(message, str):
                translated_result = translator.translate(message, src='en', dest=input_lang)
                translated_message = translated_result.text  # SYNCHRONOUS .text
                
                # Update the appropriate field
                if 'message' in result:
                    result['message'] = translated_message
                elif 'response' in result:
                    result['response'] = translated_message
                elif 'text' in result:
                    result['text'] = translated_message
                
                logger.info(f"Response translated back to {SUPPORTED_LANGUAGES.get(input_lang, input_lang)}")
                logger.debug(f"Translated response: {translated_message}")
        
        # Handle string result
        elif isinstance(result, str):
            translated_result = translator.translate(result, src='en', dest=input_lang)
            state['result'] = translated_result.text  # SYNCHRONOUS .text
            logger.info(f"Response translated back to {SUPPORTED_LANGUAGES.get(input_lang, input_lang)}")
            
    except Exception as e:
        logger.error(f"Response translation failed: {e}. Returning original response.")
    
    state['result'] = result
    return state
