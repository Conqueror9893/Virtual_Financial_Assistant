// flutter_frontend_app/lib/widgets/transfer_summary_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_frontend_app/utils/app_colors.dart';

class TransferSummaryCard extends StatelessWidget {
  final double amount;
  final String fromAccount;
  final String toBeneficiary;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const TransferSummaryCard({
    super.key,
    required this.amount,
    required this.fromAccount,
    required this.toBeneficiary,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            const Text(
              'Transfer Summary',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // Amount
            _buildSummaryRow(
              icon: Icons.currency_rupee,
              label: 'Amount',
              value: 'USD ${amount.toStringAsFixed(0)}',
              iconColor: AppColors.successColor,
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(height: 1),
            ),

            // From Account
            _buildSummaryRow(
              icon: Icons.account_balance_wallet_outlined,
              label: 'From',
              value: '$fromAccount Account',
              iconColor: AppColors.bubbleGradientEnd,
            ),

            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12.0),
              child: Divider(height: 1),
            ),

            // To Beneficiary
            _buildSummaryRow(
              icon: Icons.person_outline,
              label: 'To',
              value: toBeneficiary,
              iconColor: AppColors.infoColor,
            ),

            const SizedBox(height: 24),

            // Confirm Text
            const Text(
              'Confirm this transfer?',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow({
    required IconData icon,
    required String label,
    required String value,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            icon,
            size: 20,
            color: iconColor,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
