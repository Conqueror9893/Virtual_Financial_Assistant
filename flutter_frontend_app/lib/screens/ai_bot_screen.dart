// import 'package:flutter/material.dart';
// import 'package:flutter_frontend_app/widgets/custom_app_bar.dart';
// import 'package:flutter_frontend_app/widgets/bot_avatar_greeting.dart';
// import 'package:flutter_frontend_app/widgets/suggestion_chips.dart';
// import 'package:flutter_frontend_app/widgets/chat_input_field.dart';
// import 'package:flutter_frontend_app/widgets/ai_display_data.dart';
// import 'package:flutter_frontend_app/models/chat_message.dart';
// import 'package:flutter_frontend_app/widgets/user_message_bubble.dart';
// import 'package:flutter_frontend_app/widgets/bot_message_bubble.dart';

// class AiBotScreen extends StatefulWidget {
//   final AiDisplayData displayData;
//   const AiBotScreen({super.key, required this.displayData});

//   @override
//   State<AiBotScreen> createState() => _AiBotScreenState();
// }

// class _AiBotScreenState extends State<AiBotScreen> {
//   final List<ChatMessage> _messages = [];

//   @override
//   Widget build(BuildContext context) {
//     const double fixedWidth = 390;
//     const double fixedHeight = 844;

//     return LayoutBuilder(builder: (context, constraints) {
//       return Stack(
//         children: [
//           Positioned(
//             right: 16,
//             bottom: 16,
//             child: ConstrainedBox(
//               constraints: BoxConstraints(
//                 maxWidth: constraints.maxWidth * 0.9,
//                 maxHeight: constraints.maxHeight * 0.9,
//               ),
//               child: FittedBox(
//                 alignment: Alignment.bottomRight,
//                 fit: BoxFit.contain,
//                 child: SizedBox(
//                   width: fixedWidth,
//                   height: fixedHeight,
//                   child: Material(
//                     elevation: 8,
//                     borderRadius: BorderRadius.circular(16),
//                     clipBehavior: Clip.hardEdge,
//                     child: _buildChatContainer(),
//                   ),
//                 ),
//               ),
//             ),
//           ),
//         ],
//       );
//     });
//   }

//   Widget _buildChatContainer() {
//     return Scaffold(
//       extendBodyBehindAppBar: true,
//       appBar: CustomAppBar(title: widget.displayData.title),
//       body: Container(
//         decoration: BoxDecoration(
//           gradient: LinearGradient(
//             colors: widget.displayData.backgroundGradient,
//             begin: Alignment.topCenter,
//             end: Alignment.bottomCenter,
//             stops: const [0.0, 0.33],
//           ),
//         ),
//         child: SafeArea(
//           child: Column(
//             children: [
//               Expanded(
//                 child: ListView.builder(
//                   padding: const EdgeInsets.symmetric(horizontal: 24.0),
//                   itemCount: _messages.length,
//                   itemBuilder: (context, index) {
//                     final message = _messages[index];
//                     if (message is UserMessage) {
//                       return UserMessageBubble(text: message.text);
//                     }
//                     if (message is BotMessage) {
//                       return BotMessageBubble(message: message);
//                     }
//                     return const SizedBox.shrink();
//                   },
//                 ),
//               ),
//               ChatInputField(
//                 hintText: widget.displayData.inputHint,
//                 onSendMessage: _sendMessage,
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   void _sendMessage(String text) {
//     final userMessage = UserMessage(id: DateTime.now().toString(), text: text);
//     setState(() {
//       _messages.add(userMessage);
//     });

//     // Simulate a bot response
//     Future.delayed(const Duration(seconds: 1), () {
//       final botMessage = BotMessage(
//         id: DateTime.now().toString(),
//         title: 'Monthly spending summary - August 2025',
//         totalSpent: 82450,
//         breakdown: {
//           'Rent': 25000,
//           'Groceries': 12500,
//           'Transport': 6800,
//           'Dining & Food': 5600,
//           'Internet': 1450,
//           'Health': 4500,
//           'EMI': 15400,
//         },
//         spendingTrend:
//             'Paid: ₹4,850 more than July\nMost spent on: Rent\nMost frequent purchases: Groceries',
//         summary: 'Summarise',
//       );
//       setState(() {
//         _messages.add(botMessage);
//       });
//     });
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_frontend_app/widgets/custom_app_bar.dart';
import 'package:flutter_frontend_app/widgets/bot_avatar_greeting.dart';
import 'package:flutter_frontend_app/widgets/suggestion_chips.dart';
import 'package:flutter_frontend_app/widgets/chat_input_field.dart';
import 'package:flutter_frontend_app/widgets/ai_display_data.dart';
import 'package:flutter_frontend_app/models/chat_message.dart';
import 'package:flutter_frontend_app/widgets/user_message_bubble.dart';
import 'package:flutter_frontend_app/widgets/bot_message_bubble.dart';
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
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24.0, vertical: 16),
                  itemCount: _messages.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
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

                    final message = _messages[index - 1];
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
    final userMessage = UserMessage(id: DateTime.now().toString(), text: text);
    setState(() => _messages.add(userMessage));

    try {
      final response = await http.post(
        Uri.parse('http://10.32.2.151:3009/chatbot'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({"user_id": "1", "query": text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Check if the response has structured data
        final botResp = data['response'] ?? data;
        BotMessage botMessage;

        if (botResp['transfer'] != null || botResp['recommendation'] != null) {
          botMessage = BotMessage(
            id: DateTime.now().toString(),
            text: botResp['recommendation'] ?? "Transfer processed",
          );
        } else {
          // Plain text fallback
          botMessage = BotMessage(
            id: DateTime.now().toString(),
            text: botResp.toString(),
          );
        }

        setState(() => _messages.add(botMessage));
      } else {
        setState(() => _messages.add(
              BotMessage(
                id: DateTime.now().toString(),
                text: "Error: ${response.statusCode}",
              ),
            ));
      }
    } catch (e) {
      setState(() => _messages.add(
            BotMessage(
              id: DateTime.now().toString(),
              text: "Error: $e",
            ),
          ));
    }
  }
}
