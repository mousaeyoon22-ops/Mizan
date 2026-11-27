import 'package:flutter_test/flutter_test.dart';
import 'package:mizan_app/core/money/money_minor.dart';

void main() {
  test('Exact decimal parsing and FX conversion with zero IEEE-754 float drift', () {
    final eur = MoneyMinor.parse('123.45', 'EUR');
    final usd = eur.convertTo('USD', 1083700); // 1.083700
    expect(usd.toDecimalString(displayDecimals: 4), '133.7828');
    expect(usd.currency, 'USD');
  });

  test('Currency mismatch throws StateError', () {
    final a = MoneyMinor.parse('10.00', 'USD');
    final b = MoneyMinor.parse('10.00', 'EUR');
    expect(() => a + b, throwsStateError);
  });
}
