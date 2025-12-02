import 'package:flutter/material.dart';

class UserMessageBubble extends StatelessWidget {
  final String text;
  const UserMessageBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        decoration: const BoxDecoration(
          color: Color(0xFFD2D8EF),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(14.0),
            topRight: Radius.circular(6.0),
            bottomLeft: Radius.circular(14.0),
            bottomRight: Radius.circular(14.0),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.black),
        ),
      ),
    );
  }
}