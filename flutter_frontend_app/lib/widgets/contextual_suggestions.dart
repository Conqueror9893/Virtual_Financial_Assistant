// lib/widgets/contextual_suggestions.dart
import 'package:flutter/material.dart';

class ContextualSuggestions extends StatelessWidget {
  final List<String> suggestions;
  final void Function(String) onSuggestionSelected;

  const ContextualSuggestions({
    super.key,
    required this.suggestions,
    required this.onSuggestionSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8.0, left: 12.0, right: 12.0),
      child: Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children: suggestions.map((s) {
          return ActionChip(
            label: Text(
              s,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            backgroundColor: const Color(0xFF0077B6),
            onPressed: () => onSuggestionSelected(s),
          );
        }).toList(),
      ),
    );
  }
}
