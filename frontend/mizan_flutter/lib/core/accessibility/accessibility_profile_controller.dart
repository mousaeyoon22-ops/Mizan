import 'package:flutter/material.dart';

enum AccessibilityPreset {
  standard,
  blindScreenReader,
  lowVisionHighContrast,
  deafVisualHaptic,
  motorHandsFreeVoice,
  cognitiveSimplified,
}

/// Reactive WCAG 2.2 AA / EN 301 549 Accessibility Profile Controller.
/// Drives high-contrast themes (7:1+), 200% text scaling, 64dp motor touch targets,
/// deaf visual+haptic alert parity, screen-reader TTS read-back, and voice control.
class AccessibilityProfileController extends ChangeNotifier {
  AccessibilityPreset preset = AccessibilityPreset.standard;
  bool highContrastEnabled = false;
  double fontScale = 1.0; // 1.0 to 2.0
  bool colorBlindSafeLabels = true;
  bool screenReaderVerbose = false;
  bool ttsFinancialReadback = false;
  bool visualFlashAlerts = false;
  bool hapticFeedbackEnabled = true;
  bool liveCaptionsEnabled = false;
  bool motorLargeTargets = false;
  bool singleTapNoSwipe = false;
  bool simplifiedUiMode = false;
  double timeoutMultiplier = 1.0; // 1.0 to 3.0
  bool voiceCommandsEnabled = false;
  String voiceLang = 'ar';

  double get minTouchTargetDp => motorLargeTargets ? 64.0 : 48.0;
  double get lineHeight => simplifiedUiMode ? 1.55 : 1.3;

  void applyPreset(AccessibilityPreset p) {
    preset = p;
    switch (p) {
      case AccessibilityPreset.standard:
        highContrastEnabled = false;
        fontScale = 1.0;
        screenReaderVerbose = false;
        ttsFinancialReadback = false;
        visualFlashAlerts = false;
        liveCaptionsEnabled = false;
        motorLargeTargets = false;
        singleTapNoSwipe = false;
        simplifiedUiMode = false;
        timeoutMultiplier = 1.0;
        voiceCommandsEnabled = false;
        break;

      case AccessibilityPreset.blindScreenReader:
        highContrastEnabled = true;
        fontScale = 1.25;
        colorBlindSafeLabels = true;
        screenReaderVerbose = true;
        ttsFinancialReadback = true;
        hapticFeedbackEnabled = true;
        singleTapNoSwipe = true;
        timeoutMultiplier = 2.5;
        voiceCommandsEnabled = true;
        break;

      case AccessibilityPreset.lowVisionHighContrast:
        highContrastEnabled = true;
        fontScale = 1.75;
        colorBlindSafeLabels = true;
        ttsFinancialReadback = true;
        motorLargeTargets = true;
        timeoutMultiplier = 2.0;
        break;

      case AccessibilityPreset.deafVisualHaptic:
        visualFlashAlerts = true;
        hapticFeedbackEnabled = true;
        liveCaptionsEnabled = true;
        colorBlindSafeLabels = true;
        ttsFinancialReadback = false;
        break;

      case AccessibilityPreset.motorHandsFreeVoice:
        motorLargeTargets = true;
        singleTapNoSwipe = true;
        voiceCommandsEnabled = true;
        ttsFinancialReadback = true;
        liveCaptionsEnabled = true;
        timeoutMultiplier = 3.0;
        break;

      case AccessibilityPreset.cognitiveSimplified:
        simplifiedUiMode = true;
        fontScale = 1.25;
        colorBlindSafeLabels = true;
        singleTapNoSwipe = true;
        timeoutMultiplier = 2.5;
        break;
    }
    notifyListeners();
  }

  /// WCAG AAA High-Contrast Theme (>= 7:1 contrast ratio; pure black/yellow/white surfaces).
  ThemeData buildAccessibleTheme(ThemeData baseTheme) {
    if (!highContrastEnabled) return baseTheme;
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF000000),
      colorScheme: const ColorScheme.highContrastDark(
        primary: Color(0xFFFFEA00),   // Contrast ratio vs #000000 = 17.4:1 (AAA)
        onPrimary: Color(0xFF000000),
        secondary: Color(0xFF00E5FF), // Contrast ratio vs #000000 = 14.2:1 (AAA)
        onSecondary: Color(0xFF000000),
        surface: Color(0xFF0A0A0A),
        onSurface: Color(0xFFFFFFFF), // Contrast ratio vs #0A0A0A = 19.7:1 (AAA)
        error: Color(0xFFFF6E6E),
        onError: Color(0xFF000000),
      ),
    );
  }
}
