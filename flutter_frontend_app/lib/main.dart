import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_frontend_app/widgets/chatbot_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/ai_display_data.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final String configString =
      await rootBundle.loadString('lib/assets/ai_display_config.json');
  final Map<String, dynamic> configJson = jsonDecode(configString);

  final displayData = AiDisplayData.fromJson(configJson);

  runApp(MaterialApp(
    home: ChatbotLauncher(displayData: displayData),
    theme: ThemeData(
      fontFamily: 'Outfit',
      textTheme: GoogleFonts.outfitTextTheme(),
    ),
  ));
}
