import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class BotMessageBubble extends StatelessWidget {
  final BotMessage message;

  const BotMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    // If structured message exists
    if (message.title != null) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message.title!, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (message.totalSpent != null)
                Text("Total Spent: ₹${message.totalSpent!.toStringAsFixed(0)}"),
              if (message.breakdown != null)
                ...message.breakdown!.entries
                    .map((e) => Text("${e.key}: ₹${e.value.toStringAsFixed(0)}"))
                    .toList(),
              if (message.spendingTrend != null)
                Text("Trend: ${message.spendingTrend!}"),
              if (message.summary != null)
                Text("Summary: ${message.summary!}"),
            ],
          ),
        ),
      );
    }

    // Otherwise show text-only
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(message.text ?? ""),
      ),
    );
  }
}
