import 'package:flutter/material.dart';
import 'package:flutter_frontend_app/models/chat_message.dart';

class BotMessageBubble extends StatelessWidget {
  final BotMessage message;
  const BotMessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text('Total spent: ₹${message.totalSpent.toStringAsFixed(2)}'),
          const SizedBox(height: 16),
          const Text(
            'Breakdown by category',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          // Placeholder for the pie chart
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('Pie Chart Placeholder'),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Spending Trend',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(message.spendingTrend),
          const SizedBox(height: 16),
          const Text(
            'Summarise',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(message.summary),
        ],
      ),
    );
  }
}