// // // flutter_frontend_app/lib/widgets/voice_chat_overlay.dart

// // import 'dart:async';
// // import 'dart:convert';
// // import 'package:flutter/material.dart';
// // import 'package:http/http.dart' as http;
// // import 'package:speech_to_text/speech_to_text.dart' as stt;
// // import 'package:flutter_tts/flutter_tts.dart';
// // import 'package:video_player/video_player.dart';

// // class VoiceChatOverlay extends StatefulWidget {
// //   final VoidCallback onClose;

// //   const VoiceChatOverlay({super.key, required this.onClose});

// //   @override
// //   State<VoiceChatOverlay> createState() => _VoiceChatOverlayState();
// // }

// // class _VoiceChatOverlayState extends State<VoiceChatOverlay> {
// //   late stt.SpeechToText _speech;
// //   late FlutterTts _flutterTts;
// //   late VideoPlayerController _videoController;
// //   bool _isListening = false;
// //   bool _isLoadingResponse = false;
// //   bool _isBotSpeaking = false;
// //   bool _showTranscription = true; // Top-right toggle: default ON
// //   bool _audioEnabled = true; // Speaker toggle: default ON (enabled)
// //   bool _isPaused = false; // Pause state: default OFF (playing)
// //   String _recognizedText = ""; // User speech
// //   String _botResponse = ""; // Bot response
// //   Timer? _silenceTimer;
// //   List<Map<dynamic, dynamic>> _multipleOptions = [];

// //   @override
// //   void initState() {
// //     super.initState();
// //     _speech = stt.SpeechToText();
// //     _flutterTts = FlutterTts();
// //     _initializeVideo();
// //     _startListening();
// //   }

// //   void _initializeVideo() {
// //     _videoController = VideoPlayerController.asset(
// //       'assets/animation_chatbot.mp4',
// //     )..initialize().then((_) {
// //         setState(() {});
// //         _videoController.setLooping(true);
// //         _videoController.play();
// //       }).catchError((e) {
// //         debugPrint('Error initializing video: $e');
// //       });
// //   }

// //   @override
// //   void dispose() {
// //     _speech.stop();
// //     _flutterTts.stop();
// //     _silenceTimer?.cancel();
// //     _videoController.dispose();
// //     super.dispose();
// //   }

// //   // Start listening for user speech
// //   Future<void> _startListening() async {
// //     if (_isPaused) return;
// //     bool available = await _speech.initialize(
// //       onError: (error) => debugPrint("Speech error: $error"),
// //     );
// //     if (available) {
// //       setState(() {
// //         _isListening = true;
// //         _recognizedText = "";
// //         _botResponse = "";
// //         _multipleOptions = [];
// //         _isBotSpeaking = false;
// //       });
// //       _speech.listen(
// //         onResult: (result) {
// //           setState(() => _recognizedText = result.recognizedWords);
// //           _restartSilenceTimer();
// //         },
// //       );
// //     }
// //   }

// //   // Stop listening (pause recording)
// //   Future<void> _stopListening() async {
// //     await _speech.stop();
// //     setState(() => _isListening = false);
// //     if (_recognizedText.trim().isNotEmpty) {
// //       await _sendToBackend(_recognizedText);
// //     }
// //   }

// //   // Restart silence timer (3 seconds of silence auto-stops listening)
// //   void _restartSilenceTimer() {
// //     _silenceTimer?.cancel();
// //     _silenceTimer = Timer(const Duration(seconds: 3), () async {
// //       if (_isListening && !_isPaused) {
// //         await _stopListening();
// //       }
// //     });
// //   }

// //   // Pause conversation - interrupt bot and go dormant
// //   void _pauseConversation() {
// //     _silenceTimer?.cancel();
// //     _speech.stop();
// //     _flutterTts.stop();
// //     setState(() {
// //       _isPaused = true;
// //       _isListening = false;
// //       _isBotSpeaking = false;
// //     });
// //   }

// //   // Resume conversation after pause
// //   void _resumeConversation() {
// //     setState(() {
// //       _isPaused = false;
// //     });
// //     _startListening();
// //   }

// //   // Send recognized text to backend
// //   Future<void> _sendToBackend(String text) async {
// //     String responseText = "";
// //     setState(() {
// //       _isLoadingResponse = true;
// //       _botResponse = "";
// //       _multipleOptions = [];
// //       _isListening = false;
// //     });

// //     try {
// //       final response = await http.post(
// //         Uri.parse('http://10.32.2.151:3009/chatbot'),
// //         headers: {'Content-Type': 'application/json'},
// //         body: jsonEncode({"user_id": "1", "query": text.trim()}),
// //       );

// //       if (response.statusCode == 200) {
// //         final data = jsonDecode(response.body);
// //         final botData = data['response'];

// //         if (botData is Map && botData['status'] == "multiple_matches") {
// //           responseText = botData['message'] ?? "Please select an option.";
// //           setState(() {
// //             _botResponse = responseText;
// //             _multipleOptions =
// //                 List<Map<dynamic, dynamic>>.from(botData['options'] ?? []);
// //           });
// //         } else {
// //           responseText = botData is Map
// //               ? (botData['message'] ?? botData.toString())
// //               : botData.toString();
// //           setState(() {
// //             _botResponse = responseText;
// //             _multipleOptions = [];
// //           });
// //         }

// //         // ✅ Speak response only if audio is enabled and not paused
// //         if (_audioEnabled && !_isPaused) {
// //           setState(() => _isBotSpeaking = true);
// //           await _flutterTts.speak(responseText);
// //           setState(() => _isBotSpeaking = false);
// //         }
// //       } else {
// //         responseText = "Error: Server returned ${response.statusCode}";
// //         setState(() => _botResponse = responseText);
// //         if (_audioEnabled && !_isPaused) {
// //           setState(() => _isBotSpeaking = true);
// //           await _flutterTts.speak(responseText);
// //           setState(() => _isBotSpeaking = false);
// //         }
// //       }
// //     } catch (e) {
// //       debugPrint("Error sending voice text: $e");
// //       responseText = "Sorry, there was an error connecting to the server.";
// //       setState(() => _botResponse = responseText);
// //       if (_audioEnabled && !_isPaused) {
// //         setState(() => _isBotSpeaking = true);
// //         await _flutterTts.speak(responseText);
// //         setState(() => _isBotSpeaking = false);
// //       }
// //     } finally {
// //       setState(() => _isLoadingResponse = false);
// //       // Auto-restart listening after response if not paused
// //       if (!_isPaused) {
// //         await Future.delayed(const Duration(seconds: 1));
// //         await _startListening();
// //       }
// //     }
// //   }

// //   @override
// //   Widget build(BuildContext context) {
// //     return Container(
// //       color: const Color(0xFFF0F4FF),
// //       child: Column(
// //         children: [
// //           // App bar with transcription toggle
// //           Container(
// //             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
// //             decoration: const BoxDecoration(
// //               color: Colors.white,
// //               border: Border(
// //                 bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
// //               ),
// //             ),
// //             child: Row(
// //               mainAxisAlignment: MainAxisAlignment.spaceBetween,
// //               children: [
// //                 const Text(
// //                   "Voice Chat",
// //                   style: TextStyle(
// //                     fontSize: 16,
// //                     fontWeight: FontWeight.w600,
// //                     color: Colors.black87,
// //                   ),
// //                 ),
// //                 // ✅ Transcription toggle (top-right)
// //                 GestureDetector(
// //                   onTap: () {
// //                     setState(() => _showTranscription = !_showTranscription);
// //                   },
// //                   child: Container(
// //                     padding: const EdgeInsets.all(8),
// //                     decoration: BoxDecoration(
// //                       color: _showTranscription
// //                           ? const Color(0xFF2B7BBD)
// //                           : const Color(0xFFE0E0E0),
// //                       borderRadius: BorderRadius.circular(8),
// //                     ),
// //                     child: Icon(
// //                       Icons.subtitles,
// //                       color: _showTranscription
// //                           ? Colors.white
// //                           : Colors.grey[600],
// //                       size: 20,
// //                     ),
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),

// //           // Main content
// //           Expanded(
// //             child: SingleChildScrollView(
// //               child: Column(
// //                 children: [
// //                   const SizedBox(height: 40),

// //                   // Video animation (looping)
// //                   if (_videoController.value.isInitialized)
// //                     Container(
// //                       width: 200,
// //                       height: 200,
// //                       decoration: BoxDecoration(
// //                         borderRadius: BorderRadius.circular(150),
// //                         boxShadow: [
// //                           BoxShadow(
// //                             color: Colors.blue.withOpacity(0.2),
// //                             blurRadius: 20,
// //                             spreadRadius: 5,
// //                           ),
// //                         ],
// //                       ),
// //                       child: ClipOval(
// //                         child: VideoPlayer(_videoController),
// //                       ),
// //                     )
// //                   else
// //                     Container(
// //                       width: 200,
// //                       height: 200,
// //                       decoration: BoxDecoration(
// //                         color: Colors.grey[300],
// //                         borderRadius: BorderRadius.circular(150),
// //                       ),
// //                       child: const Center(
// //                         child: CircularProgressIndicator(),
// //                       ),
// //                     ),

// //                   const SizedBox(height: 40),

// //                   // ✅ Show both user and bot transcriptions clearly labeled
// //                   if (_showTranscription)
// //                     Padding(
// //                       padding: const EdgeInsets.symmetric(horizontal: 24),
// //                       child: Column(
// //                         children: [
// //                           // ✅ User transcription (YOU label)
// //                           if (_recognizedText.isNotEmpty)
// //                             Container(
// //                               padding: const EdgeInsets.symmetric(
// //                                   horizontal: 16, vertical: 12),
// //                               decoration: BoxDecoration(
// //                                 color: const Color(0xFFE3F2FD),
// //                                 borderRadius: BorderRadius.circular(12),
// //                                 border: Border.all(
// //                                   color: const Color(0xFF2B7BBD),
// //                                   width: 1,
// //                                 ),
// //                               ),
// //                               child: Column(
// //                                 crossAxisAlignment: CrossAxisAlignment.start,
// //                                 children: [
// //                                   const Text(
// //                                     "You:",
// //                                     style: TextStyle(
// //                                       color: Colors.black87,
// //                                       fontSize: 13,
// //                                       fontWeight: FontWeight.w600,
// //                                     ),
// //                                   ),
// //                                   const SizedBox(height: 4),
// //                                   Text(
// //                                     '"$_recognizedText"',
// //                                     textAlign: TextAlign.start,
// //                                     style: const TextStyle(
// //                                       color: Colors.black87,
// //                                       fontSize: 14,
// //                                       fontWeight: FontWeight.w400,
// //                                       fontStyle: FontStyle.italic,
// //                                     ),
// //                                   ),
// //                                 ],
// //                               ),
// //                             ),

// //                           const SizedBox(height: 16),

// //                           // ✅ Bot transcription (NIVI label)
// //                           if (_botResponse.isNotEmpty)
// //                             Container(
// //                               padding: const EdgeInsets.symmetric(
// //                                   horizontal: 16, vertical: 12),
// //                               decoration: BoxDecoration(
// //                                 color: const Color(0xFFF0F4FF),
// //                                 borderRadius: BorderRadius.circular(12),
// //                                 border: Border.all(
// //                                   color: const Color(0xFFCED7E0),
// //                                   width: 1,
// //                                 ),
// //                               ),
// //                               child: Column(
// //                                 crossAxisAlignment: CrossAxisAlignment.start,
// //                                 children: [
// //                                   const Text(
// //                                     "Nivi:",
// //                                     style: TextStyle(
// //                                       color: Colors.deepPurple,
// //                                       fontSize: 13,
// //                                       fontWeight: FontWeight.w600,
// //                                     ),
// //                                   ),
// //                                   const SizedBox(height: 4),
// //                                   Text(
// //                                     _botResponse,
// //                                     textAlign: TextAlign.start,
// //                                     style: const TextStyle(
// //                                       color: Colors.black87,
// //                                       fontSize: 14,
// //                                       fontWeight: FontWeight.w500,
// //                                     ),
// //                                   ),
// //                                 ],
// //                               ),
// //                             ),
// //                         ],
// //                       ),
// //                     ),

// //                   const SizedBox(height: 24),

// //                   // Multiple options (horizontal scroll)
// //                   if (_multipleOptions.isNotEmpty)
// //                     SizedBox(
// //                       height: 120,
// //                       child: ListView.separated(
// //                         scrollDirection: Axis.horizontal,
// //                         padding: const EdgeInsets.symmetric(horizontal: 16),
// //                         itemCount: _multipleOptions.length,
// //                         separatorBuilder: (_, __) => const SizedBox(width: 12),
// //                         itemBuilder: (context, index) {
// //                           final option = _multipleOptions[index];
// //                           return GestureDetector(
// //                             onTap: _isPaused
// //                                 ? null
// //                                 : () {
// //                                     debugPrint(
// //                                         "Selected option: ${option['name']}");
// //                                   },
// //                             child: Container(
// //                               width: 180,
// //                               padding: const EdgeInsets.all(12),
// //                               decoration: BoxDecoration(
// //                                 color: const Color(0xFFFFF9E6),
// //                                 borderRadius: BorderRadius.circular(12),
// //                                 border: Border.all(
// //                                   color: const Color(0xFF2B7BBD),
// //                                   width: 1.5,
// //                                 ),
// //                               ),
// //                               child: Column(
// //                                 mainAxisAlignment: MainAxisAlignment.center,
// //                                 crossAxisAlignment: CrossAxisAlignment.start,
// //                                 children: [
// //                                   Text(
// //                                     option['name'] ?? "Unknown",
// //                                     style: const TextStyle(
// //                                       fontWeight: FontWeight.bold,
// //                                       fontSize: 15,
// //                                     ),
// //                                   ),
// //                                   const SizedBox(height: 6),
// //                                   Text(
// //                                     option['account_number'] ?? "",
// //                                     style: const TextStyle(fontSize: 13),
// //                                   ),
// //                                 ],
// //                               ),
// //                             ),
// //                           );
// //                         },
// //                       ),
// //                     ),

// //                   const SizedBox(height: 40),
// //                 ],
// //               ),
// //             ),
// //           ),

// //           // Bottom control buttons
// //           Container(
// //             padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
// //             child: Row(
// //               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
// //               children: [
// //                 // Speaker toggle (audio on/off)
// //                 GestureDetector(
// //                   onTap: () {
// //                     setState(() => _audioEnabled = !_audioEnabled);
// //                   },
// //                   child: Container(
// //                     width: 60,
// //                     height: 60,
// //                     decoration: BoxDecoration(
// //                       color: Colors.white,
// //                       borderRadius: const BorderRadius.horizontal(
// //                         left: Radius.circular(24),
// //                         right: Radius.circular(24),
// //                       ),
// //                       border: Border.all(
// //                         color: _audioEnabled
// //                             ? const Color(0xFF2B7BBD)
// //                             : Colors.grey[400]!,
// //                         width: 2,
// //                       ),
// //                     ),
// //                     child: Icon(
// //                       _audioEnabled ? Icons.volume_up : Icons.volume_off,
// //                       color: _audioEnabled
// //                           ? const Color(0xFF2B7BBD)
// //                           : Colors.grey[400],
// //                       size: 28,
// //                     ),
// //                   ),
// //                 ),

// //                 // Mic toggle (listening on/off)
// //                 GestureDetector(
// //                   onTap: () {
// //                     if (_isListening) {
// //                       _stopListening();
// //                     } else if (!_isPaused) {
// //                       _startListening();
// //                     }
// //                   },
// //                   child: Container(
// //                     width: 60,
// //                     height: 60,
// //                     decoration: BoxDecoration(
// //                       color: Colors.white,
// //                       shape: BoxShape.circle,
// //                       border: Border.all(
// //                         color: _isListening
// //                             ? const Color(0xFF2B7BBD)
// //                             : Colors.grey[400]!,
// //                         width: 2,
// //                       ),
// //                     ),
// //                     child: Icon(
// //                       _isListening ? Icons.mic : Icons.mic_off,
// //                       color: _isListening
// //                           ? const Color(0xFF2B7BBD)
// //                           : Colors.grey[400],
// //                       size: 28,
// //                     ),
// //                   ),
// //                 ),

// //                 // Pause/Resume toggle
// //                 GestureDetector(
// //                   onTap: () {
// //                     if (_isPaused) {
// //                       _resumeConversation();
// //                     } else {
// //                       _pauseConversation();
// //                     }
// //                   },
// //                   child: Container(
// //                     width: 60,
// //                     height: 60,
// //                     decoration: BoxDecoration(
// //                       color: Colors.white,
// //                       shape: BoxShape.circle,
// //                       border: Border.all(
// //                         color: _isPaused
// //                             ? const Color(0xFF2B7BBD)
// //                             : Colors.grey[400]!,
// //                         width: 2,
// //                       ),
// //                     ),
// //                     child: Icon(
// //                       _isPaused ? Icons.play_arrow : Icons.pause,
// //                       color: _isPaused
// //                           ? const Color(0xFF2B7BBD)
// //                           : Colors.grey[400],
// //                       size: 28,
// //                     ),
// //                   ),
// //                 ),

// //                 // ✅ Close button (return to chat) - properly stops all audio and speech
// //                 GestureDetector(
// //                   onTap: () {
// //                     _speech.stop();
// //                     _flutterTts.stop();
// //                     _silenceTimer?.cancel();
// //                     widget.onClose();
// //                   },
// //                   child: Container(
// //                     width: 60,
// //                     height: 60,
// //                     decoration: BoxDecoration(
// //                       color: const Color(0xFFFFEBEE),
// //                       shape: BoxShape.circle,
// //                       border: Border.all(
// //                         color: Colors.grey,
// //                         width: 2,
// //                       ),
// //                     ),
// //                     child: const Icon(
// //                       Icons.close,
// //                       color: Color(0xFFD32F2F),
// //                       size: 28,
// //                     ),
// //                   ),
// //                 ),
// //               ],
// //             ),
// //           ),
// //         ],
// //       ),
// //     );
// //   }
// // }

// // flutter_frontend_app/lib/widgets/voice_chat_overlay.dart

// import 'dart:async';
// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:http/http.dart' as http;
// import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:flutter_tts/flutter_tts.dart';
// import 'package:video_player/video_player.dart';
// import '../utils/logger.dart';

// final logger = Logger("VoiceChatOverlay");

// class VoiceChatOverlay extends StatefulWidget {
//   final VoidCallback onClose;

//   const VoiceChatOverlay({super.key, required this.onClose});

//   @override
//   State<VoiceChatOverlay> createState() => _VoiceChatOverlayState();
// }

// class _VoiceChatOverlayState extends State<VoiceChatOverlay> {
//   late stt.SpeechToText _speech;
//   late FlutterTts _flutterTts;
//   late VideoPlayerController _videoController;
//   bool _isListening = false;
//   bool _isLoadingResponse = false;
//   bool _isBotSpeaking = false;
//   bool _showTranscription = true; // Top-right toggle: default ON
//   bool _audioEnabled = true; // Speaker toggle: default ON (enabled)
//   bool _isPaused = false; // Pause state: default OFF (playing)
//   // ✅ NEW: Track if mic was manually closed
//   bool _micManuallyClosed = false;
//   String _recognizedText = ""; // User speech
//   String _botResponse = ""; // Bot response
//   Timer? _silenceTimer;
//   List<Map<dynamic, dynamic>> _multipleOptions = [];

//   @override
//   void initState() {
//     super.initState();
//     _speech = stt.SpeechToText();
//     _flutterTts = FlutterTts();
//     _initializeVideo();
//     _startListening();
//   }

//   void _initializeVideo() {
//     _videoController = VideoPlayerController.asset(
//       'assets/animation_chatbot.mp4',
//     )..initialize().then((_) {
//         setState(() {});
//         _videoController.setLooping(true);
//         _videoController.play();
//       }).catchError((e) {
//         debugPrint('Error initializing video: $e');
//       });
//   }

//   @override
//   void dispose() {
//     _speech.stop();
//     _flutterTts.stop();
//     _silenceTimer?.cancel();
//     _videoController.dispose();
//     super.dispose();
//   }

//   // Start listening for user speech
//   Future<void> _startListening() async {
//     // ✅ Don't start if mic was manually closed or paused
//     if (_isPaused || _micManuallyClosed) return;
//     bool available = await _speech.initialize(
//       onError: (error) => debugPrint("Speech error: $error"),
//     );
//     if (available) {
//       setState(() {
//         _isListening = true;
//         _recognizedText = "";
//         _botResponse = "";
//         _multipleOptions = [];
//         _isBotSpeaking = false;
//       });
//       _speech.listen(
//         onResult: (result) {
//           setState(() => _recognizedText = result.recognizedWords);
//           _restartSilenceTimer();
//           logger.info("Recognized speech: $_recognizedText");
//         },
//       );
//     }
//   }

//   // Stop listening (pause recording)
//   Future<void> _stopListening() async {
//     await _speech.stop();
//     setState(() => _isListening = false);
//     if (_recognizedText.trim().isNotEmpty) {
//       await _sendToBackend(_recognizedText);
//     }
//     logger.info("Stopped listening. Recognized text: $_recognizedText");
//     logger.info("Mic manually closed: $_micManuallyClosed");
//   }

//   // ✅ NEW: Manually close the mic (user clicked the mic button to turn it off)
//   Future<void> _closeMicManually() async {
//     await _speech.stop();
//     setState(() {
//       _isListening = false;
//       _micManuallyClosed = true;
//     });
//   }

//   // Restart silence timer (3 seconds of silence auto-stops listening)
//   void _restartSilenceTimer() {
//     _silenceTimer?.cancel();
//     _silenceTimer = Timer(const Duration(seconds: 3), () async {
//       if (_isListening && !_isPaused && !_micManuallyClosed) {
//         await _stopListening();
//       }
//     });
//   }

//   // Pause conversation - interrupt bot and go dormant
//   void _pauseConversation() {
//     _silenceTimer?.cancel();
//     _speech.stop();
//     _flutterTts.stop();
//     setState(() {
//       _isPaused = true;
//       _isListening = false;
//       _isBotSpeaking = false;
//     });
//   }

//   // Resume conversation after pause
//   void _resumeConversation() {
//     setState(() {
//       _isPaused = false;
//       _micManuallyClosed = false; // ✅ Reset mic flag when resuming
//     });
//     _startListening();
//   }

//   // ✅ NEW: Extract answer from response for natural TTS
//   String _extractAnswerForTTS(Map<String, dynamic> responseData) {
//     // Try to get the answer field first
//     if (responseData.containsKey('answer')) {
//       String answer = responseData['answer'] ?? '';
//       if (answer.isNotEmpty) {
//         logger.info("Extracted answer for TTS: $answer");
//         return answer;
//       }
//     }
//     if (responseData.containsKey('structured_summary')) {
//       String structuredSummary = responseData['structured_summary']['trend_insights'] ?? '';
//       if (structuredSummary.isNotEmpty) {
//         logger.info("Extracted structured summary for TTS: $structuredSummary");
//       }
//     }

//     // Fallback to message if no answer
//     if (responseData.containsKey('message')) {
//       return responseData['message'] ?? '';
//     }

//     // Fallback to full response
//     return responseData.toString();
//   }

//   // Send recognized text to backend
//   Future<void> _sendToBackend(String text) async {
//     String responseText = "";
//     setState(() {
//       _isLoadingResponse = true;
//       _botResponse = "";
//       _multipleOptions = [];
//       _isListening = false;
//     });
//     logger.info("Sending to backend: $text");
//     try {
//       final response = await http.post(
//         Uri.parse('http://10.32.2.151:3009/chatbot'),
//         headers: {'Content-Type': 'application/json'},
//         body: jsonEncode({"user_id": "1", "query": text.trim()}),
//       );

//       if (response.statusCode == 200) {
//         final data = jsonDecode(response.body);
//         final botData = data['response'];

//         if (botData is Map && botData['status'] == "multiple_matches") {
//           responseText = botData['message'] ?? "Please select an option.";
//           setState(() {
//             _botResponse = responseText;
//             _multipleOptions =
//                 List<Map<dynamic, dynamic>>.from(botData['options'] ?? []);
//           });
//         } else {
//           // ✅ Extract only the answer for TTS in voice flow
//           responseText = botData is Map
//               ? _extractAnswerForTTS(botData as Map<String, dynamic>)
//               : botData.toString();

//           // ✅ Display full response (with links, etc.) in UI
//           String displayText = botData is Map
//               ? (botData['message'] ?? botData.toString())
//               : botData.toString();

//           setState(() {
//             _botResponse = displayText;
//             _multipleOptions = [];
//           });
//         }

//         // ✅ Speak only the answer part (responseText) if audio is enabled
//         if (_audioEnabled && !_isPaused) {
//           setState(() => _isBotSpeaking = true);
//           await _flutterTts.speak(responseText);
//           setState(() => _isBotSpeaking = false);
//         }
//       } else {
//         responseText = "Error: Server returned ${response.statusCode}";
//         setState(() => _botResponse = responseText);
//         if (_audioEnabled && !_isPaused) {
//           setState(() => _isBotSpeaking = true);
//           await _flutterTts.speak(responseText);
//           setState(() => _isBotSpeaking = false);
//         }
//       }
//     } catch (e) {
//       debugPrint("Error sending voice text: $e");
//       responseText = "Sorry, there was an error connecting to the server.";
//       setState(() => _botResponse = responseText);
//       if (_audioEnabled && !_isPaused) {
//         setState(() => _isBotSpeaking = true);
//         await _flutterTts.speak(responseText);
//         setState(() => _isBotSpeaking = false);
//       }
//     } finally {
//       setState(() => _isLoadingResponse = false);
//       // ✅ Auto-restart listening ONLY if mic wasn't manually closed
//       if (!_isPaused && !_micManuallyClosed) {
//         await Future.delayed(const Duration(seconds: 1));
//         await _startListening();
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       color: const Color(0xFFF0F4FF),
//       child: Column(
//         children: [
//           // App bar with transcription toggle
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//             decoration: const BoxDecoration(
//               color: Colors.white,
//               border: Border(
//                 bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
//               ),
//             ),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               children: [
//                 const Text(
//                   "Voice Chat",
//                   style: TextStyle(
//                     fontSize: 16,
//                     fontWeight: FontWeight.w600,
//                     color: Colors.black87,
//                   ),
//                 ),
//                 // ✅ Transcription toggle (top-right)
//                 GestureDetector(
//                   onTap: () {
//                     setState(() => _showTranscription = !_showTranscription);
//                   },
//                   child: Container(
//                     padding: const EdgeInsets.all(8),
//                     decoration: BoxDecoration(
//                       color: _showTranscription
//                           ? const Color(0xFF2B7BBD)
//                           : const Color(0xFFE0E0E0),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: Icon(
//                       Icons.subtitles,
//                       color:
//                           _showTranscription ? Colors.white : Colors.grey[600],
//                       size: 20,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // Main content
//           Expanded(
//             child: SingleChildScrollView(
//               child: Column(
//                 children: [
//                   const SizedBox(height: 40),

//                   // Video animation (looping)
//                   if (_videoController.value.isInitialized)
//                     Container(
//                       width: 200,
//                       height: 200,
//                       decoration: BoxDecoration(
//                         borderRadius: BorderRadius.circular(150),
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.blue.withOpacity(0.2),
//                             blurRadius: 20,
//                             spreadRadius: 5,
//                           ),
//                         ],
//                       ),
//                       child: ClipOval(
//                         child: VideoPlayer(_videoController),
//                       ),
//                     )
//                   else
//                     Container(
//                       width: 200,
//                       height: 200,
//                       decoration: BoxDecoration(
//                         color: Colors.grey[300],
//                         borderRadius: BorderRadius.circular(150),
//                       ),
//                       child: const Center(
//                         child: CircularProgressIndicator(),
//                       ),
//                     ),

//                   const SizedBox(height: 40),

//                   // ✅ Show both user and bot transcriptions clearly labeled
//                   if (_showTranscription)
//                     Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 24),
//                       child: Column(
//                         children: [
//                           // ✅ User transcription (YOU label)
//                           if (_recognizedText.isNotEmpty)
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 16, vertical: 12),
//                               decoration: BoxDecoration(
//                                 color: const Color(0xFFE3F2FD),
//                                 borderRadius: BorderRadius.circular(12),
//                                 border: Border.all(
//                                   color: const Color(0xFF2B7BBD),
//                                   width: 1,
//                                 ),
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   const Text(
//                                     "You:",
//                                     style: TextStyle(
//                                       color: Colors.black87,
//                                       fontSize: 13,
//                                       fontWeight: FontWeight.w600,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Text(
//                                     '"$_recognizedText"',
//                                     textAlign: TextAlign.start,
//                                     style: const TextStyle(
//                                       color: Colors.black87,
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w400,
//                                       fontStyle: FontStyle.italic,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),

//                           const SizedBox(height: 16),

//                           // ✅ Bot transcription (NIVI label)
//                           if (_botResponse.isNotEmpty)
//                             Container(
//                               padding: const EdgeInsets.symmetric(
//                                   horizontal: 16, vertical: 12),
//                               decoration: BoxDecoration(
//                                 color: const Color(0xFFF0F4FF),
//                                 borderRadius: BorderRadius.circular(12),
//                                 border: Border.all(
//                                   color: const Color(0xFFCED7E0),
//                                   width: 1,
//                                 ),
//                               ),
//                               child: Column(
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   const Text(
//                                     "Nivi:",
//                                     style: TextStyle(
//                                       color: Colors.deepPurple,
//                                       fontSize: 13,
//                                       fontWeight: FontWeight.w600,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 4),
//                                   Text(
//                                     _botResponse,
//                                     textAlign: TextAlign.start,
//                                     style: const TextStyle(
//                                       color: Colors.black87,
//                                       fontSize: 14,
//                                       fontWeight: FontWeight.w500,
//                                     ),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                         ],
//                       ),
//                     ),

//                   const SizedBox(height: 24),

//                   // Multiple options (horizontal scroll)
//                   if (_multipleOptions.isNotEmpty)
//                     SizedBox(
//                       height: 120,
//                       child: ListView.separated(
//                         scrollDirection: Axis.horizontal,
//                         padding: const EdgeInsets.symmetric(horizontal: 16),
//                         itemCount: _multipleOptions.length,
//                         separatorBuilder: (_, __) => const SizedBox(width: 12),
//                         itemBuilder: (context, index) {
//                           final option = _multipleOptions[index];
//                           return GestureDetector(
//                             onTap: _isPaused
//                                 ? null
//                                 : () {
//                                     debugPrint(
//                                         "Selected option: ${option['name']}");
//                                   },
//                             child: Container(
//                               width: 180,
//                               padding: const EdgeInsets.all(12),
//                               decoration: BoxDecoration(
//                                 color: const Color(0xFFFFF9E6),
//                                 borderRadius: BorderRadius.circular(12),
//                                 border: Border.all(
//                                   color: const Color(0xFF2B7BBD),
//                                   width: 1.5,
//                                 ),
//                               ),
//                               child: Column(
//                                 mainAxisAlignment: MainAxisAlignment.center,
//                                 crossAxisAlignment: CrossAxisAlignment.start,
//                                 children: [
//                                   Text(
//                                     option['name'] ?? "Unknown",
//                                     style: const TextStyle(
//                                       fontWeight: FontWeight.bold,
//                                       fontSize: 15,
//                                     ),
//                                   ),
//                                   const SizedBox(height: 6),
//                                   Text(
//                                     option['account_number'] ?? "",
//                                     style: const TextStyle(fontSize: 13),
//                                   ),
//                                 ],
//                               ),
//                             ),
//                           );
//                         },
//                       ),
//                     ),

//                   const SizedBox(height: 40),
//                 ],
//               ),
//             ),
//           ),

//           // Bottom control buttons
//           Container(
//             padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
//             child: Row(
//               mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//               children: [
//                 // Speaker toggle (audio on/off)
//                 GestureDetector(
//                   onTap: () {
//                     setState(() => _audioEnabled = !_audioEnabled);
//                   },
//                   child: Container(
//                     width: 60,
//                     height: 60,
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       borderRadius: const BorderRadius.horizontal(
//                         left: Radius.circular(24),
//                         right: Radius.circular(24),
//                       ),
//                       border: Border.all(
//                         color: _audioEnabled
//                             ? const Color(0xFF2B7BBD)
//                             : Colors.grey[400]!,
//                         width: 2,
//                       ),
//                     ),
//                     child: Icon(
//                       _audioEnabled ? Icons.volume_up : Icons.volume_off,
//                       color: _audioEnabled
//                           ? const Color(0xFF2B7BBD)
//                           : Colors.grey[400],
//                       size: 28,
//                     ),
//                   ),
//                 ),

//                 // Mic toggle (listening on/off)
//                 GestureDetector(
//                   onTap: () {
//                     if (_isListening) {
//                       // ✅ Close mic manually - don't auto-open
//                       _closeMicManually();
//                     } else if (!_isPaused && !_micManuallyClosed) {
//                       // Only open if not paused and not manually closed
//                       _startListening();
//                     } else if (!_isPaused && _micManuallyClosed) {
//                       // If manually closed, allow user to manually open again
//                       setState(() {
//                         _micManuallyClosed = false;
//                       });
//                       _startListening();
//                     }
//                   },
//                   child: Container(
//                     width: 60,
//                     height: 60,
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       shape: BoxShape.circle,
//                       border: Border.all(
//                         color: _isListening
//                             ? const Color(0xFF2B7BBD)
//                             : Colors.grey[400]!,
//                         width: 2,
//                       ),
//                     ),
//                     child: Icon(
//                       _isListening ? Icons.mic : Icons.mic_off,
//                       color: _isListening
//                           ? const Color(0xFF2B7BBD)
//                           : Colors.grey[400],
//                       size: 28,
//                     ),
//                   ),
//                 ),

//                 // Pause/Resume toggle
//                 GestureDetector(
//                   onTap: () {
//                     if (_isPaused) {
//                       _resumeConversation();
//                     } else {
//                       _pauseConversation();
//                     }
//                   },
//                   child: Container(
//                     width: 60,
//                     height: 60,
//                     decoration: BoxDecoration(
//                       color: Colors.white,
//                       shape: BoxShape.circle,
//                       border: Border.all(
//                         color: _isPaused
//                             ? const Color(0xFF2B7BBD)
//                             : Colors.grey[400]!,
//                         width: 2,
//                       ),
//                     ),
//                     child: Icon(
//                       _isPaused ? Icons.play_arrow : Icons.pause,
//                       color: _isPaused
//                           ? const Color(0xFF2B7BBD)
//                           : Colors.grey[400],
//                       size: 28,
//                     ),
//                   ),
//                 ),

//                 // ✅ Close button (return to chat) - properly stops all audio and speech
//                 GestureDetector(
//                   onTap: () {
//                     _speech.stop();
//                     _flutterTts.stop();
//                     _silenceTimer?.cancel();
//                     widget.onClose();
//                   },
//                   child: Container(
//                     width: 60,
//                     height: 60,
//                     decoration: BoxDecoration(
//                       color: const Color(0xFFFFEBEE),
//                       shape: BoxShape.circle,
//                       border: Border.all(
//                         color: Colors.grey,
//                         width: 2,
//                       ),
//                     ),
//                     child: const Icon(
//                       Icons.close,
//                       color: Color(0xFFD32F2F),
//                       size: 28,
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }

// flutter_frontend_app/lib/widgets/voice_chat_overlay.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:video_player/video_player.dart';
import '../utils/logger.dart';

final logger = Logger("VoiceChatOverlay");

class VoiceChatOverlay extends StatefulWidget {
  final VoidCallback onClose;

  const VoiceChatOverlay({super.key, required this.onClose});

  @override
  State<VoiceChatOverlay> createState() => _VoiceChatOverlayState();
}

class _VoiceChatOverlayState extends State<VoiceChatOverlay> {
  late final stt.SpeechToText _speech;
  late final FlutterTts _flutterTts;
  late final VideoPlayerController _videoController;

  bool _isListening = false;
  bool _isLoadingResponse = false;
  bool _isBotSpeaking = false;
  bool _showTranscription = true; // Top-right toggle: default ON
  bool _audioEnabled = true; // Speaker toggle: default ON (enabled)
  bool _isPaused = false; // Pause state: default OFF (playing)

  String _recognizedText = ""; // User speech
  String _botResponse = ""; // Bot response (full text for display)
  String _botTtsText = ""; // Text being spoken by TTS (displayed)

  Timer? _silenceTimer;
  List<Map<String, dynamic>> _multipleOptions = [];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _flutterTts = FlutterTts();
    _initializeTtsHandlers();
    _initializeVideo();
    _startListening();
  }

  void _initializeTtsHandlers() {
    // Optional: update UI when TTS starts/completes
    _flutterTts.setStartHandler(() {
      if (mounted) {
        setState(() => _isBotSpeaking = true);
      }
    });
    _flutterTts.setCompletionHandler(() {
      if (mounted) {
        setState(() => _isBotSpeaking = false);
      }
    });
    _flutterTts.setErrorHandler((err) {
      debugPrint("TTS error: $err");
      if (mounted) {
        setState(() => _isBotSpeaking = false);
      }
    });
  }

  void _initializeVideo() {
    _videoController =
        VideoPlayerController.asset('assets/animation_chatbot.mp4')
          ..initialize().then((_) {
            if (mounted) {
              setState(() {});
              _videoController.setLooping(true);
              _videoController.play();
            }
          }).catchError((e) {
            debugPrint('Error initializing video: $e');
          });
  }

  @override
  void dispose() {
    _speech.stop();
    _flutterTts.stop();
    _silenceTimer?.cancel();
    _videoController.dispose();
    super.dispose();
  }

  // Start listening for user speech
  Future<void> _startListening() async {
    if (_isPaused) return;

    bool available = await _speech.initialize(
      onError: (error) => debugPrint("Speech error: $error"),
    );

    if (!mounted) return;

    if (available) {
      setState(() {
        _isListening = true;
        _recognizedText = "";
        _botResponse = "";
        _multipleOptions = [];
        _isBotSpeaking = false;
      });

      _speech.listen(onResult: (result) {
        if (!mounted) return;
        setState(() => _recognizedText = result.recognizedWords);
        _restartSilenceTimer();
      });
    }
  }

  // Stop listening (pause recording) and send text if present
  Future<void> _stopListening() async {
    await _speech.stop();

    if (!mounted) return;

    setState(() => _isListening = false);

    if (_recognizedText.trim().isNotEmpty) {
      await _sendToBackend(_recognizedText);
    }
  }

  // Restart silence timer (3 seconds of silence auto-stops listening)
  void _restartSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 3), () async {
      if (_isListening && !_isPaused) {
        await _stopListening();
      }
    });
  }

  // Pause conversation - interrupt bot and go dormant
  void _pauseConversation() {
    _silenceTimer?.cancel();
    _speech.stop();
    _flutterTts.stop();
    if (mounted) {
      setState(() {
        _isPaused = true;
        _isListening = false;
        _isBotSpeaking = false;
      });
    }
  }

  // Resume conversation after pause
  void _resumeConversation() {
    if (mounted) {
      setState(() => _isPaused = false);
    }
    _startListening();
  }

  // Send recognized text to backend
  Future<void> _sendToBackend(String text) async {
    String responseText = "";
    if (mounted) {
      setState(() {
        _isLoadingResponse = true;
        _botResponse = "";
        _multipleOptions = [];
        _isListening = false;
      });
    }

    try {
      final response = await http.post(
        Uri.parse('http://10.32.2.151:3009/chatbot'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"user_id": "1", "query": text.trim()}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botData = data['response'];

        logger.info("Extracted structured summary for TTS: $responseText");

        if (botData is Map && botData['status'] == "multiple_matches") {
          responseText = botData['message'] ?? "Please select an option.";
          if (mounted) {
            setState(() {
              _botResponse = responseText;
              final rawOptions = botData['options'] ?? [];
              _multipleOptions = List<Map<String, dynamic>>.from(
                (rawOptions is List)
                    ? rawOptions.map((e) => Map<String, dynamic>.from(e))
                    : <Map<String, dynamic>>[],
              );
            });
          }
        } else if (botData.containsKey('answer')) {
          responseText = botData['answer'] ?? botData.toString();
        } else if (botData.containsKey('structured_summary')) {
          final responseUnclear =
              botData['structured_summary']['trend_insights'];
          responseText = responseUnclear.toString();
          logger.info("Extracted structured summary for TTS: $responseText");
        } else {
          responseText = botData is Map
              ? (botData['message'] ?? botData.toString())
              : botData.toString();
          if (mounted) {
            setState(() {
              _botResponse = responseText;
              _multipleOptions = [];
            });
          }
        }

        // Speak response only if audio is enabled and not paused
        if (_audioEnabled && !_isPaused) {
          if (mounted) setState(() => _botTtsText = responseText);
          await _flutterTts.speak(responseText);
        }
      } else {
        responseText = "Error: Server returned ${response.statusCode}";
        if (mounted) setState(() => _botResponse = responseText);
        if (_audioEnabled && !_isPaused) {
          if (mounted) setState(() => _botTtsText = responseText);
          await _flutterTts.speak(responseText);
        }
      }
    } catch (e) {
      debugPrint("Error sending voice text: $e");
      responseText = "Sorry, there was an error connecting to the server.";
      if (mounted) setState(() => _botResponse = responseText);
      if (_audioEnabled && !_isPaused) {
        if (mounted) setState(() => _botTtsText = responseText);
        await _flutterTts.speak(responseText);
      }
    } finally {
      if (mounted) setState(() => _isLoadingResponse = false);

      // Auto-restart listening after response if not paused
      if (!_isPaused) {
        await Future.delayed(const Duration(seconds: 1));
        await _startListening();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF0F4FF),
      child: Column(
        children: [
          // App bar with transcription toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFE0E0E0), width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Voice Chat",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                // Transcription toggle (top-right)
                GestureDetector(
                  onTap: () =>
                      setState(() => _showTranscription = !_showTranscription),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _showTranscription
                          ? const Color(0xFF2B7BBD)
                          : const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.subtitles,
                      color:
                          _showTranscription ? Colors.white : Colors.grey[600],
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // Video animation (looping)
                  if (_videoController.value.isInitialized)
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(150),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.2),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipOval(child: VideoPlayer(_videoController)),
                    )
                  else
                    Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(150),
                      ),
                      child: const Center(child: CircularProgressIndicator()),
                    ),

                  const SizedBox(height: 40),

                  // Show both user and bot transcriptions clearly labeled
                  if (_showTranscription)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          // User transcription (YOU label)
                          if (_recognizedText.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3F2FD),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFF2B7BBD), width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "You:",
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '"$_recognizedText"',
                                    textAlign: TextAlign.start,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 16),

                          // Bot transcription (NIVI label) - Show what TTS is speaking
                          if (_botTtsText.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F4FF),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFFCED7E0), width: 1),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Nivi (Speaking):",
                                    style: TextStyle(
                                      color: Colors.deepPurple,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _botTtsText,
                                    textAlign: TextAlign.start,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 24),

                  // Multiple options (horizontal scroll)
                  if (_multipleOptions.isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _multipleOptions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final option = _multipleOptions[index];
                          return GestureDetector(
                            onTap: _isPaused
                                ? null
                                : () {
                                    debugPrint(
                                        "Selected option: ${option['name']}");
                                    // TODO: wire up selection handling
                                  },
                            child: Container(
                              width: 180,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF9E6),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: const Color(0xFF2B7BBD), width: 1.5),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option['name'] ?? "Unknown",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(option['account_number'] ?? "",
                                      style: const TextStyle(fontSize: 13)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Bottom control buttons
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Speaker toggle (audio on/off)
                GestureDetector(
                  onTap: () => setState(() => _audioEnabled = !_audioEnabled),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(24),
                          right: Radius.circular(24)),
                      border: Border.all(
                          color: _audioEnabled
                              ? const Color(0xFF2B7BBD)
                              : Colors.grey[400]!,
                          width: 2),
                    ),
                    child: Icon(
                      _audioEnabled ? Icons.volume_up : Icons.volume_off,
                      color: _audioEnabled
                          ? const Color(0xFF2B7BBD)
                          : Colors.grey[400],
                      size: 28,
                    ),
                  ),
                ),

                // Mic toggle (listening on/off)
                GestureDetector(
                  onTap: () {
                    if (_isListening) {
                      _stopListening();
                    } else if (!_isPaused) {
                      _startListening();
                    }
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _isListening
                              ? const Color(0xFF2B7BBD)
                              : Colors.grey[400]!,
                          width: 2),
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_off,
                      color: _isListening
                          ? const Color(0xFF2B7BBD)
                          : Colors.grey[400],
                      size: 28,
                    ),
                  ),
                ),

                // Pause/Resume toggle
                GestureDetector(
                  onTap: () {
                    if (_isPaused) {
                      _resumeConversation();
                    } else {
                      _pauseConversation();
                    }
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: _isPaused
                              ? const Color(0xFF2B7BBD)
                              : Colors.grey[400]!,
                          width: 2),
                    ),
                    child: Icon(
                      _isPaused ? Icons.play_arrow : Icons.pause,
                      color: _isPaused
                          ? const Color(0xFF2B7BBD)
                          : Colors.grey[400],
                      size: 28,
                    ),
                  ),
                ),

                // Close button (return to chat) - properly stops all audio and speech
                GestureDetector(
                  onTap: () {
                    _speech.stop();
                    _flutterTts.stop();
                    _silenceTimer?.cancel();
                    widget.onClose();
                  },
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFEBEE),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey, width: 2)),
                    child: const Icon(Icons.close,
                        color: Color(0xFFD32F2F), size: 28),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
