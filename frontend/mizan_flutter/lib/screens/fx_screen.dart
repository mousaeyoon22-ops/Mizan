import 'package:flutter/material.dart';
import '../db/mizan_database.dart';
import '../models/mizan_models.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';

class FxScreen extends StatefulWidget {
  final MizanStore store;
  const FxScreen({super.key, required this.store});

  @override
  State<FxScreen> createState() => _FxScreenState();
}

class _FxScreenState extends State<FxScreen> {
  final _amtCtrl = TextEditingController(text: '1000');
  String _fromCurr = 'SAR';

  @override
  void dispose() {
    _amtCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final amt = double.tryParse(_amtCtrl.text) ?? 0;
    final rate = s.fxRateFor(_fromCurr);
    final converted = amt * rate;

    return Scaffold(
      appBar: AppBar(title: Text(s.t('fx_center'))),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('محول العملات (عملة الدفاتر: ${s.bookCurrency})', style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amtCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'المبلغ'),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      DropdownButton<String>(
                        value: _fromCurr,
                        items: ['USD', 'SAR', 'YER', 'AED', 'EUR']
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: (v) => setState(() => _fromCurr = v ?? 'SAR'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '= ${converted.toStringAsFixed(2)} ${s.bookCurrency} (سعر الصرف الساري: $rate)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: MizanColors.primary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _openAddRateDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('سعر صرف بتاريخ سريان'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openRevaluationDialog(context),
                  icon: const Icon(Icons.balance_outlined),
                  label: const Text('إعادة تقييم IAS 21'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('سجل أسعار الصرف التاريخية (Effective-Dated)', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...s.fxRates.map((r) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text('${r.currencyCode} — ${r.currencyName}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('تاريخ السريان: ${r.effectiveFrom.toIso8601String().substring(0, 16)}'),
                  trailing: Text(
                    '1 ${r.currencyCode} = ${r.rateToBook} ${s.bookCurrency}',
                    style: const TextStyle(fontWeight: FontWeight.w800, color: MizanColors.primary),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  void _openAddRateDialog(BuildContext context) {
    final codeCtrl = TextEditingController(text: 'SAR');
    final nameCtrl = TextEditingController(text: 'Saudi Riyal');
    final rateCtrl = TextEditingController(text: '0.2667');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة سعر صرف بتاريخ سريان جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'رمز العملة (مثل SAR, EUR, YER)')),
            const SizedBox(height: 8),
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم العملة')),
            const SizedBox(height: 8),
            TextField(controller: rateCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'المعادل بعملة الدفاتر (${widget.store.bookCurrency})')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(widget.store.t('cancel'))),
          FilledButton(
            onPressed: () async {
              await widget.store.addFxRate(FxRateRecord(
                id: MizanUuidV7.next(),
                currencyCode: codeCtrl.text.trim().toUpperCase(),
                currencyName: nameCtrl.text.trim(),
                rateToBook: double.tryParse(rateCtrl.text) ?? 1.0,
                effectiveFrom: DateTime.now(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(widget.store.t('save')),
          ),
        ],
      ),
    );
  }

  void _openRevaluationDialog(BuildContext context) {
    if (widget.store.accounts.isEmpty) return;
    String accId = widget.store.accounts.first.id;
    final diffCtrl = TextEditingController(text: '25');
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('ترحيل فروق إعادة التقييم (IAS 21)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: accId,
                decoration: const InputDecoration(labelText: 'الحساب المعاد تقييمه'),
                items: widget.store.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                onChanged: (v) => setSt(() => accId = v ?? accId),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: diffCtrl,
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                decoration: const InputDecoration(labelText: 'فارق التقييم (+ ربح / - خسارة)'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(widget.store.t('cancel'))),
            FilledButton(
              onPressed: () async {
                final err = await widget.store.postFxRevaluation(
                  accountId: accId,
                  revaluationDiffBook: double.tryParse(diffCtrl.text) ?? 0,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err ?? 'تم ترحيل قيد فروق العملة IAS 21 بنجاح.')),
                  );
                }
              },
              child: const Text('ترحيل القيد'),
            ),
          ],
        ),
      ),
    );
  }
}
