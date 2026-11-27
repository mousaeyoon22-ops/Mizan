/// Strict integer minor-unit monetary value (scale = 10,000 => 4 decimal places).
/// Mirrors PostgreSQL NUMERIC(18,4) and C# decimal with ZERO IEEE-754 double drift.
class MoneyMinor implements Comparable<MoneyMinor> {
  static const int scale = 10000;

  final int minorUnits;
  final String currency;

  MoneyMinor._(this.minorUnits, this.currency);

  factory MoneyMinor.fromMinor(int minorUnits, String currency) {
    final code = currency.trim().toUpperCase();
    if (code.length != 3) {
      throw ArgumentError('Currency must be a 3-letter ISO-4217 code.');
    }
    return MoneyMinor._(minorUnits, code);
  }

  /// Parses decimal string like "123.45" or "10.1234" without passing through double.
  factory MoneyMinor.parse(String decimalStr, String currency) {
    final trimmed = decimalStr.trim();
    if (trimmed.isEmpty) throw FormatException('Empty money string');
    final isNeg = trimmed.startsWith('-');
    final unsigned = isNeg ? trimmed.substring(1) : trimmed;
    final parts = unsigned.split('.');
    if (parts.length > 2) throw FormatException('Invalid decimal: $decimalStr');

    final whole = int.parse(parts[0].isEmpty ? '0' : parts[0]);
    final fracRaw = parts.length == 2 ? parts[1] : '';
    final fracPadded = fracRaw.padRight(4, '0').substring(0, 4);
    final frac = int.parse(fracPadded);

    final total = whole * scale + frac;
    return MoneyMinor.fromMinor(isNeg ? -total : total, currency);
  }

  factory MoneyMinor.zero(String currency) => MoneyMinor.fromMinor(0, currency);

  MoneyMinor operator +(MoneyMinor other) {
    _ensureSameCurrency(other);
    return MoneyMinor.fromMinor(minorUnits + other.minorUnits, currency);
  }

  MoneyMinor operator -(MoneyMinor other) {
    _ensureSameCurrency(other);
    return MoneyMinor.fromMinor(minorUnits - other.minorUnits, currency);
  }

  /// Multiply by quantity represented in minor units (x10000) with half-away-from-zero rounding.
  MoneyMinor multiplyByQtyMinor(int qtyMinor) {
    final product = BigInt.from(minorUnits) * BigInt.from(qtyMinor);
    final half = BigInt.from(scale ~/ 2);
    final rounded = product >= BigInt.zero
        ? (product + half) ~/ BigInt.from(scale)
        : (product - half) ~/ BigInt.from(scale);
    return MoneyMinor.fromMinor(rounded.toInt(), currency);
  }

  /// Convert currency using exchange rate scaled by 1,000,000 (matching PostgreSQL NUMERIC(18,6)).
  MoneyMinor convertTo(String targetCurrency, int fxRateMicro) {
    if (fxRateMicro <= 0) throw ArgumentError('Exchange rate must be positive.');
    final product = BigInt.from(minorUnits) * BigInt.from(fxRateMicro);
    const divisor = 1000000;
    final half = BigInt.from(divisor ~/ 2);
    final rounded = product >= BigInt.zero
        ? (product + half) ~/ BigInt.from(divisor)
        : (product - half) ~/ BigInt.from(divisor);
    return MoneyMinor.fromMinor(rounded.toInt(), targetCurrency);
  }

  String toDecimalString({int displayDecimals = 2}) {
    final isNeg = minorUnits < 0;
    final absVal = minorUnits.abs();
    final whole = absVal ~/ scale;
    final frac = (absVal % scale).toString().padLeft(4, '0');
    final shownFrac = displayDecimals >= 4 ? frac : frac.substring(0, displayDecimals);
    return '${isNeg ? '-' : ''}$whole.$shownFrac';
  }

  String formatDisplay({int decimals = 2}) => '${toDecimalString(displayDecimals: decimals)} $currency';

  void _ensureSameCurrency(MoneyMinor other) {
    if (currency != other.currency) {
      throw StateError('Currency mismatch: $currency vs ${other.currency}');
    }
  }

  @override
  int compareTo(MoneyMinor other) {
    _ensureSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      other is MoneyMinor && minorUnits == other.minorUnits && currency == other.currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);
}
