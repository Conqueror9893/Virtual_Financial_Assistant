// flutter_frontend_app/lib/widgets/otp_input_field.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_frontend_app/utils/app_colors.dart';

class OtpInputField extends StatefulWidget {
  final Function(String) onOtpComplete;
  final int otpLength;

  const OtpInputField({
    super.key,
    required this.onOtpComplete,
    this.otpLength = 4,
  });

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> {
  final TextEditingController _controller = TextEditingController();
  String _maskedOtp = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onOtpChanged(String value) {
    setState(() {
      _maskedOtp = '*' * value.length;
    });

    if (value.length == widget.otpLength) {
      widget.onOtpComplete(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  color: AppColors.warningColor,
                  size: 24,
                ),
                SizedBox(width: 12),
                Text(
                  'Enter OTP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              maxLength: widget.otpLength,
              obscureText: true,
              obscuringCharacter: '*',
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: _onOtpChanged,
              decoration: InputDecoration(
                hintText: 'Enter ${widget.otpLength}-digit OTP',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.textTertiary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(
                    color: AppColors.bubbleGradientEnd,
                    width: 2,
                  ),
                ),
                prefixIcon: const Icon(Icons.pin),
              ),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
