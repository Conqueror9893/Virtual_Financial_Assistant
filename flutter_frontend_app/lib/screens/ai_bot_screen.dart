import 'package:flutter/material.dart';

class AiBotScreen extends StatelessWidget {
  const AiBotScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extend_body_behind_appbar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            // TODO: Implement back navigation
          },
        ),
        title: const Text(
          'Speaking to Ai Bot',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFEECE2), Color(0xFFFFF7F2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
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
                      const SizedBox(height: 60), // Space for AppBar
                      // --- Avatar and Greeting ---
                      // TODO: Replace with actual avatar image in assets/images/appzia_avatar.png
                      const CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        child: CircleAvatar(
                          radius: 38,
                          backgroundColor: Color(0xFFF87B2D),
                          child: Icon(Icons.android, size: 40, color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 16),
                      RichText(
                        textAlign: TextAlign.center,
                        text: const TextSpan(
                          style: TextStyle(fontSize: 24, color: Colors.black),
                          children: <TextSpan>[
                            TextSpan(text: 'Hi, I\'m '),
                            TextSpan(
                              text: 'Appzia',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'I can help you check your',
                        style: TextStyle(fontSize: 16, color: Colors.black54),
                        textAlign: TextAlign.center,
                      ),
                      const Text(
                        'accounts, spending, or transfers',
                        style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFFF87B2D),
                            fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // --- Suggestion Chips ---
                      Wrap(
                        spacing: 12.0,
                        runSpacing: 12.0,
                        alignment: WrapAlignment.center,
                        children: const [
                          SuggestionChip(
                              icon: Icons.credit_card,
                              label: 'Payments & transfers'),
                          SuggestionChip(
                              icon: Icons.bar_chart,
                              label: 'Spending insights'),
                          SuggestionChip(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Personal finance & accounts'),
                          SuggestionChip(
                              icon: Icons.savings_outlined,
                              label: 'Savings & investments'),
                          SuggestionChip(
                              icon: Icons.lightbulb_outline,
                              label: 'Support & service'),
                          SuggestionChip(
                              icon: Icons.search,
                              label: 'Last electricity bill payment'),
                        ],
                      )
                    ],
                  ),
                ),
              ),
              // --- Chat Input Field ---
              _buildChatInputField(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatInputField() {
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
          const Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Chat with Appzia',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.mic, color: Color(0xFFF87B2D)),
            onPressed: () {
              // TODO: Implement voice input functionality
            },
          ),
        ],
      ),
    );
  }
}

class SuggestionChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const SuggestionChip({
    super.key,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: () {
        // TODO: Implement chip tap functionality
      },
      backgroundColor: Colors.white,
      avatar: Icon(icon, color: Colors.black54, size: 20),
      label: Text(
        label,
        style: const TextStyle(color: Colors.black),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
    );
  }
}
