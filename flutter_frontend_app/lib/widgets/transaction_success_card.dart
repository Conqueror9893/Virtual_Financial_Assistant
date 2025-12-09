// flutter_frontend_app/lib/widgets/transaction_success_card.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_frontend_app/utils/app_colors.dart';
import 'package:intl/intl.dart';

class TransactionSuccessCard extends StatelessWidget {
  final double amount;
  final String beneficiary;
  final String timestamp;
  final String? recommendation;
  final VoidCallback? onRecommendationYes;
  final VoidCallback? onRecommendationNo;

  const TransactionSuccessCard({
    super.key,
    required this.amount,
    required this.beneficiary,
    required this.timestamp,
    this.recommendation,
    this.onRecommendationYes,
    this.onRecommendationNo,
  });

  String _formatTimestamp(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime);
    } catch (e) {
      return timestamp;
    }
  }

  void _copyTransactionDetails(BuildContext context) {
    final details = '''
Transaction Successful
Amount: USD ${amount.toStringAsFixed(0)}
To: $beneficiary
Date: ${_formatTimestamp(timestamp)}
    '''
        .trim();

    Clipboard.setData(ClipboardData(text: details));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Transaction details copied to clipboard'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _exportReport(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report exported'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

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
          children: [
            // Success Icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.successColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                color: AppColors.successColor,
                size: 40,
              ),
            ),

            const SizedBox(height: 16),

            // Success Message
            const Text(
              'Transfer Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 8),

            // Amount
            Text(
              'USD ${amount.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: AppColors.successColor,
              ),
            ),

            const SizedBox(height: 4),

            // Beneficiary
            Text(
              'to $beneficiary',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 16),

            // Timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.access_time,
                  size: 16,
                  color: AppColors.textTertiary,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatTimestamp(timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Divider(height: 1),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  icon: Icons.file_download_outlined,
                  label: 'Export Report',
                  onTap: () => _exportReport(context),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: AppColors.textTertiary.withOpacity(0.3),
                ),
                _buildActionButton(
                  icon: Icons.content_copy_outlined,
                  label: 'Copy',
                  onTap: () => _copyTransactionDetails(context),
                ),
              ],
            ),

            // Recommendation Section
            if (recommendation != null) ...[
              const SizedBox(height: 24),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.infoColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: AppColors.infoColor,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Recommendation',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.infoColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      recommendation!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: onRecommendationNo,
                          child: const Text(
                            'No, thanks',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: onRecommendationYes,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.bubbleGradientEnd,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Yes'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            Icon(
              icon,
              color: AppColors.bubbleGradientEnd,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
