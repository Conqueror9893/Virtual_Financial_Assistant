import 'package:flutter/material.dart';
import 'package:flutter_frontend_app/models/message.dart';
import 'package:flutter_frontend_app/widgets/bot_message_bubble.dart';
import 'package:flutter_frontend_app/widgets/user_message_bubble.dart';

class ChatMessageList extends StatelessWidget {
  final List<Message> messages;
  final ScrollController scrollController;

  const ChatMessageList({
    super.key,
    required this.messages,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        if (message.isUser) {
          return UserMessageBubble(text: message.text);
        } else {
          // This assumes you have a BotMessageBubble that can take text.
          // You might need to adjust BotMessageBubble to accept a simple text string
          // or create a more generic message bubble.
          return BotMessageBubble(
            message: message,
          );
        }
      },
    );
  }
}