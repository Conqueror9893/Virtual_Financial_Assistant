import 'package:flutter/material.dart';
import 'package:flutter_frontend_app/widgets/custom_app_bar.dart';
import 'package:flutter_frontend_app/widgets/interactive_bubbles.dart';
import 'package:flutter_frontend_app/widgets/chat_input_field.dart';
import 'package:flutter_frontend_app/widgets/ai_display_data.dart';
import 'package:flutter_frontend_app/models/chat_message.dart';
import 'package:flutter_frontend_app/widgets/user_message_bubble.dart';
import 'package:flutter_frontend_app/widgets/bot_message_bubble.dart';
import 'package:flutter_frontend_app/widgets/voice_chat_overlay.dart';
import 'package:flutter_frontend_app/utils/app_colors.dart';
import 'package:video_player/video_player.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

class AiBotScreen extends StatefulWidget {
  final AiDisplayData displayData;
  final VoidCallback? onClose;

  const AiBotScreen({super.key, required this.displayData, this.onClose});

  @override
  State<AiBotScreen> createState() => _AiBotScreenState();
}

class _AiBotScreenState extends State<AiBotScreen>
    with TickerProviderStateMixin {
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();

  bool _showGreeting = true;
  String _mode = "chat"; // "chat" or "voice"
  late VideoPlayerController _videoController;
  late AnimationController _videoAnimationController;
  late AnimationController _videoMoveUpController;
  late AnimationController _bubbleAnimationController;
  late stt.SpeechToText _speech;

  bool _videoInitialized = false;
  bool _showVideo = true;
  bool _showBubbles = false;
  bool _isMicListening = false;
  List<dynamic> _currentBubbles = [];
  List<dynamic> _bubbleStack = [];
  Map<String, dynamic> _bubblesConfig = {};

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initializeVideo();
    _loadBubblesConfig();
    _setupAnimations();
  }

  void _initializeVideo() {
    _videoController = VideoPlayerController.asset(
      'assets/animation_chatbot.mp4',
    )..initialize().then((_) {
        setState(() {
          _videoInitialized = true;
        });
        _videoController.setLooping(true);
        _startVideoAnimation();
      }).catchError((e) {
        logger.info('Error initializing video: $e');
      });
  }

  void _setupAnimations() {
    // Scale animation: 10x → 1x (quick, 500ms)
    _videoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Move up animation: after scale finishes
    _videoMoveUpController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _bubbleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  Future<void> _loadBubblesConfig() async {
    try {
      final String jsonString = await DefaultAssetBundle.of(context)
          .loadString('assets/bubbles_config.json');
      setState(() {
        _bubblesConfig = json.decode(jsonString);
        _currentBubbles = _bubblesConfig['categories'] as List<dynamic>? ?? [];
        _bubbleStack = [_currentBubbles];
      });
    } catch (e) {
      logger.info('Error loading bubbles config: $e');
    }
  }

  void _startVideoAnimation() {
    if (!_videoInitialized) return;

    _videoController.play();

    // Phase 1: Scale from 10x → 1x (500ms)
    _videoAnimationController.forward().then((_) {
      // Phase 2: Hold for 1.5 seconds
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          // Phase 3: Move up (400ms)
          _videoMoveUpController.forward().then((_) {
            if (mounted) {
              setState(() {
                _showBubbles = true;
              });
              _bubbleAnimationController.forward();
            }
          });
        }
      });
    });
  }

  void _onBubbleTap(Map<String, dynamic> bubble) {
    if (bubble.containsKey('subcategories') &&
        (bubble['subcategories'] as List<dynamic>).isNotEmpty) {
      setState(() {
        _currentBubbles = bubble['subcategories'] as List<dynamic>;
        _bubbleStack.add(_currentBubbles);
      });
      _bubbleAnimationController.reset();
      _bubbleAnimationController.forward();
    } else if (bubble.containsKey('query')) {
      _sendMessage(bubble['query'] as String);
    }
  }

  void _onBubbleBack() {
    if (_bubbleStack.length > 1) {
      setState(() {
        _bubbleStack.removeLast();
        _currentBubbles = _bubbleStack.last as List<dynamic>;
      });
      _bubbleAnimationController.reset();
      _bubbleAnimationController.forward();
    }
  }

  // Mic button: Voice-to-text only (fills input field)
  Future<void> _onMicPressed() async {
    if (_isMicListening) {
      await _speech.stop();
      setState(() {
        _isMicListening = false;
      });
    } else {
      bool available = await _speech.initialize(
        onError: (error) => logger.info("Speech error: $error"),
      );

      if (available) {
        setState(() {
          _isMicListening = true;
        });

        _speech.listen(
          onResult: (result) {
            setState(() {
              _inputController.text = result.recognizedWords;
            });
          },
        );

        // Auto-stop after 5 seconds of silence
        Timer(const Duration(seconds: 5), () {
          if (_isMicListening && mounted) {
            _speech.stop();
            setState(() {
              _isMicListening = false;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const double fixedWidth = 412;
    const double fixedHeight = 844;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          children: [
            Positioned(
              right: 16,
              bottom: 16,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * 0.9,
                  maxHeight: constraints.maxHeight * 0.9,
                ),
                child: FittedBox(
                  alignment: Alignment.bottomRight,
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: fixedWidth,
                    height: fixedHeight,
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.hardEdge,
                      child: _buildChatContainer(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChatContainer() {
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.displayData.title,
        onClose: widget.onClose,
        mode: _mode,
        onModeChanged: (val) {
          setState(() {
            _mode = val;
            // If switching to voice, hide chat input
            // If switching to chat, close voice overlay
          });
        },
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.gradientTop,
              AppColors.gradientBottom,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.33],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Chat view (shown when mode == "chat")
              if (_mode == "chat")
                Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24.0, vertical: 16),
                        itemCount: _showGreeting ? 1 : _messages.length,
                        itemBuilder: (context, index) {
                          if (_showGreeting) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 16),
                                // Video with animation
                                if (_showVideo && _videoInitialized)
                                  _buildAnimatedVideo(),
                                const SizedBox(height: 32),
                                // Greeting text
                                Text(
                                  'Hi I am ${widget.displayData.botName},',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'How Can I Help You?',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Bubbles with animation
                                if (_showBubbles && _currentBubbles.isNotEmpty)
                                  ScaleTransition(
                                    scale: Tween<double>(begin: 0.8, end: 1.0)
                                        .animate(_bubbleAnimationController),
                                    child: InteractiveBubbles(
                                      bubbles: _currentBubbles
                                          .cast<Map<String, dynamic>>(),
                                      onBubbleTap: _onBubbleTap,
                                      onBackTap: _onBubbleBack,
                                      showBackButton: _bubbleStack.length > 1,
                                    ),
                                  ),
                                const SizedBox(height: 16),
                              ],
                            );
                          }

                          final message = _messages[index];

                          if (message is UserMessage) {
                            return UserMessageBubble(text: message.text);
                          } else if (message is BotMessage) {
                            return BotMessageBubble(message: message);
                          }

                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    ChatInputField(
                      hintText: widget.displayData.inputHint,
                      onSendMessage: _sendMessage,
                      onMicPressed: _onMicPressed,
                      inputController: _inputController,
                      isMicListening: _isMicListening,
                    ),
                  ],
                ),

              // Voice overlay (shown when mode == "voice")
              if (_mode == "voice")
                VoiceChatOverlay(
                  onClose: () {
                    setState(() {
                      _mode = "chat";
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedVideo() {
    return Center(
      child: AnimatedBuilder(
        animation: Listenable.merge(
            [_videoAnimationController, _videoMoveUpController]),
        builder: (context, child) {
          final scaleValue = _videoAnimationController.value;
          final scale = 10.0 - (scaleValue * 9.0);
          final moveUp = _videoMoveUpController.value * 10.0;

          return Transform.translate(
            offset: Offset(0, -moveUp),
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: 120,
                height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryAccent,
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: VideoPlayer(_videoController),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // Clear input field
    _inputController.clear();

    // Hide greeting and video
    setState(() {
      _showGreeting = false;
      _showVideo = false;
      _showBubbles = false;
    });

    // Detect OTP
    final isOtp = RegExp(r'^\d{4,8}$').hasMatch(text.trim());
    final displayText = isOtp ? '*' * text.trim().length : text.trim();

    final userMessage = UserMessage(
      id: DateTime.now().toIso8601String(),
      text: displayText,
    );

    setState(() {
      _messages.add(userMessage);
    });
    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('http://10.32.2.151:3009/chatbot'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "user_id": "1",
          "query": text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final botResponse = data['response'] is Map
            ? (data['response']['response'] ?? data['response'])
            : data['response'];

        if (botResponse is String) {
          setState(() {
            _messages.add(BotMessage(
              id: DateTime.now().toIso8601String(),
              text: botResponse,
            ));
          });
        } else if (botResponse is Map && botResponse.containsKey('answer')) {
          final answer = botResponse['answer'] ?? '';
          final sources = (botResponse['sources'] as List?) ?? [];

          String displayText = answer;
          if (sources.isNotEmpty) {
            displayText += '\n\n';
            for (var src in sources) {
              final file = src['file'] ?? '';
              final link = src['link'] ?? '';
              displayText += '[$file]($link)\n\n';
            }
          }

          setState(() {
            _messages.add(BotMessage(
              id: DateTime.now().toIso8601String(),
              text: displayText.trim(),
            ));
          });
        } else if (botResponse is Map &&
            botResponse.containsKey('recommendation')) {
          final message = botResponse['message']?.toString() ?? '';
          final recommendation = botResponse['recommendation']?.toString();
          final showForm = botResponse['show_transfer_form'] == true;

          if (message.isNotEmpty) {
            setState(() {
              _messages.add(BotMessage(
                id: DateTime.now().toIso8601String(),
                text: message,
              ));
            });
          }

          if (recommendation != null && recommendation.isNotEmpty) {
            setState(() {
              _messages.add(BotMessage(
                id: "recommendation_${DateTime.now().toIso8601String()}",
                text: recommendation,
                extraData: {
                  "recommendation_id": botResponse['recommendation_id'],
                },
              ));
            });
          }

          if (botResponse['breakdown_merchants'] != null) {
            final summary = botResponse;
            setState(() {
              _messages.add(BotMessage(
                id: "spend_summary_${DateTime.now().toIso8601String()}",
                text: "[SPEND_INSIGHTS_SUMMARY]",
                extraData: {
                  "summary_title": summary["summary_title"],
                  "total_spent": summary["total_spent"],
                  "chart_data": summary["chart_data"],
                  "breakdown_merchants": summary["breakdown_merchants"],
                  "trend_insights": summary["trend_insights"],
                },
              ));
            });
          }

          if (showForm) {
            final beneficiary =
                botResponse['beneficiary_name']?.toString() ?? '';
            final amount =
                double.tryParse(botResponse['amount']?.toString() ?? '') ?? 0.0;

            setState(() {
              _messages.add(BotMessage(
                id: "transfer_form_button_${DateTime.now().toIso8601String()}",
                text: "[SHOW_TRANSFER_FORM_BUTTON]",
                extraData: {
                  "beneficiary_name": beneficiary,
                  "amount": amount,
                },
              ));
            });
          }

          if (botResponse['contextual_questions'] != null &&
              botResponse['contextual_questions'] is List) {
            final List<String> questions =
                List<String>.from(botResponse['contextual_questions']);

            setState(() {
              _messages.add(BotMessage(
                id: "contextual_${DateTime.now().toIso8601String()}",
                text: "[CONTEXTUAL_QUESTIONS]",
                extraData: {"questions": questions},
              ));
            });
          }
        } else {
          setState(() {
            _messages.add(BotMessage(
              id: DateTime.now().toIso8601String(),
              text: "Unexpected response format from server.",
            ));
          });
        }
      } else {
        setState(() {
          _messages.add(
            BotMessage(
              id: DateTime.now().toIso8601String(),
              text: "Error: Server returned ${response.statusCode}",
            ),
          );
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(
          BotMessage(
            id: DateTime.now().toIso8601String(),
            text: "Error: Failed to connect to server.\n$e",
          ),
        );
      });
    }

    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    _videoAnimationController.dispose();
    _videoMoveUpController.dispose();
    _bubbleAnimationController.dispose();
    _scrollController.dispose();
    _inputController.dispose();
    _speech.stop();
    super.dispose();
  }
}
