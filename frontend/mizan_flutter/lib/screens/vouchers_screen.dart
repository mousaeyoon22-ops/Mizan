import 'package:flutter/material.dart';
import '../models/mizan_models.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';

class VouchersScreen extends StatefulWidget {
  final MizanStore store;
  const VouchersScreen({super.key, required this.store});

  @override
  State<VouchersScreen> createState() => _VouchersScreenState();
}

class _VouchersScreenState extends State<VouchersScreen> {
  VoucherType _type = VoucherType.receipt;
  MizanAccount? _cashbox;
  MizanAccount? _counter;
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final boxes = widget.store.accounts.where((a) => a.type == AccountType.cashbox).toList();
    if (boxes.isNotEmpty) _cashbox = boxes.first;
    final others = widget.store.accounts.where((a) => a.id != _cashbox?.id).toList();
    if (others.isNotEmpty) _counter = others.first;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  void _post() {
    final amt = double.tryParse(_amountCtrl.text) ?? 0.0;
    if (amt <= 0 || _cashbox == null || _counter == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل مبلغاً صحيحاً واختر الحسابين')));
      return;
    }
    widget.store.postVoucher(
      type: _type,
      cashbox: _cashbox!,
      counterAccount: _counter!,
      amount: amt,
      note: _noteCtrl.text.trim(),
    );
    _amountCtrl.clear();
    _noteCtrl.clear();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم ترحيل السند والقيد المزدوج بنجاح')));
  }

  @override
  Widget build(BuildContext context) {
    final boxes = widget.store.accounts.where((a) => a.type == AccountType.cashbox).toList();
    final all = widget.store.accounts;

    return Scaffold(
      appBar: AppBar(title: const Text('السندات والقيود اليومية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<VoucherType>(
            segments: const [
              ButtonSegment(value: VoucherType.receipt, label: Text('سند قبض')),
              ButtonSegment(value: VoucherType.payment, label: Text('سند صرف')),
              ButtonSegment(value: VoucherType.journal, label: Text('قيد / تحويل')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          MizanCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<MizanAccount>(
                  value: _cashbox,
                  decoration: InputDecoration(labelText: _type == VoucherType.journal ? 'الحساب الدائن (من)' : 'الصندوق / البنك'),
                  items: (_type == VoucherType.journal ? all : boxes)
                      .map((a) => DropdownMenuItem(value: a, child: Text('${a.name} (${fmtMoney(a.balance, a.currency)})')))
                      .toList(),
                  onChanged: (v) => setState(() => _cashbox = v),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<MizanAccount>(
                  value: _counter,
                  decoration: InputDecoration(labelText: _type == VoucherType.journal ? 'الحساب المدين (إلى)' : 'الحساب المقابل (عميل / مورد / مصروف)'),
                  items: all.map((a) => DropdownMenuItem(value: a, child: Text('${a.code} • ${a.name}'))).toList(),
                  onChanged: (v) => setState(() => _counter = v),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'المبلغ', prefixIcon: Icon(Icons.attach_money_rounded)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteCtrl,
                  decoration: const InputDecoration(labelText: 'البيان / الملاحظة'),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _post,
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('ترحيل السند بقيد مزدوج متوازن'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('سجل الحركة اليومية والقيود', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ...widget.store.ledger.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MizanCard(
                  padding: const EdgeInsets.all(13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(e.refNo, style: const TextStyle(fontWeight: FontWeight.w800, color: MizanColors.primary)),
                          const Spacer(),
                          Text(fmtMoney(e.amount, e.currency), style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(e.description, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(child: Text('مدين: ${e.debitAccountName}  |  دائن: ${e.creditAccountName}', style: const TextStyle(fontSize: 11.5, color: MizanColors.muted))),
                          if (e.category != 'REVERSAL')
                            TextButton(
                              onPressed: () {
                                widget.store.reverseLedgerEntry(e);
                                setState(() {});
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم إنشاء قيد عكسي لـ ${e.refNo} دون حذف السجل الأصلي')));
                              },
                              child: const Text('قيد عكسي', style: TextStyle(fontSize: 12, color: MizanColors.accent, fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
