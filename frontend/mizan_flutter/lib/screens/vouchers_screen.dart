import 'package:flutter/material.dart';
import '../engine/ifrs_engine.dart';
import '../models/mizan_models.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';

class VouchersScreen extends StatelessWidget {
  final MizanStore store;
  const VouchersScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(store.t('nav_vouchers')),
        actions: [
          IconButton(
            tooltip: 'لصق رسالة حوالة ذكي',
            icon: const Icon(Icons.sms_outlined),
            onPressed: () => _openRemittanceParserDialog(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (store.journals.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('لا توجد قيود يومية بعد. اضغط «قيد مركّب جديد» أو استخدم محلل رسائل الحوالات الذكي بالأعلى.'),
              ),
            ),
          ...store.journals.map((j) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('${j.refNo} — ${j.description}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          MizanBadge(
                            text: j.category,
                            color: j.category == 'REVERSAL' ? MizanColors.accent : MizanColors.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...j.lines.map((l) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Row(
                              children: [
                                Expanded(child: Text(l.accountName, style: const TextStyle(fontSize: 12.5))),
                                Text(
                                  l.debit > 0
                                      ? 'مدين ${l.debit.toStringAsFixed(2)} ${l.currency}'
                                      : 'دائن ${l.credit.toStringAsFixed(2)} ${l.currency}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: l.debit > 0 ? MizanColors.primary : MizanColors.info,
                                  ),
                                ),
                              ],
                            ),
                          )),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SHA-256: ${j.sha256Hash.substring(0, 12)}…',
                            style: const TextStyle(fontSize: 11, color: MizanColors.muted),
                          ),
                          if (j.reversedOfId == null)
                            TextButton.icon(
                              onPressed: () async {
                                final err = await store.reverseJournal(j.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(err ?? 'تم إنشاء قيد عكسي متوازن مع حفظ القيد الأصلي للتدقيق.')),
                                  );
                                }
                              },
                              icon: const Icon(Icons.undo_rounded, size: 16),
                              label: Text(store.t('reverse_entry')),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCompoundJournalDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('قيد مركّب جديد'),
      ),
    );
  }

  void _openRemittanceParserDialog(BuildContext context) {
    final smsCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('لصق رسالة الحوالة (تعبئة ذكية)'),
        content: TextField(
          controller: smsCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'مثال: تم استلام حوالة رقم 98231 بمبلغ 500 ريال سعودي من شركة النور',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
          FilledButton(
            onPressed: () async {
              final parsed = IfrsEngine.parseRemittanceText(smsCtrl.text);
              Navigator.pop(ctx);
              if (parsed.amount == null || parsed.amount! <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لم يُعثر على مبلغ رقمي واضح في الرسالة.')),
                );
                return;
              }
              final fx = store.fxRateFor(parsed.currency);
              final err = await store.postCompoundJournal(
                description: 'سند قبض حوالة ${parsed.reference} من ${parsed.sender}',
                category: 'REMITTANCE_SMS',
                lines: [
                  JournalLine(id: '', headerId: '', accountId: 'acc-cash', accountName: 'الصندوق الرئيسي', debit: parsed.amount!, credit: 0, currency: parsed.currency, fxRate: fx),
                  JournalLine(id: '', headerId: '', accountId: 'acc-walkin', accountName: parsed.sender, debit: 0, credit: parsed.amount!, currency: parsed.currency, fxRate: fx),
                ],
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err ?? 'تم ترحيل سند الحوالة (${parsed.amount} ${parsed.currency}) آلياً!')),
                );
              }
            },
            child: const Text('تحليل وترحيل السند'),
          ),
        ],
      ),
    );
  }

  void _openCompoundJournalDialog(BuildContext context) {
    if (store.accounts.length < 2) return;
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController(text: '100');
    String drId = store.accounts.first.id;
    String crId = store.accounts[1].id;
    String curr = store.bookCurrency;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('إنشاء سند / قيد يومية'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'البيان / الوصف')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: drId,
                  decoration: const InputDecoration(labelText: 'الحساب المدين'),
                  items: store.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.code} - ${a.name}'))).toList(),
                  onChanged: (v) => setSt(() => drId = v ?? drId),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: crId,
                  decoration: const InputDecoration(labelText: 'الحساب الدائن'),
                  items: store.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text('${a.code} - ${a.name}'))).toList(),
                  onChanged: (v) => setSt(() => crId = v ?? crId),
                ),
                const SizedBox(height: 8),
                TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: curr,
                  decoration: InputDecoration(labelText: store.t('currency')),
                  items: ['USD', 'SAR', 'YER', 'AED', 'EUR'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setSt(() => curr = v ?? store.bookCurrency),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
            FilledButton(
              onPressed: () async {
                final amt = double.tryParse(amtCtrl.text) ?? 0;
                final dr = store.accounts.firstWhere((a) => a.id == drId);
                final cr = store.accounts.firstWhere((a) => a.id == crId);
                final fx = store.fxRateFor(curr);
                final err = await store.postCompoundJournal(
                  description: descCtrl.text.trim().isEmpty ? 'قيد يومية مباشر' : descCtrl.text.trim(),
                  category: 'JOURNAL',
                  lines: [
                    JournalLine(id: '', headerId: '', accountId: dr.id, accountName: dr.name, debit: amt, credit: 0, currency: curr, fxRate: fx),
                    JournalLine(id: '', headerId: '', accountId: cr.id, accountName: cr.name, debit: 0, credit: amt, currency: curr, fxRate: fx),
                  ],
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err ?? 'تم ترحيل القيد وتوثيقه بسلسلة SHA-256.')),
                  );
                }
              },
              child: Text(store.t('save')),
            ),
          ],
        ),
      ),
    );
  }
}
