// flutter_frontend_app/lib/widgets/bot_message_bubble.dart

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_frontend_app/widgets/spending_summary_bubble.dart';
import 'package:flutter_frontend_app/widgets/contextual_suggestions.dart';
import 'package:flutter_frontend_app/widgets/account_selection_card.dart';
import 'package:flutter_frontend_app/widgets/transfer_summary_card.dart';
import 'package:flutter_frontend_app/widgets/transaction_success_card.dart';
import 'package:flutter_frontend_app/widgets/clickable_text_link.dart';
import 'package:intl/intl.dart';
import '../models/chat_message.dart';
import '../utils/logger.dart';

final logger = Logger("BotMessageBubble");

class BotMessageBubble extends StatefulWidget {
  final BotMessage message;
  final void Function(String)? onSendMessage;
  final void Function(String)? onAccountSelected;
  final void Function(bool)? onTransferConfirmed;
  final void Function(String)? onOtpEntered;
  final void Function(bool, String?)? onRecommendationResponse;
  final void Function(String, String, double)? onOpenTransferForm;

  const BotMessageBubble({
    super.key,
    required this.message,
    this.onSendMessage,
    this.onAccountSelected,
    this.onTransferConfirmed,
    this.onOtpEntered,
    this.onRecommendationResponse,
    this.onOpenTransferForm,
  });

  @override
  State<BotMessageBubble> createState() => _BotMessageBubbleState();
}

class _BotMessageBubbleState extends State<BotMessageBubble> {
  @override
  Widget build(BuildContext context) {
    final message = widget.message;
    logger.info(
        "Rendering bot message: phase=${message.phase}, text=${message.text}, action=${message.action}");

    // ✅ CHECK FOR TRANSFER FORM LINK FIRST (highest priority)
    if (message.action == 'show_transfer_form') {
      return _buildTransferFormLink();
    }

    // Handle transfer flow phases
    if (message.phase == 'ConversationPhase.ACCOUNT_SELECTION') {
      return _buildAccountSelection();
    } else if (message.phase == 'ConversationPhase.TRANSFER_SUMMARY') {
      return _buildTransferSummary();
    } else if (message.phase == 'ConversationPhase.CONFIRMATION') {
      return _buildTransactionSuccess();
    }

    // Legacy handlers
    if (message.text == "[SPEND_INSIGHTS_SUMMARY]" &&
        message.extraData != null) {
      return SpendingSummaryBubble(data: message.extraData!);
    }

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

    // ✅ Handle NORMAL phase with null or empty text by showing answer if available
    if (message.phase == 'ConversationPhase.NORMAL') {
      if ((message.text == null || message.text!.trim().isEmpty) &&
          message.extraData != null) {
        String? answer = message.extraData?['answer'] as String?;
        if (answer != null && answer.isNotEmpty) {
          return _buildMarkdownMessage(answer);
        }
      }
    }

    // Default text-only message
    if (message.text != null && message.text!.isNotEmpty) {
      return _buildMarkdownMessage(message.text!);
    }

    // If nothing to display, show empty sized box
    return const SizedBox.shrink();
  }

  // ✅ Extracted helper widget to build markdown text
  Widget _buildMarkdownMessage(String text) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: MarkdownBody(
          data: text,
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

  Widget _buildAccountSelection() {
    final options = widget.message.options ?? [];

    String getPlaceholderAccountNumber(String accountType) {
      if (accountType.toLowerCase() == 'savings') {
        return '****1234';
      } else {
        return '****5678';
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message.text != null)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  widget.message.text!,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          ...options.map((option) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: AccountSelectionCard(
                accountType: option,
                accountNumber: getPlaceholderAccountNumber(option),
                onTap: () {
                  widget.onAccountSelected?.call(option);
                },
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTransferSummary() {
    final summary = widget.message.transferSummary ?? {};
    final amount = (summary['amount'] as num?)?.toDouble() ?? 0.0;
    final fromAccount = summary['from_account'] as String? ?? '';
    final toBeneficiary = summary['to_beneficiary'] as String? ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TransferSummaryCard(
        amount: amount,
        fromAccount: fromAccount,
        toBeneficiary: toBeneficiary,
        onConfirm: () {
          widget.onTransferConfirmed?.call(true);
        },
        onCancel: () {
          widget.onTransferConfirmed?.call(false);
        },
      ),
    );
  }


  Widget _buildTransactionSuccess() {
    final summary = widget.message.transferSummary ?? {};
    final amount = (summary['amount'] as num?)?.toDouble() ?? 0.0;
    final beneficiary = summary['beneficiary'] as String? ?? '';
    final timestamp =
        widget.message.timestamp ?? DateTime.now().toIso8601String();
    final recommendation = widget.message.recommendation;
    final recommendationId = widget.message.recommendationId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TransactionSuccessCard(
        amount: amount,
        beneficiary: beneficiary,
        timestamp: timestamp,
        recommendation: recommendation,
        onRecommendationYes: () {
          widget.onRecommendationResponse?.call(true, recommendationId);
        },
        onRecommendationNo: () {
          widget.onRecommendationResponse?.call(false, recommendationId);
        },
      ),
    );
  }

  Widget _buildTransferFormLink() {
    final beneficiaryId = widget.message.beneficiaryId ?? '';
    // Extract beneficiary name and amount from message or use defaults
    // You could parse these from the text message if needed
    const beneficiaryName = "Beneficiary";
    const amount = 100.0;

    logger.info(
        "Rendering transfer form link for beneficiary: $beneficiaryName");

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message.text != null)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  widget.message.text!,
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          ClickableTextLink(
            text: 'Setup Recurring Transfer',
            onTap: () {
              logger.info("Tapped on transfer form link");
              widget.onOpenTransferForm?.call(
                beneficiaryName,
                beneficiaryId,
                amount,
              );
            },
          ),
        ],
      ),
    );
  }
}
