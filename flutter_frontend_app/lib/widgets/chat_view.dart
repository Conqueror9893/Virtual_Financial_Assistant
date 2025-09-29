import 'package:flutter/material.dart';
import 'package:flutter_frontend_app/models/message.dart';
import 'package:flutter_frontend_app/widgets/chat_message_list.dart';
import 'package:flutter_frontend_app/widgets/chat_input_field.dart';

class ChatView extends StatelessWidget {
  final List<Message> messages;
  final Function(String) onSendMessage;
  final ScrollController scrollController;
  final String hintText;

  const ChatView({
    super.key,
    required this.messages,
    required this.onSendMessage,
    required this.scrollController,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ChatMessageList(
            messages: messages,
            scrollController: scrollController,
          ),
        ),
        ChatInputField(
          hintText: hintText,
          onSendMessage: onSendMessage,
        ),
      ],
    );
  }
}