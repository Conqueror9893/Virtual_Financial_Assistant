import 'package:flutter/material.dart';

class ChatInputField extends StatelessWidget {
  final String hintText;
  const ChatInputField({super.key, required this.hintText});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: TextField(
              decoration: InputDecoration(
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
                hintText: "Chat with Appzia", // default hint text
              ),
            ),
          ),
          IconButton(
            iconSize: 28,
            icon: Image.asset(
              'assets/microphone-2.png', // your mic icon asset path
              width: 24,
              height: 24,
              color: const Color(0xFFF87B2D), // color overlay if needed
            ),
            onPressed: () {
              // TODO: Implement voice input functionality
            },
          ),
        ],
      ),
    );
  }
}
