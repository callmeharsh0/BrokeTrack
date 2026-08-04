import 'package:flutter/services.dart';

/// Utility class for haptic feedback throughout the app
class HapticHelper {
  /// Light impact - for subtle interactions (filter chips, category selection)
  static void light() {
    HapticFeedback.lightImpact();
  }

  /// Medium impact - for standard interactions (button taps, navigation)
  static void medium() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy impact - for important actions (delete, save)
  static void heavy() {
    HapticFeedback.heavyImpact();
  }

  /// Selection feedback - for picker/selection changes
  static void selection() {
    HapticFeedback.selectionClick();
  }

  /// Success vibration pattern - for successful operations
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.lightImpact();
  }

  /// Error vibration pattern - for errors or warnings
  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 50));
    await HapticFeedback.heavyImpact();
  }
}
