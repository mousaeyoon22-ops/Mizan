import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';
import 'gates_screen.dart';
import 'fx_screen.dart';
import 'qr_cart_screen.dart';
import 'reports_screen.dart';

class MoreScreen extends StatelessWidget {
  final MizanStore store;
  const MoreScreen({super.key, required this.store});

  void _showFreshEntityDialog(BuildContext context) {
    final entCtrl = TextEditingController(text: store.entityName);
    final brCtrl = TextEditingController(text: 'الفرع الرئيسي');
    String curr = store.bookCurrency;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('بدء منشأة جديدة (تصفير كامل 0.00)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('سيتم مسح جميع البيانات التجريبية والمديونيات لتبدأ برصيد 0.00 نظيف تماماً.', style: TextStyle(fontSize: 12.5, color: MizanColors.muted)),
              const SizedBox(height: 12),
              TextField(controller: entCtrl, decoration: const InputDecoration(labelText: 'اسم المنشأة / المتجر')),
              const SizedBox(height: 10),
              TextField(controller: brCtrl, decoration: const InputDecoration(labelText: 'اسم الفرع الرئيسي')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: curr,
                decoration: const InputDecoration(labelText: 'عملة الدفاتر الأساسية'),
                items: const ['USD', 'SAR', 'YER'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setS(() => curr = v ?? 'USD'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () async {
                await store.startFreshEntity(newEntityName: entCtrl.text, mainBranch: brCtrl.text, currency: curr);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تصفير النظام بنجاح (0.00) وتهيئة المنشأة الجديدة')));
                }
              },
              child: const Text('تأكيد التصفير 0.00'),
            ),
          ],
        ),
      ),
    );
  }

  void _showBackupDialog(BuildContext context) {
    final jsonStr = store.exportBackupJson();
    final importCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('النسخ الاحتياطي والاستعادة (JSON)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: jsonStr));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم نسخ النسخة الاحتياطية الكاملة إلى الحافظة')));
                },
                icon: const Icon(Icons.copy_rounded),
                label: const Text('نسخ النسخة الاحتياطية الآن'),
              ),
              const Divider(height: 22),
              TextField(
                controller: importCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'الصق نص النسخة الاحتياطية هنا للاستعادة'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
          FilledButton(
            onPressed: () async {
              final ok = await store.importBackupJson(importCtrl.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ok ? 'تمت استعادة البيانات بنجاح' : 'تنسيق النسخة الاحتياطية غير صالح')));
              }
            },
            child: const Text('استعادة'),
          ),
        ],
      ),
    );
  }

  void _showCleanA4Report(BuildContext context) {
    final activeAccounts = store.hideEmptyA4Rows
        ? store.accounts.where((a) => a.balance != 0).toList()
        : store.accounts;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('التقرير اليومي A4 (نظيف)'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('إخفاء الصفوف الفارغة: ${store.hideEmptyA4Rows ? "مفعّل" : "موقف"}', style: const TextStyle(fontSize: 12, color: MizanColors.muted)),
              const Divider(height: 16),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('إجمالي المبيعات:'), Text(fmtMoney(store.totalSalesRevenue), style: const TextStyle(fontWeight: FontWeight.w800))]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('إجمالي المصروفات:'), Text(fmtMoney(store.totalExpenses), style: const TextStyle(fontWeight: FontWeight.w800))]),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('صافي الربح التقديري:'), Text(fmtMoney(store.totalEstimatedProfit), style: const TextStyle(fontWeight: FontWeight.w900, color: MizanColors.success))]),
              const Divider(height: 16),
              const Text('الأرصدة النشطة:', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              ...activeAccounts.map((a) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Text(a.name)), Text(fmtMoney(a.balance, a.currency), style: const TextStyle(fontWeight: FontWeight.w700))]),
                  )),
            ],
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق'))],
      ),
    );
  }

  void _showModulesSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.78,
        builder: (_, sc) => AnimatedBuilder(
          animation: store,
          builder: (_, __) => ListView(
            controller: sc,
            padding: const EdgeInsets.all(16),
            children: [
              const Text('التفضيلات التشغيلية والوحدات', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...store.modules.entries.map((e) => SwitchListTile(
                    value: e.value,
                    onChanged: (v) => store.toggleModule(e.key, v),
                    title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  )),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات والتقارير والوحدات'),
        actions: [
          TextButton(onPressed: store.toggleLanguage, child: Text(store.isEnglish ? 'AR' : 'EN', style: const TextStyle(fontWeight: FontWeight.w800))),
          IconButton(onPressed: store.logout, icon: const Icon(Icons.logout_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MizanCard(
            child: Column(
              children: [
                SwitchListTile(
                  value: store.isDarkMode,
                  onChanged: (_) => store.toggleDarkMode(),
                  title: const Text('المظهر الليلي العصري (Dark Mode)', style: TextStyle(fontWeight: FontWeight.w700)),
                  secondary: const Icon(Icons.dark_mode_outlined),
                ),
                SwitchListTile(
                  value: store.hideEmptyA4Rows,
                  onChanged: store.setHideEmptyA4,
                  title: const Text('إخفاء الصفوف الفارغة في تقارير A4', style: TextStyle(fontWeight: FontWeight.w700)),
                  secondary: const Icon(Icons.print_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          MizanCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.assessment_outlined, color: MizanColors.primary),
                  title: const Text('التقارير المالية العالمية (IFRS / IAS / SHA-256)', style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GlobalReportsScreen(store: store))),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.qr_code_scanner_rounded, color: MizanColors.primary),
                  title: const Text('مسح QR والسلة الحية', style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QrCartScreen(store: store))),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.swap_horiz_rounded, color: MizanColors.primary),
                  title: const Text('الأبواب التجارية والقرارات الثلاثة', style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GatesScreen(store: store))),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.currency_exchange_rounded, color: MizanColors.primary),
                  title: const Text('سندات المصارفة (IAS 21)', style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FxScreen(store: store))),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.tune_rounded, color: MizanColors.primary),
                  title: const Text('التفضيلات التشغيلية والوحدات', style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showModulesSheet(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.backup_outlined, color: MizanColors.info),
                  title: const Text('النسخ الاحتياطي والاستعادة (JSON)', style: TextStyle(fontWeight: FontWeight.w700)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showBackupDialog(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.storage_rounded, color: MizanColors.success),
                  title: Text('محرك SQLite المحلي: ${store.isSqliteReady ? "نشط ومتصل" : "احتياطي"}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('المنشأة: ${store.entityName} • الفرع: ${store.currentBranch} • سجل التدقيق: ${store.sqliteAuditCount}', style: const TextStyle(fontSize: 12)),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cleaning_services_rounded, color: MizanColors.primary),
                  title: const Text('بدء منشأة جديدة (تصفير كامل 0.00)', style: TextStyle(fontWeight: FontWeight.w800, color: MizanColors.primary)),
                  subtitle: const Text('حذف المديونيات التجريبية والبدء من الصفر ببياناتك الحقيقية', style: TextStyle(fontSize: 12)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showFreshEntityDialog(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restart_alt_rounded, color: MizanColors.danger),
                  title: const Text('إعادة تحميل بيانات تجريبية للاختبار', style: TextStyle(fontWeight: FontWeight.w700, color: MizanColors.danger)),
                  onTap: () async {
                    await store.resetDemoData();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إعادة ضبط البيانات الافتراضية')));
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
