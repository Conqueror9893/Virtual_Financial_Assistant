import 'package:flutter/material.dart';
import 'ai_display_data.dart';

class BotAvatarGreeting extends StatelessWidget {
  final AiDisplayData displayData;
  const BotAvatarGreeting({super.key, required this.displayData});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: Colors.white,
          child: CircleAvatar(
            radius: 28,
            backgroundColor: displayData.avatarBgColor,
            backgroundImage: displayData.avatarAssetPath != null
                ? AssetImage(displayData.avatarAssetPath!)
                : null,
            child: displayData.avatarAssetPath == null
                ? const Icon(Icons.android, size: 40, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(fontSize: 24, color: Colors.black),
            children: [
              TextSpan(text: displayData.greetingIntro),
              TextSpan(
                text: displayData.botName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          displayData.greetingLine1,
          style: const TextStyle(fontSize: 16, color: Colors.black54),
          textAlign: TextAlign.center,
        ),
        Text(
          displayData.greetingLine2,
          style: const TextStyle(
              fontSize: 16,
              color: Color(0xFFF87B2D),
              fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
