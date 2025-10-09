
abstract class ChatMessage {
  final String id;
  ChatMessage({required this.id});
}

// User message
class UserMessage extends ChatMessage {
  final String text;
  UserMessage({required String id, required this.text}) : super(id: id);
}

// Bot message can be either text-only OR structured spending
class BotMessage extends ChatMessage {
  final String? text; // plain text message
  final String? title; // structured message title
  final double? totalSpent;
  final Map<String, double>? breakdown;
  final String? spendingTrend;
  final String? summary;
  final Map<String, dynamic>? extraData;


  BotMessage({
    required String id,
    this.text,
    this.title,
    this.totalSpent,
    this.breakdown,
    this.spendingTrend,
    this.summary,
    this.extraData,
  }) : super(id: id);
}
