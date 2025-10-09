import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';
import '../widgets/transfer_form.dart';

class BotMessageBubble extends StatefulWidget {
  final BotMessage message;

  const BotMessageBubble({super.key, required this.message});

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

    // 🧾 Transfer form inline
    if (message.text == "[SHOW_TRANSFER_FORM_BUTTON]") {
      final extra = message.extraData ?? {};
      final beneficiaryName = extra["beneficiary_name"]?.toString() ?? "Beneficiary";
      final initialAmount = (extra["amount"] is num) ? extra["amount"] * 1.0 : 5000.0;

      // store name locally
      _beneficiaryName ??= beneficiaryName;

      if (_submitted && _finalAmount != null && _finalDate != null) {
        // ✅ Show confirmation card
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          color: Colors.green.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              "✅ Transfer of ₹${_finalAmount!.toStringAsFixed(0)} to $_beneficiaryName "
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
                initialAmount: initialAmount, // we’ll add this param next
                onSubmit: (amount, date) {
                  setState(() {
                    _submitted = true;
                    _finalAmount = amount;
                    _finalDate = date;
                  });

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "Transfer of ₹$amount scheduled for ${DateFormat('dd MMM yyyy').format(date)}.",
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      );
    }

    // Default bot message handling...
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
                Text("Total Spent: ₹${message.totalSpent!.toStringAsFixed(0)}"),
              if (message.breakdown != null)
                ...message.breakdown!.entries.map(
                  (e) => Text("${e.key}: ₹${e.value.toStringAsFixed(0)}"),
                ),
              if (message.spendingTrend != null)
                Text("Trend: ${message.spendingTrend!}"),
              if (message.summary != null)
                Text("Summary: ${message.summary!}"),
            ],
          ),
        ),
      );
    }

    // Text-only bot messages
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Text(message.text ?? ""),
      ),
    );
  }
}
