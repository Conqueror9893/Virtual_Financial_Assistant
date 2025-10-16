/// lib/widgets/bot_message_bubble.dart
library;

import 'package:flutter/material.dart';
import 'spending_summary_bubble.dart';
import 'contextual_suggestions.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';
import 'transfer_form.dart';
import '../utils/logger.dart';

final logger = Logger("BotMessageBubble");

class BotMessageBubble extends StatefulWidget {
  final BotMessage message;
  final void Function(String)? onSendMessage; // 👈 Added callback

  const BotMessageBubble({
    super.key,
    required this.message,
    this.onSendMessage,
  });

  @override
  State<BotMessageBubble> createState() => _BotMessageBubbleState();
}

class _BotMessageBubbleState extends State<BotMessageBubble> {
  bool _showForm = false;
  bool _submitted = false;
  double? _finalAmount;
  DateTime? _finalDate;
  String? _beneficiaryName;

  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    logger.info(
        "Rendering bot message: ${message.text}, extraData: ${message.extraData}");

    // 🧾 Transfer form inline
    if (message.text == "[SHOW_TRANSFER_FORM_BUTTON]") {
      final extra = message.extraData ?? {};
      final beneficiaryName =
          extra["beneficiary_name"]?.toString() ?? "Beneficiary";
      final initialAmount =
          (extra["amount"] is num) ? extra["amount"] * 1.0 : 5000.0;

      // Store name locally
      _beneficiaryName ??= beneficiaryName;

      if (_submitted && _finalAmount != null && _finalDate != null) {
        // ✅ Show confirmation card
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "✅ Transfer of USD ${_finalAmount!.toStringAsFixed(0)} $_beneficiaryName "
              "scheduled for ${DateFormat('dd MMM yyyy').format(_finalDate!)}.",
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        );
      }

      // 🧩 Otherwise show form
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!_showForm)
              ElevatedButton.icon(
                icon: const Icon(Icons.account_balance),
                label: const Text("Open Transfer Form"),
                onPressed: () {
                  setState(() => _showForm = true);
                },
              ),
            if (_showForm)
              TransferForm(
                beneficiaryName: beneficiaryName,
                initialAmount: initialAmount,
                onSubmit: (amount, date) {
                  setState(() {
                    _submitted = true;
                    _finalAmount = amount;
                    _finalDate = date;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Transfer of USD $amount scheduled for ${DateFormat('dd MMM yyyy').format(date)}.",
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      );
    }

    // 📊 Spend Insights Summary
    if (message.text == "[SPEND_INSIGHTS_SUMMARY]" &&
        message.extraData != null) {
      return SpendingSummaryBubble(data: message.extraData!);
    }

    // 💡 Contextual suggestions
    if (message.text == "[CONTEXTUAL_QUESTIONS]" &&
        message.extraData?["questions"] != null) {
      final suggestions =
          List<String>.from(message.extraData!["questions"] ?? []);
      return ContextualSuggestions(
        suggestions: suggestions,
        onSuggestionSelected: (selected) {
          logger.info("Contextual suggestion tapped: $selected");
          widget.onSendMessage?.call(selected); // 👈 Calls parent send method
        },
      );
    }

    // 🧠 Default bot message handling...
    if (message.title != null) {
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.title!,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (message.totalSpent != null)
                Text(
                    "Total Spent: USD ${message.totalSpent!.toStringAsFixed(0)}"),
              if (message.breakdown != null)
                ...message.breakdown!.entries.map(
                  (e) => Text("${e.key}: USD ${e.value.toStringAsFixed(0)}"),
                ),
              if (message.spendingTrend != null)
                Text("Trend: ${message.spendingTrend!}"),
              if (message.summary != null) Text("Summary: ${message.summary!}"),
            ],
          ),
        ),
      );
    }

    // 💬 Text-only bot messages (default)
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(message.text ?? ""),
      ),
    );
  }
}
