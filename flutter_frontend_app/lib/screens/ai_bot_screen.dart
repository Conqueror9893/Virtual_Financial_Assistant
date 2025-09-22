import 'package:flutter/material.dart';
import 'package:flutter_frontend_app/widgets/custom_app_bar.dart';
import 'package:flutter_frontend_app/widgets/bot_avatar_greeting.dart';
import 'package:flutter_frontend_app/widgets/suggestion_chips.dart';
import 'package:flutter_frontend_app/widgets/chat_input_field.dart';
import 'package:flutter_frontend_app/widgets/ai_display_data.dart';

class AiBotScreen extends StatelessWidget {
  final AiDisplayData displayData;
  const AiBotScreen({super.key, required this.displayData});

  @override
  Widget build(BuildContext context) {
    const double fixedWidth = 390;
    const double fixedHeight = 844;

    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        children: [
          Positioned(
            right: 16,
            bottom: 16,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: constraints.maxWidth * 0.9,
                maxHeight: constraints.maxHeight * 0.9,
              ),
              child: FittedBox(
                alignment: Alignment.bottomRight,
                fit: BoxFit.contain,
                child: SizedBox(
                  width: fixedWidth,
                  height: fixedHeight,
                  child: Material(
                    elevation: 8,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.hardEdge,
                    child: _buildChatContainer(),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildChatContainer() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CustomAppBar(title: displayData.title),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: displayData.backgroundGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.33],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      BotAvatarGreeting(displayData: displayData),
                      const SizedBox(height: 32),
                      SuggestionChips(suggestions: displayData.suggestions),
                    ],
                  ),
                ),
              ),
              ChatInputField(hintText: displayData.inputHint),
            ],
          ),
        ),
      ),
    );
  }
}
