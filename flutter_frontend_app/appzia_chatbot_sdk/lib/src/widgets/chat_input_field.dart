import 'package:flutter/material.dart';

class ChatInputField extends StatefulWidget {
  final String hintText;
  final Function(String) onSendMessage;
  final VoidCallback? onMicPressed; // Callback for mic button press
  const ChatInputField({
    super.key,
    required this.hintText,
    required this.onSendMessage,
    this.onMicPressed,
  });

  @override
  State<ChatInputField> createState() => _ChatInputFieldState();
}

class _ChatInputFieldState extends State<ChatInputField> {
  final TextEditingController _controller = TextEditingController();
  final bool _isLoading = false;

  bool _hasText = false; // Track if input has text

  @override
  void initState() {
    super.initState();

    // Listen to text changes to toggle icon
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (_hasText != hasText) {
        setState(() {
          _hasText = hasText;
        });
      }
    });
  }

  void _sendMessage() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSendMessage(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      margin: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                border: InputBorder.none,
                hintStyle: const TextStyle(color: Colors.grey),
                hintText: widget.hintText,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  iconSize: 28,
                  icon: _hasText
                      ? const Icon(Icons.send, color: Color(0xFFF87B2D))
                      : Image.asset(
                          'assets/microphone-2.png', // Replace with your mic icon filename
                          width: 28,
                          height: 28,
                        ),
                  onPressed: _hasText
                      ? _sendMessage
                      : () {
                          print("Mic button pressed");
                          widget.onMicPressed?.call();
                        },
                ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
