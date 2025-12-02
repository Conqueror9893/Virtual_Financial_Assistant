import 'dart:ui';
import 'package:flutter/material.dart';

class SuggestionBar extends StatelessWidget {
  final List<String> suggestions;
  final Function(String) onSuggestionTap;

  const SuggestionBar({
    Key? key,
    required this.suggestions,
    required this.onSuggestionTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    // Sort alphabetically (change if needed)
    final sorted = List<String>.from(suggestions)
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          children: [
            // Frosted Glass Background
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                    width: 1.2,
                  ),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.03),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                height: 80,
              ),
            ),

            // Soft inner glow (glass effect)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: RadialGradient(
                    colors: [
                      Colors.white.withOpacity(0.07),
                      Colors.transparent,
                    ],
                    center: const Alignment(-0.6, -0.6),
                    radius: 1.2,
                  ),
                ),
              ),
            ),

            // Content Row (Scrollable Chips)
            Positioned.fill(
              child: Align(
                alignment: Alignment.centerLeft,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: sorted.map((q) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () => onSuggestionTap(q),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0xFFC4E3FF),
                                  blurRadius: 1,
                                  
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.lightbulb_outline,
                                    size: 18, color: Colors.white.withOpacity(0.9)),
                                const SizedBox(width: 6),
                                Text(
                                  q,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
