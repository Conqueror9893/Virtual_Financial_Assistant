# langraph_flow/nodes/voice_node.py
import speech_recognition as sr
from gtts import gTTS
import tempfile, os
from utils.logger import get_logger

logger = get_logger("VoiceNode")

def handle_voice_interaction(user_id: str, state_input: str = None):
    """Handles voice interaction with speech recognition and synthesis."""
    recognizer = sr.Recognizer()

    if not state_input:
        with sr.Microphone() as source:
            print("🎤 Listening...")
            audio = recognizer.listen(source)
            try:
                text = recognizer.recognize_google(audio)
                print(f"🗣️ You said: {text}")
                return {"status": "ok", "recognized_text": text}
            except sr.UnknownValueError:
                return {"status": "error", "message": "Could not understand audio."}
            except sr.RequestError as e:
                return {"status": "error", "message": f"Speech recognition service failed: {e}"}
    else:
        # Convert text to speech
        try:
            tts = gTTS(text=state_input, lang="en")
            with tempfile.NamedTemporaryFile(delete=False, suffix=".mp3") as f:
                tts.save(f.name)
                os.system(f"mpg123 {f.name}")
            return {"status": "spoken", "message": "Voice output played."}
        except Exception as e:
            logger.exception("TTS Error")
            return {"status": "error", "message": str(e)}
