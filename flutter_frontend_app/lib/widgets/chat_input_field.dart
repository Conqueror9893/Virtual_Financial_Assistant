import 'package:flutter/material.dart';

class ChatInputField extends StatefulWidget {
  final String hintText;
  final Function(String) onSendMessage;
  final VoidCallback onMicPressed;
  final TextEditingController inputController;
  final bool isMicListening;

  const ChatInputField({
    super.key,
    required this.hintText,
    required this.onSendMessage,
    required this.onMicPressed,
    required this.inputController,
    this.isMicListening = false,
  });

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Plus icon
          GestureDetector(
            onTap: () {
              // Handle attachments/more options
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade100,
              ),
              child: Icon(Icons.add, color: Colors.grey.shade600, size: 20),
            ),
          ),
          const SizedBox(width: 8),

          // Input field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
              ),
              child: TextField(
                controller: widget.inputController,
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  suffixIcon: widget.isMicListening
                      ? Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.orange.shade500,
                                ),
                              ),
                            ),
                          ),
                        )
                      : null,
                ),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    widget.onSendMessage(value);
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Mic button
          GestureDetector(
            onTap: widget.onMicPressed,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isMicListening
                    ? Colors.orange.shade100
                    : Colors.grey.shade100,
              ),
              child: Icon(
                widget.isMicListening ? Icons.mic : Icons.mic_none,
                color: widget.isMicListening
                    ? Colors.orange.shade600
                    : Colors.grey.shade600,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Send button
          GestureDetector(
            onTap: () {
              final text = widget.inputController.text;
              if (text.trim().isNotEmpty) {
                widget.onSendMessage(text);
              }
            },
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF5B5FB9),
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    widget.inputController.dispose();
    super.dispose();
  }
}
