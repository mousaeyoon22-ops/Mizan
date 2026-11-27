import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'accessibility_profile_controller.dart';

/// Accessible Action Button guaranteeing >= 48dp (WCAG 2.2) or >= 64dp (Motor Assist),
/// explicit Semantics label/hint for TalkBack, VoiceOver & Android Voice Access.
class MizanAccessibleButton extends StatelessWidget {
  final AccessibilityProfileController a11y;
  final String label;
  final String semanticHint;
  final IconData icon;
  final VoidCallback? onPressed;

  const MizanAccessibleButton({
    super.key,
    required this.a11y,
    required this.label,
    required this.semanticHint,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: label,
      hint: semanticHint,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: a11y.minTouchTargetDp, minWidth: a11y.minTouchTargetDp),
        child: FilledButton.icon(
          icon: Icon(icon, size: a11y.motorLargeTargets ? 28 : 22),
          label: Text(label, style: TextStyle(height: a11y.lineHeight)),
          onPressed: onPressed == null
              ? null
              : () {
                  if (a11y.hapticFeedbackEnabled) HapticFeedback.mediumImpact();
                  onPressed!();
                },
        ),
      ),
    );
  }
}

/// Color-Blind Safe Financial Status Badge: NEVER relies on color alone;
/// always combines distinct icon + explicit text prefix + Semantics liveRegion.
class MizanColorBlindSafeBadge extends StatelessWidget {
  final String statusText;
  final bool isPositive;
  final bool isNeutral;

  const MizanColorBlindSafeBadge({
    super.key,
    required this.statusText,
    required this.isPositive,
    this.isNeutral = false,
  });

  @override
  Widget build(BuildContext context) {
    final icon = isNeutral
        ? Icons.info_outline
        : (isPositive ? Icons.check_circle_outline : Icons.warning_amber_rounded);
    final prefix = isNeutral ? '[•]' : (isPositive ? '[+]' : '[!]');

    return Semantics(
      liveRegion: true,
      label: statusText,
      child: Chip(
        avatar: Icon(icon, size: 18),
        label: Text('$prefix $statusText', style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

/// Multi-Sensory Feedback Bridge ensuring Deaf/Hard-of-Hearing & Blind Parity:
/// Every system event simultaneously triggers Visual Caption Banner + Haptic Pattern + Screen Reader Announcement.
class MizanSensoryFeedbackBridge {
  static void notify({
    required BuildContext context,
    required AccessibilityProfileController a11y,
    required String message,
    bool isError = false,
  }) {
    if (a11y.hapticFeedbackEnabled) {
      if (isError) {
        HapticFeedback.heavyImpact();
      } else {
        HapticFeedback.lightImpact();
      }
    }
    if (a11y.visualFlashAlerts || a11y.liveCaptionsEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: (3 * a11y.timeoutMultiplier).round()),
          backgroundColor: isError ? Colors.red.shade900 : Colors.teal.shade900,
          content: Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Icon(isError ? Icons.error_outline : Icons.subtitles, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        ),
      );
    }
  }
}
