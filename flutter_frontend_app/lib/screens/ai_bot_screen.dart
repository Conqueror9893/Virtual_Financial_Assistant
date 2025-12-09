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

  // ✅ NEW: Inline transfer form state
  bool _showTransferForm = false;
  String _currentBeneficiaryName = '';
  String _currentBeneficiaryId = '';
  double _currentTransferAmount = 0.0;

  // Loading state
  bool _isLoadingResponse = false;

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

  // Helper getter to check if in transfer flow
  bool get _isInTransferFlow =>
      _currentPhase == 'ConversationPhase.ACCOUNT_SELECTION' ||
      _currentPhase == 'ConversationPhase.TRANSFER_SUMMARY' ||
      _currentPhase == 'ConversationPhase.OTP' ||
      _currentPhase == 'ConversationPhase.CONFIRMATION';

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
                        itemCount: _showGreeting
                            ? 1
                            : _messages.length + (_isLoadingResponse ? 1 : 0),
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

                          // Show loading message if applicable
                          if (_isLoadingResponse && index == _messages.length) {
                            return _buildThinkingMessage();
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
                              onInlineTransferSubmit:
                                  _handleInlineTransferSubmit,
                            );
                          }

                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    // ✅ NEW: Inline Transfer Form (displays here instead of modal)
                    if (_showTransferForm)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        child: _buildInlineTransferForm(),
                      ),
                    // ✅ Show suggestions ONLY when not loading and not in transfer flow
                    if (!_isLoadingResponse &&
                        !_isInTransferFlow &&
                        _lastContextualQuestions.isNotEmpty)
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

  // ✅ NEW: Build inline transfer form widget
  Widget _buildInlineTransferForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Setup Recurring Transfer',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showTransferForm = false;
                    });
                  },
                  child: const Icon(
                    Icons.close,
                    color: Colors.grey,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(color: Colors.grey.withOpacity(0.3)),
            const SizedBox(height: 12),

            // Beneficiary info
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.primaryAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    color: AppColors.bubbleGradientEnd,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Beneficiary',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Mr. Duanmu Huai',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick form preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.2),
                ),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amount: USD 300',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Frequency: Monthly',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Installments: 12',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text( 'Start Date: 03-Dec-2025', style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),),
                  SizedBox(height: 8),
                  Text(
                    'Fill in the details below to set up recurring transfer',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showTransferForm = false;
                      });
                    },
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Cancel'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: Colors.grey),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _openFullTransferForm;
                      
                       ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Recurring transfer of USD 300 set up successfully!'),
                    ),
                  );
                  setState(() {
                        _showTransferForm = false;
                      });
                    },
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: const Text('Submit Form'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.bubbleGradientEnd,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ NEW: Build "Nivi is thinking..." with streaming animation
  Widget _buildThinkingMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _StreamingDots(),
          const SizedBox(width: 12),
          const Text(
            "Nivi is thinking...",
            style: TextStyle(
              fontSize: 15,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ],
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

  void _handleInlineTransferSubmit(double amount, String remarks) {
    final message = "Transfer USD $amount with remarks: $remarks";
    _sendMessage(message);
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

  // ✅ NEW: Handle inline transfer form open
  void _handleOpenTransferForm(
      String beneficiaryName, String beneficiaryId, double amount) {
    setState(() {
      _showTransferForm = true;
      _currentBeneficiaryName = beneficiaryName;
      _currentBeneficiaryId = beneficiaryId;
      _currentTransferAmount = amount;
    });
    // Scroll down to show the form
    Future.delayed(const Duration(milliseconds: 300), () {
      _scrollToBottom();
    });
  }

// ✅ NEW: Open full transfer form (you can keep modal or make full-screen)
  void _openFullTransferForm() {
    // Option 1: Open as modal (keeping existing behavior)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 412,
              maxHeight: 700,
            ),
            child: Material(
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              child: TransferForm(
                beneficiaryName: _currentBeneficiaryName,
                initialAmount: _currentTransferAmount,
                onSubmit:
                    (amount, frequency, installments, remarks, startDate) {
                  logger.info(
                      'Recurring transfer setup: $amount, $frequency, $installments installments, "$remarks", starting $startDate');
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
      // ✅ Set loading to true when sending
      _isLoadingResponse = true;
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
          // ✅ Set loading to false
          _isLoadingResponse = false;
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
        // ✅ Set loading to false
        _isLoadingResponse = false;
      });
    }

    _scrollToBottom();
  }

  void _handleApiResponse(Map<String, dynamic> data) {
    final phase = data['phase'] as String?;
    final responseData = data['response'] as Map<String, dynamic>?;

    if (responseData == null) {
      setState(() {
        _messages.add(BotMessage(
          id: DateTime.now().toIso8601String(),
          text: "Unexpected response format from server.",
        ));
        // ✅ Set loading to false
        _isLoadingResponse = false;
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
      // ✅ Clear contextual questions when in transfer flow
      _lastContextualQuestions = [];
      // ✅ Set loading to false
      _isLoadingResponse = false;
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
      // ✅ Clear contextual questions when in transfer flow
      _lastContextualQuestions = [];
      // ✅ Set loading to false
      _isLoadingResponse = false;
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
      // ✅ Clear contextual questions when in transfer flow
      _lastContextualQuestions = [];
      // ✅ Set loading to false
      _isLoadingResponse = false;
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
      // ✅ Clear contextual questions when in transfer flow
      _lastContextualQuestions = [];
      // ✅ Set loading to false
      _isLoadingResponse = false;
    });
  }

  void _handleLegacyResponse(Map<String, dynamic> responseData) {
    // Handle old response format for backward compatibility
    logger.info("Response Data: $responseData");
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
        // ✅ Set loading to false
        _isLoadingResponse = false;
      });
    } else if (botResponse is Map && botResponse.containsKey('answer')) {
      final answer = botResponse['answer'] ?? '';
      final sources = (botResponse['sources'] as List?) ?? [];
      String displayText = answer;
      // if (sources.isNotEmpty) {
      //   displayText += '\n\n';
      //   for (var src in sources) {
      //     final file = src['file'] ?? '';
      //     final link = src['link'] ?? '';
      //     displayText += '[$file]($link)\n\n';
      //   }
      // }
      setState(() {
        _messages.add(BotMessage(
          id: DateTime.now().toIso8601String(),
          text: displayText.trim(),
        ));
        // ✅ Set loading to false
        _isLoadingResponse = false;
      });
    } else if (botResponse is Map &&
        botResponse.containsKey('breakdown_merchants')) {
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
        // ✅ Set loading to false
        _isLoadingResponse = false;
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
          // ✅ Set loading to false
          _isLoadingResponse = false;
        });
      } else {
        setState(() {
          _isLoadingResponse = false;
        });
      }
    } else if (responseData.containsKey('action') &&
        responseData['action'] == 'show_transfer_form') {
      final String beneficiaryId = responseData['beneficiary_id'] ?? '';
      final String message =
          responseData['message'] ?? 'Setup recurring transfer';
      final String recommendationId = responseData['recommendation_id'] ?? '';

      // Call your existing open transfer form handler
      _handleOpenTransferForm(
        message, // Assuming message contains beneficiary name or text you want to show
        beneficiaryId,
        100.0, // You may adapt this to pass amount if in the response
      );

      setState(() {
        _messages.add(BotMessage(
          id: DateTime.now().toIso8601String(),
          text: message,
          phase: 'ConversationPhase.NORMAL',
          action: 'show_transfer_form',
          beneficiaryId: beneficiaryId,
          recommendationId: recommendationId,
        ));
        _isLoadingResponse = false;
        _lastContextualQuestions = [];
      });
      return; // Important: exit early since transfer form handled
    } else if (responseData.containsKey('action') &&
        responseData['action'] == 'show_inline_transfer_form') {
      final String message =
          responseData['message'] ?? 'Please fill out the form below';
      setState(() {
        _messages.add(BotMessage(
          id: DateTime.now().toIso8601String(),
          text: message,
          phase: 'ConversationPhase.NORMAL',
          action: 'show_inline_transfer_form',
        ));
        _isLoadingResponse = false;
        _lastContextualQuestions = [];
      });
      return;
    } else if (responseData.containsKey('message')) {
      final message = responseData['message']?.toString() ?? '';
      setState(() {
        _messages.add(BotMessage(
          id: DateTime.now().toIso8601String(),
          text: message,
        ));
        // ✅ Set loading to false
        _isLoadingResponse = false;
      });
    } else {
      setState(() {
        _messages.add(BotMessage(
          id: DateTime.now().toIso8601String(),
          text: "Unexpected response format from server.",
        ));
        // ✅ Set loading to false
        _isLoadingResponse = false;
      });
    }
    logger.info("contextual questions check");
    // Handle contextual questions (can be at root or nested)
    final contextualQuestions = responseData['contextual_questions'] ??
        botResponse['contextual_questions'];
    if (contextualQuestions != null && contextualQuestions is List) {
      final List<String> questions = List<String>.from(contextualQuestions);
      setState(() {
        _lastContextualQuestions = questions;
      });
    } else {
      setState(() {
        _lastContextualQuestions = [];
      });
    }
  }

  void _handleSpendingSummaryResponse(Map<String, dynamic> responseData) {
    final structuredSummary = responseData['structured_summary'] as Map;
    final details = responseData['details'] as Map?;

    final summaryTitle =
        structuredSummary['summary_title']?.toString() ?? 'Spending Summary';
    final totalSpent =
        structuredSummary['total_spent']?.toString() ?? 'USD 0.00';
    final chartData = structuredSummary['chart_data'] as List? ?? [];
    final breakdownMerchants =
        structuredSummary['breakdown_merchants'] as List? ?? [];
    final trendInsights = structuredSummary['trend_insights'] as List? ?? [];

    final category = details?['category']?.toString() ?? '';
    String friendlyMessage = _generateFriendlyMessage(category, totalSpent);

    setState(() {
      _messages.add(BotMessage(
        id: DateTime.now().toIso8601String(),
        text: friendlyMessage,
      ));

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
      // ✅ Set loading to false
      _isLoadingResponse = false;
    });
  }

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

// ✅ NEW: Streaming dots animation widget
class _StreamingDots extends StatefulWidget {
  @override
  State<_StreamingDots> createState() => _StreamingDotsState();
}

class _StreamingDotsState extends State<_StreamingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )
      ..addListener(() {
        if (_controller.status == AnimationStatus.completed) {
          _controller.reset();
        }
        setState(() {
          _dotCount = (_controller.value * 3).floor() + 1;
        });
      })
      ..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      child: Text(
        "." * _dotCount,
        style: const TextStyle(
          fontSize: 24,
          color: Colors.blueAccent,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
