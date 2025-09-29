import 'package:flutter/material.dart';
import 'package:flutter_frontend_app/models/message.dart';

class BotMessageBubble extends StatelessWidget {
  final Message message;

  const BotMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    if (message.data != null && message.data!['title'] != null) {
      final data = message.data!;
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data['title']!,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (data['totalSpent'] != null)
                Text(
                    "Total Spent: ₹${(data['totalSpent'] as num).toStringAsFixed(0)}"),
              if (data['breakdown'] != null && data['breakdown'] is Map)
                ...(data['breakdown'] as Map<String, dynamic>)
                    .entries
                    .map((e) => Text(
                        "${e.key}: ₹${(e.value as num).toStringAsFixed(0)}"))
                    .toList(),
              if (data['spendingTrend'] != null)
                Text("Trend: ${data['spendingTrend']!}"),
              if (data['summary'] != null) Text("Summary: ${data['summary']!}"),
            ],
          ),
        ),
      );
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(message.text),
      ),
    );
  }
}