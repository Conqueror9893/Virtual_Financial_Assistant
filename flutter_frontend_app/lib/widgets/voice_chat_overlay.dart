// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'dart:convert';
// import 'package:http/http.dart' as http;
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:flutter_tts/flutter_tts.dart';

// class VoiceChatOverlay extends StatefulWidget {
//   final VoidCallback onClose;
//   final Function(String) onSendVoiceText;

//   const VoiceChatOverlay({
//     super.key,
//     required this.onClose,
//     required this.onSendVoiceText,
//   });

//   @override
//   State<VoiceChatOverlay> createState() => _VoiceChatOverlayState();
// }

// class _VoiceChatOverlayState extends State<VoiceChatOverlay> {
//   late stt.SpeechToText _speech;
//   late FlutterTts _flutterTts;

//   bool _isListening = false;
//   String _recognizedText = "";
//   Timer? _silenceTimer;

//   @override
//   void initState() {
//     super.initState();
//     _speech = stt.SpeechToText();
//     _flutterTts = FlutterTts();
//   }

//   @override
//   void dispose() {
//     _speech.stop();
//     _silenceTimer?.cancel();
//     super.dispose();
//   }

//   /// Start listening and handle silence detection
//   Future<void> _startListening() async {
//     bool available = await _speech.initialize(
//       onError: (error) => debugPrint("Speech error: $error"),
//     );
//     if (available) {
//       setState(() {
//         _isListening = true;
//         _recognizedText = "";
//       });
//       _speech.listen(
//         onResult: (result) {
//           setState(() {
//             _recognizedText = result.recognizedWords;
//           });
//           _restartSilenceTimer();
//         },
//       );
//     }
//   }

//   /// Stop listening manually or after timeout
//   Future<void> _stopListening() async {
//     await _speech.stop();
//     setState(() => _isListening = false);

//     if (_recognizedText.trim().isNotEmpty) {
//       await _sendToBackend(_recognizedText);
//     }
//   }

//   /// Restart the silence timer every time user speaks
//   void _restartSilenceTimer() {
//     _silenceTimer?.cancel();
//     _silenceTimer = Timer(const Duration(seconds: 3), () async {
//       if (_isListening) {
//         await _stopListening();
//       }
//     });
//   }

//   /// Send recognized text to backend and get bot response
//   Future<void> _sendToBackend(String text) async {
//     // Notify chat screen to display user's message
//     widget.onSendVoiceText(text);

//     try {
//       final response = await http.post(
//         Uri.parse('http://10.32.2.151:3009/chatbot'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({
//           "user_id": "1", // Optionally make this dynamic
//           "query": text.trim(),
//         }),
//       );

//       String responseText = "";

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);

//         // Flatten bot response (same as your chat screen)
//         final botResponse = data['response'] is Map
//             ? (data['response']['response'] ?? data['response'])
//             : data['response'];

//         if (botResponse is String) {
//           responseText = botResponse;
//         } else if (botResponse is Map) {
//           // Prefer to speak user-friendly text if available
//           responseText = botResponse['message']?.toString() ?? '';
//           if (responseText.isEmpty) {
//             responseText = botResponse.toString();
//           }
//         } else {
//           responseText = "Unexpected response format.";
//         }
//       } else {
//         responseText = "Error: Server returned ${response.statusCode}";
//       }

//       // Speak the bot's reply using TTS
//       await _flutterTts.speak(responseText);
//     } catch (e) {
//       debugPrint("Error sending voice text: $e");
//       await _flutterTts
//           .speak("Sorry, there was an error connecting to the server.");
//     }
//   }

//   /// UI
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: const Color(0xFFFEECE2).withOpacity(0.95),
//       child: Column(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           const SizedBox(height: 40),
//           const Text(
//             "Speaking to Appzia",
//             style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
//           ),
//           const SizedBox(height: 32),

//           // 🌀 Animated GIF (voice waves)
//           Image.asset(
//             'assets/voice_animation.png', // replace with your actual file name
//             width: 220,
//             height: 220,
//             fit: BoxFit.cover,
//           ),

//           const SizedBox(height: 28),

//           if (_recognizedText.isNotEmpty)
//             Padding(
//               padding: const EdgeInsets.symmetric(horizontal: 24.0),
//               child: Text(
//                 _recognizedText,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(
//                   color: Colors.black,
//                   fontSize: 16,
//                   fontWeight: FontWeight.w400,
//                 ),
//               ),
//             ),

//           const Spacer(),

//           // 🔘 Three bottom buttons
//           Padding(
//             padding: const EdgeInsets.only(bottom: 32),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 // 🗨️ Chat button
//                 IconButton(
//                   icon: const Icon(Icons.chat_bubble_outline,
//                       color: Colors.grey, size: 36),
//                   onPressed: widget.onClose, // returns to chat
//                 ),

//                 // 🎙️ Mic button
//                 IconButton(
//                   icon: Icon(
//                     _isListening ? Icons.mic : Icons.mic_none,
//                     color: Colors.orange,
//                     size: 48,
//                   ),
//                   onPressed: _isListening ? _stopListening : _startListening,
//                 ),

//                 // ❌ Close button
//                 IconButton(
//                   icon: const Icon(Icons.close, color: Colors.red, size: 36),
//                   onPressed: () {
//                     _speech.stop();
//                     widget.onClose();
//                   },
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class VoiceChatOverlay extends StatefulWidget {
  final VoidCallback onClose;

  const VoiceChatOverlay({
    super.key,
    required this.onClose,
  });

  @override
  State<VoiceChatOverlay> createState() => _VoiceChatOverlayState();
}

class _VoiceChatOverlayState extends State<VoiceChatOverlay> {
  late stt.SpeechToText _speech;
  late FlutterTts _flutterTts;

  bool _isListening = false;
  bool _isLoadingResponse = false;
  String _recognizedText = "";
  String _botResponse = "";
  Timer? _silenceTimer;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
  }

  @override
  void dispose() {
    _speech.stop();
    _silenceTimer?.cancel();
    super.dispose();
  }

  /// Start listening and handle silence detection
  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onError: (error) => debugPrint("Speech error: $error"),
    );
    if (available) {
      setState(() {
        _isListening = true;
        _recognizedText = "";
        _botResponse = "";
      });
      _speech.listen(
        onResult: (result) {
          setState(() => _recognizedText = result.recognizedWords);
          _restartSilenceTimer();
        },
      );
    }
  }

  /// Stop listening manually or after timeout
  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);

    if (_recognizedText.trim().isNotEmpty) {
      await _sendToBackend(_recognizedText);
    }
  }

  /// Restart the silence timer every time user speaks
  void _restartSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 3), () async {
      if (_isListening) await _stopListening();
    });
  }

  /// Send recognized text to backend and get bot response
  Future<void> _sendToBackend(String text) async {
    setState(() {
      _isLoadingResponse = true;
      _botResponse = "";
    });

    try {
      final response = await http.post(
        Uri.parse('http://10.32.2.151:3009/chatbot'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "user_id": "1",
          "query": text.trim(),
        }),
      );

      String responseText = "";

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botResponse = data['response'] is Map
            ? (data['response']['response'] ?? data['response'])
            : data['response'];

        if (botResponse is String) {
          responseText = botResponse;
        } else if (botResponse is Map) {
          responseText = botResponse['message']?.toString() ?? '';
          if (responseText.isEmpty) {
            responseText = botResponse.toString();
          }
        } else {
          responseText = "Unexpected response format.";
        }
      } else {
        responseText = "Error: Server returned ${response.statusCode}";
      }

      // Show + Speak the bot's reply
      setState(() {
        _isLoadingResponse = false;
        _botResponse = responseText;
      });
      await _flutterTts.speak(responseText);
    } catch (e) {
      debugPrint("Error sending voice text: $e");
      setState(() {
        _isLoadingResponse = false;
        _botResponse = "Sorry, there was an error connecting to the server.";
      });
      await _flutterTts.speak(_botResponse);
    }
  }

  /// UI
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFEECE2).withOpacity(0.95),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text(
            "Speaking to Appzia",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 32),

          // 🌀 Animated GIF (voice waves)
          Image.asset(
            'assets/voice_animation.png', // use your actual GIF name
            width: 220,
            height: 220,
            fit: BoxFit.cover,
          ),

          const SizedBox(height: 28),

          if (_recognizedText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                "\"$_recognizedText\"",
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),

          if (_isLoadingResponse)
            const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: Colors.orange),
            ),

          if (_botResponse.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
              child: Text(
                _botResponse,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

          const Spacer(),

          // 🔘 Three bottom buttons
          Padding(
            padding: const EdgeInsets.only(bottom: 32),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 🗨️ Chat button
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline,
                      color: Colors.grey, size: 36),
                  onPressed: () {
                    _speech.stop();
                    widget.onClose(); // exit overlay manually
                  },
                ),

                // 🎙️ Mic button
                IconButton(
                  icon: Icon(
                    _isListening ? Icons.mic : Icons.mic_none,
                    color: Colors.orange,
                    size: 48,
                  ),
                  onPressed: _isListening ? _stopListening : _startListening,
                ),

                // ❌ Close button
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red, size: 36),
                  onPressed: () {
                    _speech.stop();
                    widget.onClose();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
