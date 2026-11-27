import 'package:flutter/material.dart';
import '../models/mizan_models.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';

class FxScreen extends StatefulWidget {
  final MizanStore store;
  const FxScreen({super.key, required this.store});

  @override
  State<FxScreen> createState() => _FxScreenState();
}

class _FxScreenState extends State<FxScreen> {
  MizanAccount? _from;
  MizanAccount? _to;
  final _amtCtrl = TextEditingController(text: '1000');
  final _bookCtrl = TextEditingController(text: '3.75');
  final _appliedCtrl = TextEditingController(text: '3.72');

  @override
  void initState() {
    super.initState();
    final boxes = widget.store.accounts.where((a) => a.type == AccountType.cashbox).toList();
    if (boxes.isNotEmpty) _from = boxes.first;
    if (boxes.length > 1) _to = boxes[1];
  }

  @override
  void dispose() {
    _amtCtrl.dispose();
    _bookCtrl.dispose();
    _appliedCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boxes = widget.store.accounts.where((a) => a.type == AccountType.cashbox).toList();
    final amt = double.tryParse(_amtCtrl.text) ?? 0;
    final book = double.tryParse(_bookCtrl.text) ?? 1;
    final applied = double.tryParse(_appliedCtrl.text) ?? 1;
    final actualDest = amt * applied;
    final fxDiff = actualDest - (amt * book);

    return Scaffold(
      appBar: AppBar(title: const Text('سند مصارفة وتحويل عملات (IAS 21)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MizanCard(
            child: Column(
              children: [
                DropdownButtonFormField<MizanAccount>(
                  value: _from,
                  decoration: const InputDecoration(labelText: 'الصندوق المحوّل منه'),
                  items: boxes.map((b) => DropdownMenuItem(value: b, child: Text('${b.name} (${fmtMoney(b.balance, b.currency)})'))).toList(),
                  onChanged: (v) => setState(() => _from = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<MizanAccount>(
                  value: _to,
                  decoration: const InputDecoration(labelText: 'الصندوق المستلم'),
                  items: boxes.map((b) => DropdownMenuItem(value: b, child: Text('${b.name} (${fmtMoney(b.balance, b.currency)})'))).toList(),
                  onChanged: (v) => setState(() => _to = v),
                ),
                const SizedBox(height: 10),
                TextField(controller: _amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المحوّل'), onChanged: (_) => setState(() {})),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _bookCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر الدفتري (Book)'), onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 10),
                    Expanded(child: TextField(controller: _appliedCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر المطبّق (Applied)'), onChanged: (_) => setState(() {}))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MizanCard(
            color: (fxDiff >= 0 ? MizanColors.success : MizanColors.accent).withValues(alpha: 0.12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المبلغ المستلم الفعلي: ${actualDest.toStringAsFixed(2)} ${_to?.currency ?? ""}', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  fxDiff >= 0
                      ? 'ربح فروقات عملة (IAS 21): +${fxDiff.toStringAsFixed(2)} ${_to?.currency ?? ""}'
                      : 'مصروف / خسارة فروقات عملة (IAS 21): ${fxDiff.toStringAsFixed(2)} ${_to?.currency ?? ""}',
                  style: TextStyle(fontWeight: FontWeight.w800, color: fxDiff >= 0 ? MizanColors.success : MizanColors.danger),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {
              if (_from == null || _to == null || _from!.id == _to!.id || amt <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر صندوقين مختلفين ومبلغاً صحيحاً')));
                return;
              }
              widget.store.postFxExchange(fromCashbox: _from!, toCashbox: _to!, sourceAmount: amt, bookRate: book, appliedRate: applied);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم ترحيل سند المصارفة وتحديث أرصدة الصندوقين')));
              Navigator.pop(context);
            },
            icon: const Icon(Icons.currency_exchange_rounded),
            label: const Text('ترحيل سند المصارفة بقيد مزدوج متوازن'),
          ),
        ],
      ),
    );
  }
}
