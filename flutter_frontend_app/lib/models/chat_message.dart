// // flutter_frontend_app/lib/models/chat_message.dart
// abstract class ChatMessage {
//   final String id;
//   ChatMessage({required this.id});
// }

// // User message
// class UserMessage extends ChatMessage {
//   final String text;
//   UserMessage({required String id, required this.text}) : super(id: id);
// }

// // Bot message can be either text-only OR structured spending
// class BotMessage extends ChatMessage {
//   final String? text; // plain text message
//   final String? title; // structured message title
//   final double? totalSpent;
//   final Map<String, double>? breakdown;
//   final String? spendingTrend;
//   final String? summary;
//   final Map<String, dynamic>? extraData; // for any additional data

//   BotMessage({
//     required String id,
//     this.text,
//     this.title,
//     this.totalSpent,
//     this.breakdown,
//     this.spendingTrend,
//     this.summary,
//     this.extraData,
//   }) : super(id: id);
// }


// flutter_frontend_app/lib/models/chat_message.dart

abstract class ChatMessage {
  final String id;
  ChatMessage({required this.id});
}

// User message
class UserMessage extends ChatMessage {
  final String text;
  UserMessage({required String id, required this.text}) : super(id: id);
}

// Bot message can be either text-only OR structured spending OR transfer flow
class BotMessage extends ChatMessage {
  final String? text; // plain text message
  final String? title; // structured message title
  final double? totalSpent;
  final Map<String, dynamic>? breakdown;
  final String? spendingTrend;
  final String? summary;
  final Map<String, dynamic>? extraData; // for any additional data
  
  // Transfer flow specific fields
  final String? phase; // ConversationPhase
  final List<String>? options; // For account selection
  final Map<String, dynamic>? transferSummary; // Summary data
  final bool? otpRequired;
  final String? recommendation;
  final String? recommendationId;
  final String? timestamp;
  final String? action; // For showing transfer form
  final String? beneficiaryId;

  BotMessage({
    required String id,
    this.text,
    this.title,
    this.totalSpent,
    this.breakdown,
    this.spendingTrend,
    this.summary,
    this.extraData,
    this.phase,
    this.options,
    this.transferSummary,
    this.otpRequired,
    this.recommendation,
    this.recommendationId,
    this.timestamp,
    this.action,
    this.beneficiaryId,
  }) : super(id: id);
}
