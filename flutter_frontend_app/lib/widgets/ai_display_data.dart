import 'package:flutter/material.dart';
import 'suggestion_chip_data.dart';

class AiDisplayData {
  final String title;
  final List<Color> backgroundGradient;
  final Color avatarBgColor;
  final IconData? avatarIcon;
  final String? avatarAssetPath;
  final String greetingIntro;
  final String botName;
  final String greetingLine1;
  final String greetingLine2;
  final List<SuggestionChipData> suggestions;
  final String inputHint;

  AiDisplayData({
    required this.title,
    required this.backgroundGradient,
    required this.avatarBgColor,
    this.avatarIcon,
    this.avatarAssetPath,
    required this.greetingIntro,
    required this.botName,
    required this.greetingLine1,
    required this.greetingLine2,
    required this.suggestions,
    required this.inputHint,
  });

  // Load from JSON method here
  factory AiDisplayData.fromJson(Map<String, dynamic> json) {
    // Parse gradient colors safely
    List<Color> gradientColors = (json['backgroundGradient'] as List<dynamic>)
        .map((color) => Color(int.parse(color.toString())))
        .toList();

    // Parse avatar background color
    Color avatarBg = Color(int.parse(json['avatarBgColor'].toString()));

    // Parse avatarIcon or avatarAssetPath depending on if path or icon int string
    String avatarIconRaw = json['avatarIcon'] as String;

    String? avatarAssetPath;
    IconData? avatarIcon;

    if (avatarIconRaw.toLowerCase().endsWith('.png') ||
        avatarIconRaw.toLowerCase().endsWith('.jpg') ||
        avatarIconRaw.toLowerCase().endsWith('.jpeg')) {
      avatarAssetPath = avatarIconRaw;
      avatarIcon = null;
    } else {
      // Attempt to parse string as int code point
      avatarIcon =
          IconData(int.parse(avatarIconRaw), fontFamily: 'MaterialIcons');
      avatarAssetPath = null;
    }

    // Parse suggestions list
    List<SuggestionChipData> suggestionsList =
        (json['suggestions'] as List<dynamic>)
            .map((chipJson) => SuggestionChipData.fromJson(chipJson))
            .toList();

    return AiDisplayData(
      title: json['title'] as String,
      backgroundGradient: gradientColors,
      avatarBgColor: avatarBg,
      avatarIcon: avatarIcon,
      avatarAssetPath: avatarAssetPath,
      greetingIntro: json['greetingIntro'] as String,
      botName: json['botName'] as String,
      greetingLine1: json['greetingLine1'] as String,
      greetingLine2: json['greetingLine2'] as String,
      suggestions: suggestionsList,
      inputHint: json['inputHint'] as String,
    );
  }
}
