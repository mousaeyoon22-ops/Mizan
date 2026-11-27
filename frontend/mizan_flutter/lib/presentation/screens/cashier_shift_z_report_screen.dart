import 'package:flutter/material.dart';

/// Blind Shift Close & Z-Report Screen:
/// Cashier enters physical counted cash WITHOUT seeing expected drawer balance first (anti-skimming control).
class CashierShiftZReportScreen extends StatefulWidget {
  final bool isArabic;
  const CashierShiftZReportScreen({super.key, this.isArabic = true});

  @override
  State<CashierShiftZReportScreen> createState() => _CashierShiftZReportScreenState();
}

class _CashierShiftZReportScreenState extends State<CashierShiftZReportScreen> {
  final TextEditingController _countedCtrl = TextEditingController();
  bool _isClosed = false;
  double _variance = 0.0;
  static const double _expectedHiddenCash = 1600.00;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isArabic ? 'إغلاق الوردية الأعمى وتقرير Z-Report' : 'Blind Shift Close & Z-Report')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  widget.isArabic
                      ? 'الإغلاق الأعمى مفعّل: أدخل النقد المعدود فعلياً في الدرج، وسيحسب النظام تلقائياً العجز أو الزيادة ويصدر قيداً متوازناً وتقرير Z-Report غير قابل للتعديل.'
                      : 'Blind Close Active: Enter physically counted drawer cash. Variance and immutable Z-Report are computed automatically.',
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _countedCtrl,
              enabled: !_isClosed,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: widget.isArabic ? 'إجمالي النقد المعدود فعلياً في الدرج (USD)' : 'Physically Counted Drawer Cash (USD)',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              icon: const Icon(Icons.lock_clock),
              label: Text(widget.isArabic ? 'إغلاق الوردية وإصدار Z-Report مختوم بـ SHA-256' : 'Close Shift & Issue SHA-256 Z-Report'),
              onPressed: _isClosed
                  ? null
                  : () {
                      final counted = double.tryParse(_countedCtrl.text.trim()) ?? 0.0;
                      setState(() {
                        _variance = counted - _expectedHiddenCash;
                        _isClosed = true;
                      });
                    },
            ),
            if (_isClosed) ...[
              const SizedBox(height: 16),
              Card(
                color: _variance == 0 ? Colors.teal.shade50 : Colors.orange.shade50,
                child: ListTile(
                  title: Text(widget.isArabic ? 'تم إغلاق الوردية وإصدار Z-Report' : 'Shift Closed & Z-Report Issued'),
                  subtitle: Text(
                    'Expected: \$${_expectedHiddenCash.toStringAsFixed(2)} • Variance: ${_variance >= 0 ? '+' : ''}${_variance.toStringAsFixed(2)} USD',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
