import 'package:flutter/material.dart';
import 'package:flutter_frontend_app/models/message.dart';
import 'package:flutter_frontend_app/services/api_service.dart';
import 'package:flutter_frontend_app/widgets/ai_display_data.dart';
import 'package:flutter_frontend_app/widgets/chat_view.dart';
import 'package:flutter_frontend_app/widgets/custom_app_bar.dart';
import 'package:flutter_frontend_app/widgets/user_query_bubble.dart';

class AiBotScreen extends StatefulWidget {
  final AiDisplayData displayData;
  const AiBotScreen({super.key, required this.displayData});

  @override
  State<AiBotScreen> createState() => _AiBotScreenState();
}

class _AiBotScreenState extends State<AiBotScreen> {
  final List<Message> _messages = [];
  final ApiService _apiService = ApiService();
  final ScrollController _scrollController = ScrollController();
  Message? _userQuery;

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
      appBar: CustomAppBar(title: widget.displayData.title),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.displayData.backgroundGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: const [0.0, 0.33],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (_userQuery != null)
                UserQueryBubble(text: _userQuery!.text),
              Expanded(
                child: ChatView(
                  messages: _messages,
                  onSendMessage: _sendMessage,
                  scrollController: _scrollController,
                  hintText: widget.displayData.inputHint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _sendMessage(String text) {
    final userMessage = Message(
      id: DateTime.now().toString(),
      text: text,
      isUser: true,
    );

    bool shouldScroll = false;
    setState(() {
      if (_userQuery == null) {
        _userQuery = userMessage;
      } else {
        _messages.add(userMessage);
        shouldScroll = true;
      }
    });

    if (shouldScroll) {
      _scrollToBottom();
    }

    _apiService.sendMessage(text).then((botMessage) {
      setState(() {
        _messages.add(botMessage);
      });
      _scrollToBottom();
    }).catchError((error) {
      setState(() {
        _messages.add(
          Message(
            id: DateTime.now().toString(),
            text: 'Error: $error',
            isUser: false,
          ),
        );
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}