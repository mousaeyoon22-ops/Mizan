import 'package:flutter/material.dart';
import '../db/mizan_database.dart';
import '../l10n/mizan_l10n.dart';
import '../models/mizan_models.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';

class AccountsScreen extends StatelessWidget {
  final MizanStore store;
  const AccountsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(store.t('nav_accounts')),
          actions: [
            IconButton(
              tooltip: 'إقفال الفترة المالية',
              icon: Icon(store.fiscalLockDate != null ? Icons.lock : Icons.lock_open),
              onPressed: () => _toggleFiscalLock(context),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'دليل الحسابات'),
              Tab(text: 'الأصول الثابتة'),
              Tab(text: 'الموازنات'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildAccountsTab(context),
            _buildFixedAssetsTab(context),
            _buildBudgetsTab(context),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showAddAccountDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('حساب جديد'),
        ),
      ),
    );
  }

  Widget _buildAccountsTab(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: store.accounts.length,
      itemBuilder: (ctx, i) {
        final a = store.accounts[i];
        final displayName = MizanL10n.localizedName(store.languageCode, a.name, a.nameI18n);
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: MizanColors.primarySoft,
              child: Text(a.code.length >= 2 ? a.code.substring(0, 2) : a.code,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: MizanColors.primary)),
            ),
            title: Text('$displayName (${a.code})', style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Wrap(
              spacing: 6,
              children: [
                Text('${a.type.name} · ${a.currency} · ${a.defaultWarehouse}'),
                if (a.isOverCreditLimit)
                  const MizanBadge(text: 'تجاوز سقف المديونية!', color: MizanColors.danger),
              ],
            ),
            trailing: Text(
              '${a.balance.toStringAsFixed(2)} ${a.currency}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: a.balance >= 0 ? MizanColors.primary : MizanColors.danger,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFixedAssetsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        FilledButton.icon(
          onPressed: () => _showAddAssetDialog(context),
          icon: const Icon(Icons.add_business_outlined),
          label: const Text('تسجيل أصل ثابت جديد'),
        ),
        const SizedBox(height: 12),
        if (store.fixedAssets.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('لا توجد أصول ثابتة مسجلة بعد. أضف مركبة أو معدة لتشغيل الإهلاك الشهري الآلي.'),
            ),
          ),
        ...store.fixedAssets.map((fa) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(fa.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  'التكلفة: ${fa.acquisitionCost.toStringAsFixed(2)} · مجمع الإهلاك: ${fa.accumulatedDepreciation.toStringAsFixed(2)} · الصافي: ${fa.netBookValue.toStringAsFixed(2)}',
                ),
                trailing: OutlinedButton(
                  onPressed: () async {
                    final err = await store.runMonthlyDepreciation(fa.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(err ?? 'تم ترحيل قسط الإهلاك الشهري بقيد مزدوج متوازن.')),
                      );
                    }
                  },
                  child: const Text('إهلاك شهري'),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildBudgetsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        FilledButton.icon(
          onPressed: () => _showAddBudgetDialog(context),
          icon: const Icon(Icons.pie_chart_outline),
          label: const Text('إضافة بند موازنة تقديرية'),
        ),
        const SizedBox(height: 12),
        ...store.budgets.map((b) {
          final acc = store.accounts.where((a) => a.id == b.accountId).toList();
          final actual = acc.isNotEmpty ? acc.first.balance.abs() : 0.0;
          final pct = b.plannedAmount > 0 ? (actual / b.plannedAmount).clamp(0.0, 1.5) : 0.0;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${b.accountName} (${b.periodLabel})', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  LinearProgressIndicator(value: pct.clamp(0.0, 1.0)),
                  const SizedBox(height: 6),
                  Text('الفعلي: ${actual.toStringAsFixed(2)} / المخطط: ${b.plannedAmount.toStringAsFixed(2)} ${store.bookCurrency}'),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _toggleFiscalLock(BuildContext context) async {
    if (store.fiscalLockDate != null) {
      await store.setFiscalLockDate(null);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم فتح الفترة المالية.')));
      }
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      await store.setFiscalLockDate(picked);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إقفال الفترة المالية حتى ${picked.toIso8601String().substring(0, 10)}')),
        );
      }
    }
  }

  void _showAddAccountDialog(BuildContext context) {
    final codeCtrl = TextEditingController(text: '12${store.accounts.length + 10}');
    final nameCtrl = TextEditingController();
    final enCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '0');
    AccountType type = AccountType.customer;
    String wh = store.warehouses.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('إضافة حساب / طرف جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'رقم الحساب')),
                const SizedBox(height: 8),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'الاسم بالعربية')),
                const SizedBox(height: 8),
                TextField(controller: enCtrl, decoration: const InputDecoration(labelText: 'English Name (اختياري)')),
                const SizedBox(height: 8),
                DropdownButtonFormField<AccountType>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'تصنيف الحساب'),
                  items: AccountType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.name))).toList(),
                  onChanged: (v) => setSt(() => type = v ?? AccountType.customer),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: wh,
                  decoration: const InputDecoration(labelText: 'المخزن الافتراضي المرتبط'),
                  items: store.warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                  onChanged: (v) => setSt(() => wh = v ?? store.warehouses.first),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: limitCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'سقف المديونية (0 = بدون سقف)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                await store.addAccount(MizanAccount(
                  id: MizanUuidV7.next(),
                  code: codeCtrl.text.trim(),
                  name: nameCtrl.text.trim(),
                  nameI18n: enCtrl.text.trim().isNotEmpty ? {'en': enCtrl.text.trim()} : {},
                  type: type,
                  currency: store.bookCurrency,
                  creditLimit: double.tryParse(limitCtrl.text) ?? 0,
                  defaultWarehouse: wh,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(store.t('save')),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAssetDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final costCtrl = TextEditingController(text: '1000');
    final monthsCtrl = TextEditingController(text: '36');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل أصل ثابت'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الأصل (مثال: سيارة توزيع)')),
            const SizedBox(height: 8),
            TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'تكلفة الشراء')),
            const SizedBox(height: 8),
            TextField(controller: monthsCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'العمر الإنتاجي (بالأشهر)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              await store.addFixedAsset(FixedAsset(
                id: MizanUuidV7.next(),
                name: nameCtrl.text.trim(),
                accountId: 'acc-fa',
                acquisitionCost: double.tryParse(costCtrl.text) ?? 0,
                usefulLifeMonths: int.tryParse(monthsCtrl.text) ?? 36,
                acquisitionDate: DateTime.now(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(store.t('save')),
          ),
        ],
      ),
    );
  }

  void _showAddBudgetDialog(BuildContext context) {
    final amtCtrl = TextEditingController(text: '5000');
    final periodCtrl = TextEditingController(text: '2026-Q4');
    String accId = store.accounts.isNotEmpty ? store.accounts.first.id : 'acc-exp';
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('إضافة موازنة تقديرية'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: accId,
                items: store.accounts.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name))).toList(),
                onChanged: (v) => setSt(() => accId = v ?? accId),
              ),
              const SizedBox(height: 8),
              TextField(controller: periodCtrl, decoration: const InputDecoration(labelText: 'الفترة')),
              const SizedBox(height: 8),
              TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المخطط')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
            FilledButton(
              onPressed: () async {
                final acc = store.accounts.firstWhere((a) => a.id == accId);
                await store.addBudget(BudgetLine(
                  id: MizanUuidV7.next(),
                  accountId: acc.id,
                  accountName: acc.name,
                  periodLabel: periodCtrl.text.trim(),
                  plannedAmount: double.tryParse(amtCtrl.text) ?? 0,
                ));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(store.t('save')),
            ),
          ],
        ),
      ),
    );
  }
}
