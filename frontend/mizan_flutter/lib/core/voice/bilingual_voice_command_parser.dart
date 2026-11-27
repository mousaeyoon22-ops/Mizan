/// On-Device Offline-Capable Bilingual (Arabic + English) Voice Command Parser.
/// Mirrors `VoiceCommandGovernanceService.cs` so merchants & employees with special needs
/// can operate Mizan hands-free even when internet drops.
enum LocalVoiceIntent {
  queryBalance,
  queryStock,
  navigate,
  createSaleInvoice,
  recordCashReceipt,
  recordCashPayment,
  confirmDraft,
  cancelDraft,
  unknown,
}

class ParsedVoiceCommand {
  final LocalVoiceIntent intent;
  final bool requiresTwoStepConfirmation;
  final int? amountMinor; // x10000 exact integer minor units
  final String currency;
  final String normalizedTranscript;

  const ParsedVoiceCommand({
    required this.intent,
    required this.requiresTwoStepConfirmation,
    required this.amountMinor,
    required this.currency,
    required this.normalizedTranscript,
  });
}

class BilingualVoiceCommandParser {
  static String _normalizeArabicDigits(String input) {
    const map = {
      '٠': '0', '١': '1', '٢': '2', '٣': '3', '٤': '4',
      '٥': '5', '٦': '6', '٧': '7', '٨': '8', '٩': '9',
    };
    final sb = StringBuffer();
    for (final ch in input.split('')) {
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }

  static ParsedVoiceCommand parse(String rawTranscript) {
    final norm = _normalizeArabicDigits(rawTranscript.trim());
    final lower = norm.toLowerCase();

    if (lower.contains('تأكيد الترحيل') || lower == 'تأكيد' || lower.contains('confirm post') || lower == 'confirm') {
      return ParsedVoiceCommand(
        intent: LocalVoiceIntent.confirmDraft,
        requiresTwoStepConfirmation: false,
        amountMinor: null,
        currency: 'USD',
        normalizedTranscript: norm,
      );
    }

    if (lower.contains('إلغاء') || lower.contains('الغاء') || lower.contains('cancel')) {
      return ParsedVoiceCommand(
        intent: LocalVoiceIntent.cancelDraft,
        requiresTwoStepConfirmation: false,
        amountMinor: null,
        currency: 'USD',
        normalizedTranscript: norm,
      );
    }

    String currency = 'USD';
    if (lower.contains('ريال سعودي') || lower.contains('sar')) currency = 'SAR';
    else if (lower.contains('ريال يمني') || lower.contains('yer')) currency = 'YER';
    else if (lower.contains('درهم') || lower.contains('aed')) currency = 'AED';
    else if (lower.contains('يورو') || lower.contains('eur')) currency = 'EUR';

    int? amountMinor;
    final match = RegExp(r'(\d+(?:[.,]\d{1,4})?)').firstMatch(lower);
    if (match != null) {
      final numStr = match.group(1)!.replaceAll(',', '.');
      final parts = numStr.split('.');
      final whole = int.parse(parts[0]);
      final frac = parts.length == 2 ? int.parse(parts[1].padRight(4, '0').substring(0, 4)) : 0;
      amountMinor = whole * 10000 + frac;
    }

    if (lower.contains('رصيد') || lower.contains('balance')) {
      return ParsedVoiceCommand(intent: LocalVoiceIntent.queryBalance, requiresTwoStepConfirmation: false, amountMinor: null, currency: currency, normalizedTranscript: norm);
    }
    if (lower.contains('مخزون') || lower.contains('stock')) {
      return ParsedVoiceCommand(intent: LocalVoiceIntent.queryStock, requiresTwoStepConfirmation: false, amountMinor: null, currency: currency, normalizedTranscript: norm);
    }
    if (lower.contains('افتح') || lower.contains('open')) {
      return ParsedVoiceCommand(intent: LocalVoiceIntent.navigate, requiresTwoStepConfirmation: false, amountMinor: null, currency: currency, normalizedTranscript: norm);
    }
    if (lower.contains('فاتورة بيع') || lower.contains('sale invoice') || lower.contains('sell')) {
      return ParsedVoiceCommand(intent: LocalVoiceIntent.createSaleInvoice, requiresTwoStepConfirmation: true, amountMinor: amountMinor, currency: currency, normalizedTranscript: norm);
    }
    if (lower.contains('سند قبض') || lower.contains('قبض') || lower.contains('receipt')) {
      return ParsedVoiceCommand(intent: LocalVoiceIntent.recordCashReceipt, requiresTwoStepConfirmation: true, amountMinor: amountMinor, currency: currency, normalizedTranscript: norm);
    }
    if (lower.contains('سند صرف') || lower.contains('صرف') || lower.contains('pay cash')) {
      return ParsedVoiceCommand(intent: LocalVoiceIntent.recordCashPayment, requiresTwoStepConfirmation: true, amountMinor: amountMinor, currency: currency, normalizedTranscript: norm);
    }

    return ParsedVoiceCommand(intent: LocalVoiceIntent.unknown, requiresTwoStepConfirmation: false, amountMinor: amountMinor, currency: currency, normalizedTranscript: norm);
  }
}
