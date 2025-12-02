// flutter_frontend_app/lib/widgets/clickable_text_link.dart

import 'package:flutter/material.dart';
import 'package:flutter_frontend_app/utils/app_colors.dart';

class ClickableTextLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const ClickableTextLink({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: AppColors.bubbleGradientEnd,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_forward,
              size: 16,
              color: AppColors.bubbleGradientEnd,
            ),
          ],
        ),
      ),
    );
  }
}
