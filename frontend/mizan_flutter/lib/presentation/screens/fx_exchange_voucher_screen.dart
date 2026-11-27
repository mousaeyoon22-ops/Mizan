import 'package:flutter/material.dart';
import '../../core/fx/fx_calculator.dart';

/// Direct Currency Exchange Voucher (سند المصارفة) screen.
/// Shows real-time FX Gain/Loss (فرق المصارفة) in base currency before posting.
class FxExchangeVoucherScreen extends StatefulWidget {
  final bool isArabic;
  const FxExchangeVoucherScreen({super.key, this.isArabic = true});

  @override
  State<FxExchangeVoucherScreen> createState() => _FxExchangeVoucherScreenState();
}

class _FxExchangeVoucherScreenState extends State<FxExchangeVoucherScreen> {
  String _sourceCurrency = 'USD';
  String _targetCurrency = 'SAR';
  final int _sourceAmountMinor = 10000000;   // 1,000.0000 USD
  final int _sourceBookRateMicro = 3750000;  // 3.750000 SAR/USD
  final int _targetAmountMinor = 37200000;   // 3,720.0000 SAR received
  final int _targetBookRateMicro = 1000000;  // 1.000000 (SAR is base)

  @override
  Widget build(BuildContext context) {
    final preview = FxCalculator.computeDirectExchange(
      sourceAmountMinor: _sourceAmountMinor,
      sourceBookRateMicro: _sourceBookRateMicro,
      targetAmountMinor: _targetAmountMinor,
      targetBookRateMicro: _targetBookRateMicro,
    );

    final diffText = (preview.fxDiffBaseMinor.abs() / 10000).toStringAsFixed(2);
    final label = preview.isLoss
        ? (widget.isArabic ? 'مصروف / فرق مصارفة (خسارة)' : 'FX Exchange Expense (Loss)')
        : (widget.isArabic ? 'إيراد / ربح مصارفة' : 'FX Exchange Gain');

    return Scaffold(
      appBar: AppBar(title: Text(widget.isArabic ? 'سند مصارفة وتحويل عملات (IAS 21)' : 'Currency Exchange Voucher (IAS 21)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                title: Text('${widget.isArabic ? 'الصندوق المحوَّل منه' : 'From Box'}: $_sourceCurrency'),
                subtitle: Text('1,000.00 $_sourceCurrency @ Book 3.7500 = ${(preview.sourceBaseMinor / 10000).toStringAsFixed(2)} SAR'),
              ),
            ),
            Card(
              child: ListTile(
                title: Text('${widget.isArabic ? 'الصندوق المستلم' : 'To Box'}: $_targetCurrency'),
                subtitle: Text('3,720.00 $_targetCurrency (Applied Rate: 3.7200)'),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              color: preview.isLoss ? Colors.orange.shade50 : Colors.teal.shade50,
              child: ListTile(
                leading: Icon(preview.isLoss ? Icons.trending_down : Icons.trending_up),
                title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                trailing: Text('$diffText SAR', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {},
              child: Text(widget.isArabic ? 'ترحيل سند المصارفة بقيد مزدوج متوازن' : 'Post Balanced FX Exchange Entry'),
            ),
          ],
        ),
      ),
    );
  }
}
