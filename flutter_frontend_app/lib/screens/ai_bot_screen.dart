import 'package:flutter/material.dart';
import 'package:flutter_frontend_app/widgets/custom_app_bar.dart';
import 'package:flutter_frontend_app/widgets/bot_avatar_greeting.dart';
import 'package:flutter_frontend_app/widgets/suggestion_chips.dart';
import 'package:flutter_frontend_app/widgets/chat_input_field.dart';
import 'package:flutter_frontend_app/widgets/ai_display_data.dart';
import 'package:flutter_frontend_app/models/chat_message.dart';
import 'package:flutter_frontend_app/widgets/user_message_bubble.dart';
import 'package:flutter_frontend_app/widgets/bot_message_bubble.dart';
import 'package:flutter_frontend_app/widgets/voice_chat_overlay.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AiBotScreen extends StatefulWidget {
  final AiDisplayData displayData;
  final VoidCallback? onClose;

  const AiBotScreen({super.key, required this.displayData, this.onClose});

  @override
  State<AiBotScreen> createState() => _AiBotScreenState();
}

class _AiBotScreenState extends State<AiBotScreen> {
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  
  bool _showGreeting = true;

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

  bool _isVoiceMode = false;

  Widget _buildChatContainer() {
    return Scaffold(
      appBar: CustomAppBar(
        title: widget.displayData.title,
        onClose: widget.onClose,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.displayData.backgroundGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.33],
            
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Chat view
              Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24.0, vertical: 16),
                      itemCount: _showGreeting
                          ? _messages.length + 1
                          : _messages.length,
                      itemBuilder: (context, index) {
                        if (_showGreeting && index == 0) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const SizedBox(height: 16),
                              BotAvatarGreeting(
                                  displayData: widget.displayData),
                              const SizedBox(height: 32),
                              SuggestionChips(
                                  suggestions: widget.displayData.suggestions),
                              const SizedBox(height: 16),
                            ],
                          );
                        }

                        final message =
                            _messages[_showGreeting ? index - 1 : index];

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
                    onMicPressed: _toggleVoiceMode, // <-- toggle overlay
                  ),
                ],
              ),

              // Voice overlay (shown on mic press)
              if (_isVoiceMode)
                Positioned.fill(
                  child: VoiceChatOverlay(
                    onClose: _toggleVoiceMode,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleVoiceMode() {
    setState(() {
      _isVoiceMode = !_isVoiceMode;
    });
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    // 🩵 Detect OTP (e.g. 4-8 digits)
    final isOtp = RegExp(r'^\d{4,8}$').hasMatch(text.trim());

    // 🧠 Mask OTP for UI only
    final displayText = isOtp ? '*' * text.trim().length : text.trim();

    final userMessage = UserMessage(
      id: DateTime.now().toIso8601String(),
      text: displayText, // 👈 Masked for frontend
    );

    setState(() {
      _messages.add(userMessage);
      _showGreeting = false;
    });
    _scrollToBottom();

    try {
      // ✅ Send actual OTP (not masked) to backend
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

        // Flatten bot response
        final botResponse = data['response'] is Map
            ? (data['response']['response'] ?? data['response'])
            : data['response'];

        if (botResponse is String) {
          // Simple text fallback
          setState(() {
            _messages.add(BotMessage(
              id: DateTime.now().toIso8601String(),
              text: botResponse,
            ));
          });
        } else if (botResponse is Map && botResponse.containsKey('answer')) {
          // 🧩 Handle FAQ structured response
          final answer = botResponse['answer'] ?? '';
          final sources = (botResponse['sources'] as List?) ?? [];

          // Combine the answer + sources into formatted text
          String displayText = answer;

          if (sources.isNotEmpty) {
            displayText += '\n\n'; // Add spacing before sources
            for (var src in sources) {
              final file = src['file'] ?? '';
              final link = src['link'] ?? '';

              // Wrap filename as clickable link (Markdown style)
              displayText += '[$file]($link)\n\n';
            }
          }

          setState(() {
            _messages.add(BotMessage(
              id: DateTime.now().toIso8601String(),
              text: displayText.trim(),
            ));
          });
        } else if (botResponse is Map && botResponse.containsKey('recommendation')) {
          final message = botResponse['message']?.toString() ?? '';
          final recommendation = botResponse['recommendation']?.toString();
          final showForm = botResponse['show_transfer_form'] == true;

          // Normal text message
          if (message.isNotEmpty) {
            setState(() {
              _messages.add(BotMessage(
                id: DateTime.now().toIso8601String(),
                text: message,
              ));
            });
          }

          // Recommendation
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

          // Spend insights handling (structured summary)
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

          // Transfer form
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
          // Contextual questions
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

  // Helper function to safely scroll to bottom
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });
  }
}
