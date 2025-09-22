import 'package:flutter/material.dart';
import 'package:flutter_frontend_app/screens/ai_bot_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Appzia',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const AiBotScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
