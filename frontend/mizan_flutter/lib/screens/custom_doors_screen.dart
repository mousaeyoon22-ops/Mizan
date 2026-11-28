import 'package:flutter/material.dart';
import '../db/mizan_database.dart';
import '../models/mizan_models.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';

class CustomDoorsScreen extends StatelessWidget {
  final MizanStore store;
  const CustomDoorsScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(store.t('custom_doors')),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'الأبواب والحقول المخصصة'),
              Tab(text: 'حزم الدول والقطاعات'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildCustomDoorsTab(context),
            _buildCountryPacksTab(context),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openAddDoorDialog(context),
          icon: const Icon(Icons.add),
          label: const Text('باب مخصّص جديد'),
        ),
      ),
    );
  }

  Widget _buildCustomDoorsTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        if (store.customDoors.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('أنشئ أبواباً وحقولاً مخصصة لمنشأتك (مثل: عهدة سيارات التوزيع، مقاسات الألمنيوم، أو عيارات الذهب) واربطها بمسار اعتماد وقواعد ترحيل محاسبية.'),
            ),
          ),
        ...store.customDoors.map((d) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(d.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                  'الدور: ${d.targetRole} · الحقول: ${d.fields.map((f) => f['name']).join("، ")}',
                ),
                trailing: Wrap(
                  spacing: 6,
                  children: [
                    if (d.requiresApproval) const MizanBadge(text: 'اعتماد', color: MizanColors.accent),
                    if (d.postsToLedger) const MizanBadge(text: 'يرحّل للدفتر', color: MizanColors.primary),
                  ],
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildCountryPacksTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: CountrySectorPack.builtIn.map((pack) {
        final active = store.countryPackCode == pack.code;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(store.languageCode == 'ar' ? pack.nameAr : pack.nameEn, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${pack.defaultCurrency} · VAT ${pack.defaultVatPercent}% · ${pack.complianceScope}'),
            trailing: active
                ? const MizanBadge(text: 'مفعّلة', color: MizanColors.success)
                : OutlinedButton(
                    onPressed: () async {
                      await store.applyCountryPack(pack);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('تم تطبيق حزمة ${pack.code} وحفظ تاريخ سريانها في effective_settings.')),
                        );
                      }
                    },
                    child: const Text('تفعيل'),
                  ),
          ),
        );
      }).toList(),
    );
  }

  void _openAddDoorDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final fieldsCtrl = TextEditingController(text: 'رقم اللوحة, عدد العبوات الفارغة, اسم المندوب');
    bool reqApproval = true;
    bool posts = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('تصميم باب عمل وحقول مخصصة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'اسم الباب المخصّص')),
                const SizedBox(height: 8),
                TextField(controller: fieldsCtrl, decoration: const InputDecoration(labelText: 'أسماء الحقول (مفصولة بفاصلة)')),
                SwitchListTile(
                  value: reqApproval,
                  title: const Text('يتطلب مسار اعتماد قبل الترحيل'),
                  onChanged: (v) => setSt(() => reqApproval = v),
                ),
                SwitchListTile(
                  value: posts,
                  title: const Text('له أثر مالي يرحّل للدفتر'),
                  onChanged: (v) => setSt(() => posts = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
            FilledButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                final fields = fieldsCtrl.text
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .map((s) => {'name': s, 'type': 'text'})
                    .toList();
                await store.addCustomDoor(CustomDoorSchema(
                  id: MizanUuidV7.next(),
                  title: titleCtrl.text.trim(),
                  requiresApproval: reqApproval,
                  postsToLedger: posts,
                  fields: fields,
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
