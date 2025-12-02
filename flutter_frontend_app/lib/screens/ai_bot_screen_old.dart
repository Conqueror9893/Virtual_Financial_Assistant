// flutter_frontend_app/lib/screens/ai_bot_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_frontend_app/widgets/custom_app_bar.dart';
import 'package:flutter_frontend_app/widgets/interactive_bubbles.dart';
import 'package:flutter_frontend_app/widgets/chat_input_field.dart';
import 'package:flutter_frontend_app/widgets/ai_display_data.dart';
import 'package:flutter_frontend_app/models/chat_message.dart';
import 'package:flutter_frontend_app/widgets/suggestion_bar.dart';
import 'package:flutter_frontend_app/widgets/user_message_bubble.dart';
import 'package:flutter_frontend_app/widgets/bot_message_bubble.dart';
import 'package:flutter_frontend_app/widgets/voice_chat_overlay.dart';
import 'package:flutter_frontend_app/widgets/transfer_form.dart';
import 'package:flutter_frontend_app/utils/app_colors.dart';
import 'package:flutter_frontend_app/utils/logger.dart';
import 'package:video_player/video_player.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

final logger = Logger("AiBotScreen");

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
  List<String> _lastContextualQuestions = [];

  // Transfer flow state
  String? _currentPhase;
  String? _pendingRecommendationId;
  String? _pendingBeneficiaryId;

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
    _videoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
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
        _currentBubbles = _bubblesConfig['categories'] as List? ?? [];
        _bubbleStack = [_currentBubbles];
      });
    } catch (e) {
      logger.info('Error loading bubbles config: $e');
    }
  }

  void _startVideoAnimation() {
    if (!_videoInitialized) return;
    _videoController.play();
    _videoAnimationController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
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

  void _onBubbleTap(Map<dynamic, dynamic> bubble) {
    if (bubble.containsKey('subcategories') &&
        (bubble['subcategories'] as List).isNotEmpty) {
      setState(() {
        _currentBubbles = bubble['subcategories'] as List;
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
        _currentBubbles = _bubbleStack.last as List;
      });
      _bubbleAnimationController.reset();
      _bubbleAnimationController.forward();
    }
  }

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
                                if (_showVideo && _videoInitialized)
                                  _buildAnimatedVideo(),
                                const SizedBox(height: 32),
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
                            return BotMessageBubble(
                              message: message,
                              onSendMessage: _sendMessage,
                              onAccountSelected: _handleAccountSelection,
                              onTransferConfirmed: _handleTransferConfirmation,
                              onOtpEntered: _handleOtpEntry,
                              onRecommendationResponse:
                                  _handleRecommendationResponse,
                              onOpenTransferForm: _handleOpenTransferForm,
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    // ✅ NEW: Contextual suggestions bar
                    if (_lastContextualQuestions.isNotEmpty)
                      SuggestionBar(
                        suggestions: _lastContextualQuestions,
                        onSuggestionTap: (q) {
                          _sendMessage(q);
                        },
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

  // Transfer flow handlers
  void _handleAccountSelection(String accountType) {
    _sendMessage(accountType);
  }

  void _handleTransferConfirmation(bool confirmed) {
    _sendMessage(confirmed ? 'yes' : 'no');
  }

  void _handleOtpEntry(String otp) {
    _sendMessage(otp);
  }

  void _handleRecommendationResponse(bool accepted, String? recommendationId) {
    if (accepted) {
      _pendingRecommendationId = recommendationId;
      _sendMessage('yes');
    } else {
      _sendMessage('no');
    }
  }

  void _handleOpenTransferForm(
      String beneficiaryName, String beneficiaryId, double amount) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        // Match the bot screen typical size
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 412, // Typical mobile screen width
              maxHeight: 700, // Leave space for status/app bars
            ),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: TransferForm(
                beneficiaryName: beneficiaryName,
                initialAmount: amount,
                onSubmit:
                    (amount, frequency, installments, remarks, startDate) {
                  logger.info(
                      'Recurring transfer setup: $amount, $frequency, $installments installments, "$remarks", starting $startDate');
                  // You can send this data to backend here
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Recurring transfer of USD ${amount.toStringAsFixed(0)} set up successfully!'),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _inputController.clear();

    setState(() {
      _showGreeting = false;
      _showVideo = false;
      _showBubbles = false;
    });

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
        _handleApiResponse(data);
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

  // void _handleApiResponse(Map<String, dynamic> data) {
  //   final phase = data['phase'] as String?;
  //   final responseData = data['response'] as Map<String, dynamic>?;

  //   if (responseData == null) {
  //     setState(() {
  //       _messages.add(BotMessage(
  //         id: DateTime.now().toIso8601String(),
  //         text: "Unexpected response format from server.",
  //       ));
  //     });
  //     return;
  //   }

  //   setState(() {
  //     _currentPhase = phase;
  //   });

  //   // Handle different phases
  //   if (phase == 'ConversationPhase.ACCOUNT_SELECTION') {
  //     _handleAccountSelectionPhase(responseData);
  //   } else if (phase == 'ConversationPhase.TRANSFER_SUMMARY') {
  //     _handleTransferSummaryPhase(responseData);
  //   } else if (phase == 'ConversationPhase.OTP') {
  //     _handleOtpPhase(responseData);
  //   } else if (phase == 'ConversationPhase.CONFIRMATION') {
  //     _handleConfirmationPhase(responseData);
  //   } else if (phase == 'ConversationPhase.NORMAL') {
  //     logger.info("Handling normal phase response");
  //     logger.info("Response Data: $responseData");

  //     _handleLegacyResponse(responseData);
  //   } else {
  //     // Legacy handling for old response formats
  //     logger.info("Handling legacy response format");
  //     _handleLegacyResponse(responseData);
  //   }
  // }

  void _handleApiResponse(Map<String, dynamic> data) {
    final phase = data['phase'] as String?;
    final responseData = data['response'] as Map<String, dynamic>?;

    if (responseData == null) {
      setState(() {
        _messages.add(BotMessage(
          id: DateTime.now().toIso8601String(),
          text: "Unexpected response format from server.",
        ));
      });
      return;
    }

    setState(() {
      _currentPhase = phase;
    });

    // Handle different phases - with null safety
    if (phase == null || phase == 'ConversationPhase.NORMAL') {
      // Normal phase or no phase - use legacy handler
      logger.info("Handling normal/legacy phase response");
      logger.info("Response Data: $responseData");
      _handleLegacyResponse(responseData);
    } else if (phase == 'ConversationPhase.ACCOUNT_SELECTION') {
      _handleAccountSelectionPhase(responseData);
    } else if (phase == 'ConversationPhase.TRANSFER_SUMMARY') {
      _handleTransferSummaryPhase(responseData);
    } else if (phase == 'ConversationPhase.OTP') {
      _handleOtpPhase(responseData);
    } else if (phase == 'ConversationPhase.CONFIRMATION') {
      _handleConfirmationPhase(responseData);
    } else {
      // Unknown phase - try legacy handler
      logger.info("Unknown phase: $phase, using legacy handler");
      _handleLegacyResponse(responseData);
    }
  }

  void _handleAccountSelectionPhase(Map<String, dynamic> responseData) {
    final message = responseData['message'] as String?;
    final options = (responseData['options'] as List?)?.cast<String>();

    setState(() {
      _messages.add(BotMessage(
        id: DateTime.now().toIso8601String(),
        text: message,
        phase: 'ConversationPhase.ACCOUNT_SELECTION',
        options: options,
      ));
    });
  }

  void _handleTransferSummaryPhase(Map<String, dynamic> responseData) {
    final message = responseData['message'] as String?;
    final summary = responseData['summary'] as Map<String, dynamic>?;

    setState(() {
      _messages.add(BotMessage(
        id: DateTime.now().toIso8601String(),
        text: message,
        phase: 'ConversationPhase.TRANSFER_SUMMARY',
        transferSummary: summary,
      ));
    });
  }

  void _handleOtpPhase(Map<String, dynamic> responseData) {
    final message = responseData['message'] as String?;
    final otpRequired = responseData['otp_required'] as bool? ?? false;

    setState(() {
      _messages.add(BotMessage(
        id: DateTime.now().toIso8601String(),
        text: message,
        phase: 'ConversationPhase.OTP',
        otpRequired: otpRequired,
      ));
    });
  }

  void _handleConfirmationPhase(Map<String, dynamic> responseData) {
    final message = responseData['message'] as String?;
    final amount = responseData['amount'] as num?;
    final beneficiary = responseData['beneficiary'] as String?;
    final timestamp = responseData['timestamp'] as String?;
    final recommendation = responseData['recommendation'] as String?;
    final recommendationId = responseData['recommendation_id'] as String?;

    setState(() {
      _messages.add(BotMessage(
        id: DateTime.now().toIso8601String(),
        text: message,
        phase: 'ConversationPhase.CONFIRMATION',
        transferSummary: {
          'amount': amount,
          'beneficiary': beneficiary,
        },
        timestamp: timestamp,
        recommendation: recommendation,
        recommendationId: recommendationId,
      ));
    });
  }

  // void _handleNormalPhase(Map<String, dynamic> responseData) {
  //   final message = responseData['message'] as String?;
  //   final action = responseData['action'] as String?;
  //   final beneficiaryId = responseData['beneficiary_id'] as String?;
  //   final recommendationId = responseData['recommendation_id'] as String?;

  //   setState(() {
  //     _messages.add(BotMessage(
  //       id: DateTime.now().toIso8601String(),
  //       text: message,
  //       phase: 'ConversationPhase.NORMAL',
  //       action: action,
  //       beneficiaryId: beneficiaryId,
  //       recommendationId: recommendationId,
  //     ));
  //   });
  // }

  // void _handleLegacyResponse(Map<String, dynamic> responseData) {
  //   // Handle old response format for backward compatibility
  //   final botResponse = responseData['response'] ?? responseData;

  //   if (botResponse is String) {
  //     setState(() {
  //       _messages.add(BotMessage(
  //         id: DateTime.now().toIso8601String(),
  //         text: botResponse,
  //       ));
  //     });
  //   } else if (botResponse is Map && botResponse.containsKey('answer')) {
  //     final answer = botResponse['answer'] ?? '';
  //     final sources = (botResponse['sources'] as List?) ?? [];
  //     String displayText = answer;
  //     if (sources.isNotEmpty) {
  //       displayText += '\n\n';
  //       for (var src in sources) {
  //         final file = src['file'] ?? '';
  //         final link = src['link'] ?? '';
  //         displayText += '[$file]($link)\n\n';
  //       }
  //     }
  //     setState(() {
  //       _messages.add(BotMessage(
  //         id: DateTime.now().toIso8601String(),
  //         text: displayText.trim(),
  //       ));
  //     });
  //   } else if (botResponse is Map &&
  //       botResponse.containsKey('breakdown_merchants')) {
  //     final summary = botResponse;
  //     setState(() {
  //       _messages.add(BotMessage(
  //         id: "spend_summary_${DateTime.now().toIso8601String()}",
  //         text: "[SPEND_INSIGHTS_SUMMARY]",
  //         extraData: {
  //           "summary_title": summary["summary_title"],
  //           "total_spent": summary["total_spent"],
  //           "chart_data": summary["chart_data"],
  //           "breakdown_merchants": summary["breakdown_merchants"],
  //           "trend_insights": summary["trend_insights"],
  //         },
  //       ));
  //     });
  //   } else if (botResponse is Map &&
  //       botResponse.containsKey('recommendation')) {
  //     final message = botResponse['message']?.toString() ?? '';
  //     final recommendation = botResponse['recommendation']?.toString();

  //     if (message.isNotEmpty) {
  //       setState(() {
  //         _messages.add(BotMessage(
  //           id: DateTime.now().toIso8601String(),
  //           text: message,
  //         ));
  //       });
  //     }

  //     if (recommendation != null && recommendation.isNotEmpty) {
  //       setState(() {
  //         _messages.add(BotMessage(
  //           id: "recommendation_${DateTime.now().toIso8601String()}",
  //           text: recommendation,
  //           extraData: {
  //             "recommendation_id": botResponse['recommendation_id'],
  //           },
  //         ));
  //       });
  //     }
  //   }

  //   // Handle contextual questions
  //   if (responseData['contextual_questions'] != null &&
  //       responseData['contextual_questions'] is List) {
  //     final List<String> questions =
  //         List<String>.from(responseData['contextual_questions']);
  //     setState(() {
  //       _messages.add(BotMessage(
  //         id: "contextual_${DateTime.now().toIso8601String()}",
  //         text: "[CONTEXTUAL_QUESTIONS]",
  //         extraData: {"questions": questions},
  //       ));
  //     });
  //   }
  // }

  void _handleLegacyResponse(Map<dynamic, dynamic> responseData) {
    // Handle old response format for backward compatibility

    // Check if this is a spending summary response (nested in structured_summary)
    if (responseData.containsKey('structured_summary') &&
        responseData['structured_summary'] is Map) {
      _handleSpendingSummaryResponse(responseData);
      return;
    }

    final botResponse = responseData['response'] ?? responseData;

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
        botResponse.containsKey('breakdown_merchants')) {
      // Old format spending summary (for backward compatibility)
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
    } else if (botResponse is Map &&
        botResponse.containsKey('recommendation')) {
      final message = botResponse['message']?.toString() ?? '';
      final recommendation = botResponse['recommendation']?.toString();
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
    } else {
      // Fallback for unknown format
      setState(() {
        _messages.add(BotMessage(
          id: DateTime.now().toIso8601String(),
          text: "Unexpected response format from server.",
        ));
      });
    }

    // Handle contextual questions (can be at root or nested)
    final contextualQuestions = responseData['contextual_questions'] ??
        botResponse['contextual_questions'];
    if (contextualQuestions != null && contextualQuestions is List) {
      final List<String> questions = List<String>.from(contextualQuestions);
      setState(() {
        _lastContextualQuestions = questions.cast<String>();
      });
    }
  }

// New method to handle spending summary responses
  void _handleSpendingSummaryResponse(Map<dynamic, dynamic> responseData) {
    final structuredSummary = responseData['structured_summary'] as Map;
    final details = responseData['details'] as Map?;

    // Extract data from structured_summary
    final summaryTitle =
        structuredSummary['summary_title']?.toString() ?? 'Spending Summary';
    final totalSpent =
        structuredSummary['total_spent']?.toString() ?? 'USD 0.00';
    final chartData = structuredSummary['chart_data'] as List? ?? [];
    final breakdownMerchants =
        structuredSummary['breakdown_merchants'] as List? ?? [];
    final trendInsights = structuredSummary['trend_insights'] as List? ?? [];

    // Generate friendly message based on category
    final category = details?['category']?.toString() ?? '';
    String friendlyMessage = _generateFriendlyMessage(category, totalSpent);

    setState(() {
      // Add friendly message first
      _messages.add(BotMessage(
        id: DateTime.now().toIso8601String(),
        text: friendlyMessage,
      ));

      // Add spending summary widget
      _messages.add(BotMessage(
        id: "spend_summary_${DateTime.now().toIso8601String()}",
        text: "[SPEND_INSIGHTS_SUMMARY]",
        extraData: {
          "summary_title": summaryTitle,
          "total_spent": totalSpent,
          "chart_data": chartData,
          "breakdown_merchants": breakdownMerchants,
          "trend_insights": trendInsights,
        },
      ));
    });
  }

// Helper method to generate friendly messages based on category
  String _generateFriendlyMessage(String category, String totalSpent) {
    final categoryLower = category.toLowerCase();

    if (categoryLower.contains('coffee')) {
      return 'Looks like you needed your caffeine fix!\nYou spent a total of $totalSpent on coffee.';
    } else if (categoryLower.contains('food') ||
        categoryLower.contains('restaurant')) {
      return 'You\'ve been enjoying some good meals!\nYou spent a total of $totalSpent on dining.';
    } else if (categoryLower.contains('shopping')) {
      return 'Looks like you treated yourself!\nYou spent a total of $totalSpent on shopping.';
    } else if (categoryLower.contains('transport')) {
      return 'You\'ve been on the move!\nYou spent a total of $totalSpent on transportation.';
    } else if (categoryLower.contains('entertainment')) {
      return 'Having fun is important!\nYou spent a total of $totalSpent on entertainment.';
    } else {
      return 'Here\'s your spending summary.\nYou spent a total of $totalSpent on $category.';
    }
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
