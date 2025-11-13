import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

class VoiceChatOverlay extends StatefulWidget {
  final VoidCallback onClose;

  const VoiceChatOverlay({super.key, required this.onClose});

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
  List<Map<String, dynamic>> _multipleOptions = [];

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

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onError: (error) => debugPrint("Speech error: $error"),
    );
    if (available) {
      setState(() {
        _isListening = true;
        _recognizedText = "";
        _botResponse = "";
        _multipleOptions = [];
      });
      _speech.listen(
        onResult: (result) {
          setState(() => _recognizedText = result.recognizedWords);
          _restartSilenceTimer();
        },
      );
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);

    if (_recognizedText.trim().isNotEmpty) {
      await _sendToBackend(_recognizedText);
    }
  }

  void _restartSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 3), () async {
      if (_isListening) await _stopListening();
    });
  }

  Future<void> _sendToBackend(String text) async {
    String responseText = "";
    setState(() {
      _isLoadingResponse = true;
      _botResponse = "";
      _multipleOptions = [];
    });

    try {
      final response = await http.post(
        Uri.parse('http://10.32.2.151:3009/chatbot'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"user_id": "1", "query": text.trim()}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botData = data['response'];

        if (botData is Map && botData['status'] == "multiple_matches") {
          responseText = botData['message'] ?? "Please select an option.";
          setState(() {
            _botResponse = responseText;
            _multipleOptions =
                List<Map<String, dynamic>>.from(botData['options']);
          });
        } else {
          responseText = botData is Map
              ? (botData['message'] ?? botData.toString())
              : botData.toString();
          setState(() {
            _botResponse = responseText;
            _multipleOptions = [];
          });
        }

        await _flutterTts.speak(responseText);
      } else {
        responseText = "Error: Server returned ${response.statusCode}";
        setState(() {
          _botResponse = responseText;
        });
        await _flutterTts.speak(responseText);
      }
    } catch (e) {
      debugPrint("Error sending voice text: $e");
      responseText = "Sorry, there was an error connecting to the server.";
      setState(() {
        _botResponse = responseText;
      });
      await _flutterTts.speak(responseText);
    } finally {
      setState(() {
        _isLoadingResponse = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFEECE2).withOpacity(0.95),
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Text(
            "Speaking to Appzia",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),

          // Display recognized voice text
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

          // Show bot response
          if (_botResponse.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12),
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

          // Multiple beneficiaries horizontal options
          if (_multipleOptions.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _multipleOptions.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final option = _multipleOptions[index];
                  return GestureDetector(
                    onTap: () {
                      debugPrint("Selected beneficiary: ${option['name']}");
                      // Handle selection later
                    },
                    child: Container(
                      width: 180,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color.fromARGB(255, 0, 225, 255), width: 1.5),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option['name'] ?? "Unknown",
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            option['account_number'] ?? "",
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          const Spacer(),

          // GIF just above mic button
          Image.asset(
            'assets/voice_animation.png',
            width: 140,
            height: 140,
            fit: BoxFit.cover,
          ),

          const SizedBox(height: 12),

          // Bottom buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Chat button
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline,
                    color: Colors.grey, size: 36),
                onPressed: () {
                  _speech.stop();
                  widget.onClose();
                },
              ),
              // Mic button
              IconButton(
                icon: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.orange,
                  size: 48,
                ),
                onPressed: _isListening ? _stopListening : _startListening,
              ),
              // Close button
              IconButton(
                icon: const Icon(Icons.close, color: Colors.red, size: 36),
                onPressed: () {
                  _speech.stop();
                  widget.onClose();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
