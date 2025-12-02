// flutter_frontend_app/lib/widgets/account_selection_card.dart

import 'package:flutter/material.dart';
import 'package:flutter_frontend_app/utils/app_colors.dart';

class AccountSelectionCard extends StatelessWidget {
  final String accountType;
  final String accountNumber; // Placeholder like "****1234"
  final VoidCallback onTap;

  const AccountSelectionCard({
    super.key,
    required this.accountType,
    required this.accountNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Account Icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  accountType.toLowerCase() == 'savings'
                      ? Icons.savings_outlined
                      : Icons.account_balance_outlined,
                  color: AppColors.bubbleGradientEnd,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Account Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$accountType Account',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      accountNumber,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Arrow Icon
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
