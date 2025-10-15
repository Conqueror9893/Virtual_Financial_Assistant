import 'package:flutter/material.dart';
import 'ai_display_data.dart';
import 'ai_bot_screen.dart';

class ChatbotLauncher extends StatefulWidget {
  final AiDisplayData displayData;

  /// Initial position of floating button
  final Alignment alignment;

  /// Initial width and height of chatbot panel
  final double initialWidth;
  final double initialHeight;

  /// Minimum and maximum chatbot size limits
  final double minWidth;
  final double minHeight;
  final double maxWidth;
  final double maxHeight;

  /// Floating button customization
  final double buttonSize;
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final String? label;

  const ChatbotLauncher({
    super.key,
    required this.displayData,
    this.alignment = Alignment.bottomRight,
    this.initialWidth = 400,
    this.initialHeight = 600,
    this.minWidth = 300,
    this.minHeight = 400,
    this.maxWidth = 600,
    this.maxHeight = 800,
    this.buttonSize = 64,
    this.icon = Icons.chat_bubble_rounded,
    this.backgroundColor = const Color(0xFF0066FF),
    this.iconColor = Colors.white,
    this.label,
  });

  @override
  State<ChatbotLauncher> createState() => _ChatbotLauncherState();
}

class _ChatbotLauncherState extends State<ChatbotLauncher> {
  bool _isChatOpen = false;
  Offset? _chatPosition;
  double? _chatWidth;
  double? _chatHeight;
  Offset? _dragStart;
  bool _isResizing = false;

  @override
  void initState() {
    super.initState();
    _chatWidth = widget.initialWidth;
    _chatHeight = widget.initialHeight;
  }

  void _toggleChat() {
    setState(() => _isChatOpen = !_isChatOpen);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      final dx = (_chatPosition?.dx ?? 0) + details.delta.dx;
      final dy = (_chatPosition?.dy ?? 0) + details.delta.dy;
      _chatPosition = Offset(dx, dy);
    });
  }

  void _onResizeUpdate(DragUpdateDetails details) {
    setState(() {
      _chatWidth = (_chatWidth! + details.delta.dx)
          .clamp(widget.minWidth, widget.maxWidth);
      _chatHeight = (_chatHeight! + details.delta.dy)
          .clamp(widget.minHeight, widget.maxHeight);
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final startX = _chatPosition?.dx ??
        (widget.alignment == Alignment.bottomRight
            ? size.width - widget.initialWidth - 16
            : 16);
    final startY = _chatPosition?.dy ??
        (widget.alignment == Alignment.bottomRight
            ? size.height - widget.initialHeight - 32
            : 32);

    return Stack(
      children: [
        // Floating button when chatbot is closed
        if (!_isChatOpen)
          Positioned(
            right: widget.alignment == Alignment.bottomRight ? 16 : null,
            left: widget.alignment == Alignment.bottomLeft ? 16 : null,
            bottom: 24,
            child: GestureDetector(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton(
                    heroTag: "chatbot_fab",
                    onPressed: _toggleChat,
                    backgroundColor: widget.backgroundColor,
                    shape: const CircleBorder(),
                    child: Icon(widget.icon, color: widget.iconColor, size: 28),
                  ),
                  if (widget.label != null) ...[
                    const SizedBox(height: 4),
                    Text(widget.label!, style: const TextStyle(fontSize: 12))
                  ]
                ],
              ),
            ),
          ),

        // Chatbot overlay when open
        if (_isChatOpen)
          Positioned(
            left: startX,
            top: startY,
            child: GestureDetector(
              onPanUpdate: !_isResizing ? _onDragUpdate : null,
              child: Stack(
                children: [
                  Container(
                    width: _chatWidth,
                    height: _chatHeight,
                    decoration: const BoxDecoration(
                      // color: Colors.white.withOpacity(0.95),
                      // borderRadius: BorderRadius.circular(20),
                      // boxShadow: [
                      //   BoxShadow(
                      //     color: Colors.black.withOpacity(0.2),
                      //     blurRadius: 10,
                      //   ),
                      // ],
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Material(
                      color: Colors.transparent,
                      child: AiBotScreen(displayData: widget.displayData, onClose: _toggleChat),
                    ),
                  ),

                  // Close button (top right)
                  // Positioned(
                  //   right: 8,
                  //   top: 8,
                  //   child: IconButton(
                  //     icon:
                  //         const Icon(Icons.close_rounded, color: Colors.black),
                  //     onPressed: _toggleChat,
                  //   ),
                  // ),

                  // Resize handle (bottom-right corner)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: GestureDetector(
                      onPanStart: (_) => setState(() => _isResizing = true),
                      onPanEnd: (_) => setState(() => _isResizing = false),
                      onPanUpdate: _onResizeUpdate,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Icon(
                          Icons.drag_handle_rounded,
                          size: 16,
                          color: Colors.black38,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
