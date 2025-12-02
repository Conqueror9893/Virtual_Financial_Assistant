import langdetect
from googletrans import Translator
from langdetect.lang_detect_exception import LangDetectException

translator = Translator()

def language_translation_node(state: Dict[str, Any]) -> Dict[str, Any]:
    """Detects language, translates user input to English, stores original lang."""
    user_input = state.get('user_input', '').strip()
    if not user_input:
        return state
    
    try:
        # Detect input language
        detected_lang = langdetect.detect(user_input)
        state['input_language'] = detected_lang
        logger.info(f"Detected language: {detected_lang}")
        
        # Translate to English if not already English
        if detected_lang != 'en':
            translated_input = translator.translate(user_input, src=detected_lang, dest='en').text
            state['user_input_en'] = translated_input  # English version for processing
            state['original_user_input'] = user_input  # Store original
            logger.info(f"Translated '{user_input}' to '{translated_input}'")
        else:
            state['user_input_en'] = user_input
        
    except LangDetectException:
        logger.warning("Language detection failed, proceeding with original input")
        state['input_language'] = 'en'
        state['user_input_en'] = user_input
        state['original_user_input'] = user_input
    
    return state
