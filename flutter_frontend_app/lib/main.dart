import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'widgets/ai_display_data.dart';
import 'screens/ai_bot_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final String configString =
      await rootBundle.loadString('lib/assets/ai_display_config.json');
  final Map<String, dynamic> configJson = jsonDecode(configString);

  final displayData = AiDisplayData.fromJson(configJson);

  runApp(MaterialApp(
    home: AiBotScreen(displayData: displayData),
  ));
}
