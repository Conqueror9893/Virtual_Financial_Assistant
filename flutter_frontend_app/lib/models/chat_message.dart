import 'package:flutter/material.dart';

abstract class ChatMessage {
  final String id;
  ChatMessage({required this.id});
}

class UserMessage extends ChatMessage {
  final String text;
  UserMessage({required String id, required this.text}) : super(id: id);
}

class BotMessage extends ChatMessage {
  final String title;
  final double totalSpent;
  final Map<String, double> breakdown;
  final String spendingTrend;
  final String summary;

  BotMessage({
    required String id,
    required this.title,
    required this.totalSpent,
    required this.breakdown,
    required this.spendingTrend,
    required this.summary,
  }) : super(id: id);
}