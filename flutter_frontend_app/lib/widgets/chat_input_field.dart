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
  double _textFieldHeight = 44.0; // Base height (single line)
  final double _minHeight = 44.0; // Single line
  final double _maxHeight = 100.0; // Max height for 3 lines + scrolling
  final double _lineHeight = 24.0; // Height per line

  @override
  void initState() {
    super.initState();
    widget.inputController.addListener(_updateTextFieldHeight);
  }

  @override
  void dispose() {
    widget.inputController.removeListener(_updateTextFieldHeight);
    super.dispose();
  }

  void _updateTextFieldHeight() {
    final text = widget.inputController.text;
    final lines = '\n'.allMatches(text).length + 1;

    double newHeight = _minHeight + ((lines - 1) * _lineHeight);
    newHeight = newHeight.clamp(_minHeight, _maxHeight);

    if (_textFieldHeight != newHeight) {
      setState(() {
        _textFieldHeight = newHeight;
      });
    }
  }

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
        crossAxisAlignment: CrossAxisAlignment.end,
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
              height: _textFieldHeight,
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
                maxLines: null,
                minLines: 1,
                expands: false,
                scrollPhysics: const ClampingScrollPhysics(),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: TextStyle(color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  suffixIcon: widget.isMicListening
                      ? const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: Padding(
                              padding: EdgeInsets.all(6.0),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Color.fromARGB(255, 152, 130, 253),
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
                    ? const Color.fromARGB(255, 214, 214, 238)
                    : Colors.grey.shade100,
              ),
              child: Icon(
                widget.isMicListening ? Icons.mic : Icons.mic_none,
                color: widget.isMicListening
                    ? const Color(0xFF5B5FB9)
                    : const Color.fromARGB(255, 118, 144, 184),
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

  // ✅ Removed dispose() method - parent widget owns the controller
}
