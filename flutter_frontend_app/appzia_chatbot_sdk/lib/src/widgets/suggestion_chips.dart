import 'package:flutter/material.dart';
import 'suggestion_chip_data.dart';

class SuggestionChips extends StatelessWidget {
  final List<SuggestionChipData> suggestions;
  const SuggestionChips({super.key, required this.suggestions});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      alignment: WrapAlignment.center,
      children: [
        for (final s in suggestions)
          ActionChip(
            onPressed: s.onTap,
            backgroundColor: Colors.white,
            avatar: s.iconAssetPath != null
                ? Image.asset(s.iconAssetPath!, width: 20, height: 20)
                : Icon(s.icon, color: Colors.black54, size: 20),
            label: Text(s.label, style: const TextStyle(color: Colors.black)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.0),
              side: BorderSide(color: Colors.grey.shade300, width: 1),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          ),
      ],
    );
  }
}
