
abstract class ChatMessage {
  final String id;
  ChatMessage({required this.id});
}

// User message
class UserMessage extends ChatMessage {
  final String text;
  UserMessage({required super.id, required this.text});
}

// Bot message can be either text-only OR structured spending
class BotMessage extends ChatMessage {
  final String? text; // plain text message
  final String? title; // structured message title
  final double? totalSpent;
  final Map<String, double>? breakdown;
  final String? spendingTrend;
  final String? summary;
  final Map<String, dynamic>? extraData; // for any additional data

  BotMessage({
    required super.id,
    this.text,
    this.title,
    this.totalSpent,
    this.breakdown,
    this.spendingTrend,
    this.summary,
    this.extraData,
  });
}
