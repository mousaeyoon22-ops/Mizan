import 'package:flutter/material.dart';
import '../l10n/mizan_l10n.dart';
import '../models/mizan_models.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';

class MoreScreen extends StatelessWidget {
  final MizanStore store;
  const MoreScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(store.t('nav_more'))),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.storage_rounded, color: MizanColors.success),
              title: Text(store.t('sqlite_active'), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('الجداول العلائقية الفعلية: ${store.activeSqliteTables} · الإصدار v3.3.0'),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.t('language'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: MizanL10n.supported.map((lang) {
                      return ChoiceChip(
                        label: Text(lang.nativeName),
                        selected: lang.code == store.languageCode,
                        onSelected: (_) => store.setLanguage(lang.code),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: SwitchListTile(
              title: Text(store.t('dark_mode')),
              value: store.isDarkMode,
              onChanged: (_) => store.toggleDarkMode(),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('أوضاع الواجهة المتكيفة (5 Modes)', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: WorkspaceMode.values.map((m) {
                      return ChoiceChip(
                        label: Text(m.name),
                        selected: store.mode == m,
                        onSelected: (_) => store.setMode(m),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.add_location_alt_outlined),
                  title: const Text('إضافة فرع جديد'),
                  subtitle: Text('الفروع الحالية: ${store.branches.join("، ")}'),
                  onTap: () => _promptAddText(context, 'إضافة فرع جديد', store.addBranch),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.warehouse_outlined),
                  title: const Text('إضافة مخزن جديد'),
                  subtitle: Text('المخازن الحالية: ${store.warehouses.join("، ")}'),
                  onTap: () => _promptAddText(context, 'إضافة مخزن جديد', store.addWarehouse),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: MizanColors.danger),
            onPressed: () => _openZeroStartDialog(context),
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(store.t('zero_start')),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => store.logout(),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل الخروج'),
          ),
        ],
      ),
    );
  }

  void _promptAddText(BuildContext context, String title, Future<void> Function(String) onSave) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'الاسم')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
          FilledButton(
            onPressed: () async {
              await onSave(ctrl.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(store.t('save')),
          ),
        ],
      ),
    );
  }

  void _openZeroStartDialog(BuildContext context) {
    final entityCtrl = TextEditingController(text: store.entityName);
    final branchCtrl = TextEditingController(text: store.currentBranch);
    String curr = store.bookCurrency;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text(store.t('zero_start')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('سيتم تصفير جميع القيود والمديونيات والأصناف التجريبية للبدء من 0.00 نظيف تماماً مع إبقاء الجداول العلائقية الـ 18 جاهزة.'),
              const SizedBox(height: 10),
              TextField(controller: entityCtrl, decoration: InputDecoration(labelText: store.t('entity'))),
              const SizedBox(height: 8),
              TextField(controller: branchCtrl, decoration: InputDecoration(labelText: store.t('branch'))),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: curr,
                decoration: InputDecoration(labelText: store.t('currency')),
                items: ['USD', 'SAR', 'YER', 'AED', 'EUR'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setSt(() => curr = v ?? 'USD'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: MizanColors.danger),
              onPressed: () async {
                await store.startFreshEntity(
                  newEntityName: entityCtrl.text,
                  newBranchName: branchCtrl.text,
                  newBookCurrency: curr,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تصفير المنشأة بالكامل إلى 0.00 بنجاح.')),
                  );
                }
              },
              child: const Text('تأكيد التصفير 0.00'),
            ),
          ],
        ),
      ),
    );
  }
}
