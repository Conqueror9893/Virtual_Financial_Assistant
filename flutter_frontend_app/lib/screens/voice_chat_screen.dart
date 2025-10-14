import 'package:flutter/material.dart';

class VoiceChatScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const double fixedWidth = 412;
    const double fixedHeight = 844;

    return Scaffold(
      backgroundColor: const Color(0xFFFEECE2), // or use your gradient if applicable
      body: Center(
        child: SizedBox(
          width: fixedWidth,
          height: fixedHeight,
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.only(top: 40, left: 8, right: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Speaking to Appzia",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Animated GIF placeholder
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    "GIF HERE",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  // TODO: Replace with Image.asset('assets/your_wave.gif')
                ),
              ),

              const SizedBox(height: 28),

              // Suggested voice text snippet
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: "Send ₹ 5,000 to Amy from my ",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                      TextSpan(
                        text: "Savings bank account",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: " |",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Spacer(),

              // "Listening..." indicator and controls row
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  children: [
                    Text(
                      "Listening...",
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Optionally add other controls (start, stop, cancel)
                        IconButton(
                          icon: Icon(Icons.mic_none, color: Colors.orange, size: 36),
                          onPressed: () {}, // start/stop logic here
                        ),
                        const SizedBox(width: 32),
                        IconButton(
                          icon: Icon(Icons.close, color: Colors.grey, size: 36),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
