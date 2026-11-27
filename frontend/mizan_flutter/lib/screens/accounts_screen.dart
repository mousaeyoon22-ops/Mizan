import 'package:flutter/material.dart';
import '../models/mizan_models.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';

class AccountsScreen extends StatefulWidget {
  final MizanStore store;
  const AccountsScreen({super.key, required this.store});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  AccountType? _filter;

  String _typeLabel(AccountType t) => switch (t) {
        AccountType.customer => 'العملاء',
        AccountType.supplier => 'الموردون',
        AccountType.cashbox => 'الصناديق والبنوك',
        AccountType.employee => 'الموظفون',
        AccountType.expense => 'المصاريف',
        AccountType.asset => 'الأصول',
      };

  void _openAddAccount() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final balCtrl = TextEditingController(text: '0');
    AccountType type = _filter ?? AccountType.customer;
    String currency = 'USD';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إضافة حساب / عميل / صندوق جديد', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountType>(
                value: type,
                decoration: const InputDecoration(labelText: 'تصنيف الحساب'),
                items: AccountType.values.map((t) => DropdownMenuItem(value: t, child: Text(_typeLabel(t)))).toList(),
                onChanged: (v) => setS(() => type = v ?? type),
              ),
              const SizedBox(height: 10),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم الكامل')),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'رقم الهاتف (اختياري)'))),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: currency,
                      decoration: const InputDecoration(labelText: 'العملة'),
                      items: const ['USD', 'SAR', 'YER'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setS(() => currency = v ?? 'USD'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(controller: balCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الرصيد الافتتاحي')),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () {
                  if (nameCtrl.text.trim().isEmpty) return;
                  widget.store.addAccount(
                    name: nameCtrl.text.trim(),
                    type: type,
                    currency: currency,
                    phone: phoneCtrl.text.trim(),
                    openingBalance: double.tryParse(balCtrl.text) ?? 0,
                  );
                  Navigator.pop(ctx);
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('حفظ الحساب'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStatement(MizanAccount acc) {
    final rows = widget.store.statementForAccount(acc.id);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        builder: (_, sc) => ListView(
          controller: sc,
          padding: const EdgeInsets.all(16),
          children: [
            Text('كشف حساب: ${acc.name}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text('رقم الحساب: ${acc.code} • الرصيد الحالي: ${fmtMoney(acc.balance, acc.currency)}', style: const TextStyle(color: MizanColors.primary, fontWeight: FontWeight.w700)),
            const Divider(height: 22),
            if (rows.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('لا توجد حركات مسجلة على هذا الحساب بعد', style: TextStyle(color: MizanColors.muted))))
            else
              ...rows.map((r) {
                final isDebit = r.debitAccountId == acc.id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: MizanCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(isDebit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, color: isDebit ? MizanColors.success : MizanColors.danger, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.description, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                              Text('${r.refNo} • ${fmtDate(r.date)}', style: const TextStyle(fontSize: 11, color: MizanColors.muted)),
                            ],
                          ),
                        ),
                        Text(
                          '${isDebit ? "مدين" : "دائن"} ${r.amount.toStringAsFixed(2)}',
                          style: TextStyle(fontWeight: FontWeight.w800, color: isDebit ? MizanColors.success : MizanColors.danger),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filter == null ? widget.store.accounts : widget.store.accounts.where((a) => a.type == _filter).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('دليل الحسابات والأطراف'),
        actions: [
          FilledButton.icon(
            onPressed: _openAddAccount,
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
            label: const Text('إضافة حساب'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
            child: Row(
              children: [
                FilterChip(label: const Text('الكل'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null)),
                const SizedBox(width: 8),
                ...AccountType.values.map((t) => Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: FilterChip(
                        label: Text(_typeLabel(t)),
                        selected: _filter == t,
                        onSelected: (_) => setState(() => _filter = t),
                      ),
                    )),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final a = list[i];
                return MizanCard(
                  onTap: () => _openStatement(a),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: MizanColors.primarySoft,
                        foregroundColor: MizanColors.primary,
                        child: Text(a.code.substring(0, 2), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('${a.code} • ${_typeLabel(a.type)}${a.phone.isNotEmpty ? " • ${a.phone}" : ""}', style: const TextStyle(fontSize: 12, color: MizanColors.muted)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            fmtMoney(a.balance, a.currency),
                            style: TextStyle(fontWeight: FontWeight.w900, color: a.balance >= 0 ? MizanColors.success : MizanColors.danger),
                          ),
                          const Text('كشف الحساب ←', style: TextStyle(fontSize: 10.5, color: MizanColors.muted)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
