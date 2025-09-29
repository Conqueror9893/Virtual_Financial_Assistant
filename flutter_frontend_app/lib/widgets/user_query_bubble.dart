import 'package:flutter/material.dart';

class UserQueryBubble extends StatelessWidget {
  final String text;

  const UserQueryBubble({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange[200],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.black, fontSize: 16),
      ),
    );
  }
}