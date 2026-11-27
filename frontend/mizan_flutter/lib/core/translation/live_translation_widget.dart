import 'package:flutter/material.dart';

/// Feature-gated inline translation widget for cross-border invoices, catalog items, and chat.
/// Renders cleanly as plain original text when INSTANT_CROSS_BORDER_TRANSLATION is OFF (Store-compliant).
class LiveTranslatableText extends StatelessWidget {
  final String originalText;
  final String? translatedText;
  final bool isInstantTranslationEnabled;
  final VoidCallback? onRequestTranslate;

  const LiveTranslatableText({
    super.key,
    required this.originalText,
    this.translatedText,
    required this.isInstantTranslationEnabled,
    this.onRequestTranslate,
  });

  @override
  Widget build(BuildContext context) {
    if (!isInstantTranslationEnabled) {
      return Text(originalText);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(translatedText ?? originalText),
        if (translatedText != null)
          Text(originalText, style: const TextStyle(fontSize: 11, color: Colors.black54)),
        if (translatedText == null && onRequestTranslate != null)
          TextButton.icon(
            onPressed: onRequestTranslate,
            icon: const Icon(Icons.translate, size: 16),
            label: const Text('ترجمة فورية / Translate'),
          ),
      ],
    );
  }
}
