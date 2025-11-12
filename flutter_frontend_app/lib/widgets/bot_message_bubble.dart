import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_frontend_app/widgets/spending_summary_bubble.dart';
import 'package:flutter_frontend_app/widgets/contextual_suggestions.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';
import '../widgets/transfer_form.dart';
import '../utils/logger.dart';

final logger = Logger("BotMessageBubble");

class BotMessageBubble extends StatefulWidget {
  final BotMessage message;
  final void Function(String)? onSendMessage;

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

      _beneficiaryName ??= beneficiaryName;

      if (_submitted && _finalAmount != null && _finalDate != null) {
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
          widget.onSendMessage?.call(selected);
        },
      );
    }

    // 🧠 Summary message (if title etc.)
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

    // 💬 Default text-only bot messages with clickable links
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: MarkdownBody(
          data: message.text ?? "",
          selectable: true,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            a: const TextStyle(
              color: Colors.blue,
              decoration: TextDecoration.underline,
            ),
            p: const TextStyle(fontSize: 15),
          ),
          onTapLink: (text, href, title) async {
            if (href != null) {
              final uri = Uri.parse(href);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            }
          },
        ),
      ),
    );
  }
}
