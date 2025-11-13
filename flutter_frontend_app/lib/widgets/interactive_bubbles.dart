import 'package:flutter/material.dart';
import 'package:flutter_frontend_app/utils/app_colors.dart';

class InteractiveBubbles extends StatelessWidget {
  final List<Map<String, dynamic>> bubbles;
  final Function(Map<String, dynamic>) onBubbleTap;
  final VoidCallback onBackTap;
  final bool showBackButton;

  const InteractiveBubbles({
    super.key,
    required this.bubbles,
    required this.onBubbleTap,
    required this.onBackTap,
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 12.0,
          runSpacing: 12.0,
          alignment: WrapAlignment.center,
          children: [
            for (final bubble in bubbles)
              _BubbleButton(
                label: bubble['label'] as String? ?? '',
                icon: bubble['icon'] as String?,
                onTap: () => onBubbleTap(bubble),
              ),
          ],
        ),
        if (showBackButton) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: onBackTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bubbleBackgroundDark,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primaryAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back, size: 16, color: Colors.white70),
                  SizedBox(width: 8),
                  Text(
                    'Back',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BubbleButton extends StatefulWidget {
  final String label;
  final String? icon;
  final VoidCallback onTap;

  const _BubbleButton({
    required this.label,
    this.icon,
    required this.onTap,
  });

  @override
  State<_BubbleButton> createState() => _BubbleButtonState();
}

class _BubbleButtonState extends State<_BubbleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.bubbleGradientStart,
                AppColors.bubbleGradientEnd,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryAccent.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                _buildIcon(widget.icon!),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(String icon) {
    // Check if it's an asset path
    if (icon.toLowerCase().endsWith('.png') ||
        icon.toLowerCase().endsWith('.jpg') ||
        icon.toLowerCase().endsWith('.jpeg') ||
        icon.toLowerCase().endsWith('.svg')) {
      return Image.asset(
        icon,
        width: 18,
        height: 18,
        color: Colors.white,
      );
    } else {
      // Try to parse as icon code point
      try {
        final iconData =
            IconData(int.parse(icon), fontFamily: 'MaterialIcons');
        return Icon(iconData, size: 18, color: Colors.white);
      } catch (e) {
        // Default icon if parsing fails
        return const Icon(Icons.bubble_chart, size: 18, color: Colors.white);
      }
    }
  }
}
