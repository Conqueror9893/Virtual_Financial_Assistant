///lib/screens/ai_bot_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_frontend_app/widgets/custom_app_bar.dart';
import 'package:flutter_frontend_app/widgets/bot_avatar_greeting.dart';
import 'package:flutter_frontend_app/widgets/suggestion_chips.dart';
import 'package:flutter_frontend_app/widgets/chat_input_field.dart';
import 'package:flutter_frontend_app/widgets/ai_display_data.dart';
import 'package:flutter_frontend_app/models/chat_message.dart';
import 'package:flutter_frontend_app/widgets/user_message_bubble.dart';
import 'package:flutter_frontend_app/widgets/bot_message_bubble.dart';
import 'package:flutter_frontend_app/widgets/transfer_form.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AiBotScreen extends StatefulWidget {
  final AiDisplayData displayData;
  const AiBotScreen({super.key, required this.displayData});

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

    return LayoutBuilder(builder: (context, constraints) {
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
    });
  }

  Widget _buildChatContainer() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(title: widget.displayData.title),
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
          child: Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16),
                  itemCount:
                      _showGreeting ? _messages.length + 1 : _messages.length,
                  itemBuilder: (context, index) {
                    if (_showGreeting && index == 0) {
                      // Show avatar greeting and suggestion chips at top
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 16),
                          BotAvatarGreeting(displayData: widget.displayData),
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = UserMessage(
      id: DateTime.now().toIso8601String(),
      text: text.trim(),
    );

    setState(() {
      _messages.add(userMessage);
      _showGreeting = false;
    });

    _scrollToBottom();

    try {
      final response = await http.post(
        Uri.parse('http://10.32.2.151:3009/chatbot'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"user_id": "1", "query": text.trim()}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // 🧠 Flatten nested structure
        final botResponse = data['response'] is Map
            ? (data['response']['response'] ?? data['response'])
            : data['response'];

        if (botResponse is String) {
          // 🩵 FIX: Wrap this in setState
          setState(() {
            _messages.add(BotMessage(
              id: DateTime.now().toIso8601String(),
              text: botResponse,
            ));
          });
        } else if (botResponse is Map) {
          final message = botResponse['message']?.toString() ?? '';
          final recommendation = botResponse['recommendation']?.toString();
          final showForm = botResponse['show_transfer_form'] == true;

          // 1️⃣ Add main message
          if (message.isNotEmpty) {
            setState(() {
              _messages.add(BotMessage(
                id: DateTime.now().toIso8601String(),
                text: message,
              ));
            });
          }

          // 2️⃣ Add recommendation as a separate bubble
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

          // 3️⃣ Add transfer form bubble if required
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
          _messages.add(BotMessage(
            id: DateTime.now().toIso8601String(),
            text: "Error: Server returned ${response.statusCode}",
          ));
        });
      }
    } catch (e) {
      setState(() {
        _messages.add(BotMessage(
          id: DateTime.now().toIso8601String(),
          text: "Error: Failed to connect to server.\n$e",
        ));
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
