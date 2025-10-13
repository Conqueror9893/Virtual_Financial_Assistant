// lib/utils/logger.dart

// lib/utils/logger.dart
import 'package:flutter/foundation.dart';

class Logger {
  final String tag;
  Logger(this.tag);

  void info(String message) {
    debugPrint("[INFO][$tag] $message");
  }

  void debug(String message) {
    debugPrint("[DEBUG][$tag] $message");
  }

  void error(String message) {
    debugPrint("[ERROR][$tag] $message");
  }
}


/// Usage:
/// final logger = Logger("AiBotScreen");
/// logger.i("Chat message sent");
