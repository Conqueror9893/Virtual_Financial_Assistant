import 'package:flutter/material.dart';

class SuggestionChipData {
  final String? iconAssetPath;
  final IconData? icon;
  final String label;
  final VoidCallback onTap;

  SuggestionChipData({
    this.icon,
    this.iconAssetPath,
    required this.label,
    required this.onTap,
  });

  factory SuggestionChipData.fromJson(Map<String, dynamic> json) {
    String iconRaw = json['icon'] as String;
    String? iconAssetPath;
    IconData? icon;

    if (iconRaw.toLowerCase().endsWith('.png') ||
        iconRaw.toLowerCase().endsWith('.jpg') ||
        iconRaw.toLowerCase().endsWith('.jpeg')) {
      iconAssetPath = iconRaw;
      icon = null;
    } else {
      icon = IconData(int.parse(iconRaw), fontFamily: 'MaterialIcons');
      iconAssetPath = null;
    }

    return SuggestionChipData(
      icon: icon,
      iconAssetPath: iconAssetPath,
      label: json['label'],
      onTap: () {},
    );
  }
}
