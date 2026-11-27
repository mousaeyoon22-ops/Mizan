import 'package:flutter/material.dart';
import '../../core/workspace/workspace_mode_controller.dart';

/// Live Adaptive Workspace Screen that visibly transforms BOTH its layout structure
/// and displayed data granularity according to the selected WorkspaceExperienceMode.
class AdaptiveWorkspaceScreen extends StatelessWidget {
  final WorkspaceModeController controller;
  final bool isArabic;

  const AdaptiveWorkspaceScreen({
    super.key,
    required this.controller,
    this.isArabic = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final p = controller.currentProfile;
        return Scaffold(
          appBar: AppBar(
            title: Text('${isArabic ? 'شاشة العمل' : 'Workspace'} — ${isArabic ? p.titleAr : p.titleEn}'),
            actions: [
              PopupMenuButton<WorkspaceExperienceMode>(
                icon: const Icon(Icons.dashboard_customize_outlined),
                tooltip: isArabic ? 'تبديل وضع العرض' : 'Switch Display Mode',
                onSelected: (m) {
                  final err = controller.switchMode(m);
                  if (err != null) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                  }
                },
                itemBuilder: (_) => controller.allowedModesForRole
                    .map((m) => PopupMenuItem(
                          value: m,
                          child: Text(isArabic ? WorkspaceModeController.profiles[m]!.titleAr : WorkspaceModeController.profiles[m]!.titleEn),
                        ))
                    .toList(),
              ),
            ],
          ),
          body: _buildModeBody(context, p),
        );
      },
    );
  }

  Widget _buildModeBody(BuildContext context, WorkspaceModeProfile p) {
    switch (p.mode) {
      case WorkspaceExperienceMode.easy:
        return ListView(
          padding: EdgeInsets.all(p.cardPadding),
          children: [
            _metricCard(controller.term('cash', isArabic: isArabic), '1,250.00 USD', Icons.account_balance_wallet, Colors.teal),
            const SizedBox(height: 12),
            _metricCard(controller.term('ar', isArabic: isArabic), '600.00 USD', Icons.arrow_downward, Colors.green),
            const SizedBox(height: 12),
            _metricCard(controller.term('ap', isArabic: isArabic), '300.00 USD', Icons.arrow_upward, Colors.orange),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
              icon: const Icon(Icons.add_shopping_cart),
              label: Text(isArabic ? 'تسجيل بيع سريع' : 'Quick Sale', style: const TextStyle(fontSize: 18)),
              onPressed: () {},
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(60)),
              icon: const Icon(Icons.payments_outlined),
              label: Text(isArabic ? 'قبض أو صرف مبلغ' : 'Receive / Pay Cash', style: const TextStyle(fontSize: 18)),
              onPressed: () {},
            ),
          ],
        );

      case WorkspaceExperienceMode.professional:
        return SingleChildScrollView(
          padding: EdgeInsets.all(p.cardPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Card(
                child: ListTile(
                  dense: true,
                  leading: Icon(Icons.verified, color: Colors.teal),
                  title: Text('Trial Balance Variance: 0.0000 USD • IFRS 15 + IAS 2 (FIFO) + IAS 21 Active'),
                  subtitle: Text('Ledger Immutability: ON • Row-Level Security: ON'),
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columnSpacing: 16,
                  columns: const [
                    DataColumn(label: Text('COA')),
                    DataColumn(label: Text('الحساب / Account')),
                    DataColumn(label: Text('Tx Dr')),
                    DataColumn(label: Text('Tx Cr')),
                    DataColumn(label: Text('FX Rate')),
                    DataColumn(label: Text('Base Dr')),
                    DataColumn(label: Text('Base Cr')),
                    DataColumn(label: Text('SHA-256')),
                  ],
                  rows: const [
                    DataRow(cells: [
                      DataCell(Text('1120')),
                      DataCell(Text('AR — عميل الأمل')),
                      DataCell(Text('600.0000 USD')),
                      DataCell(Text('0.0000')),
                      DataCell(Text('1.000000')),
                      DataCell(Text('600.0000')),
                      DataCell(Text('0.0000')),
                      DataCell(Text('a70bc3b3...')),
                    ]),
                    DataRow(cells: [
                      DataCell(Text('4110')),
                      DataCell(Text('إيراد مبيعات (IFRS 15)')),
                      DataCell(Text('0.0000')),
                      DataCell(Text('600.0000 USD')),
                      DataCell(Text('1.000000')),
                      DataCell(Text('0.0000')),
                      DataCell(Text('600.0000')),
                      DataCell(Text('a70bc3b3...')),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        );

      case WorkspaceExperienceMode.executive:
        return GridView.count(
          padding: EdgeInsets.all(p.cardPadding),
          crossAxisCount: MediaQuery.of(context).size.width >= 900 ? 3 : 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _kpiTile(isArabic ? 'صافي الإيراد الموحّد' : 'Consolidated Revenue', '14,820 USD', '+12.4%'),
            _kpiTile(isArabic ? 'فارق ورديات الكاشيرات' : 'Shift Cash Variance', '0.00 USD', '100% Exact'),
            _kpiTile(isArabic ? 'الذمم المتأخرة (+30 يوم)' : 'Overdue AR (>30d)', '420 USD', '2 Accounts'),
            _kpiTile(isArabic ? 'مؤشر الموثوقية' : 'Trust Score', '99.4 / 100', 'Verified'),
          ],
        );

      case WorkspaceExperienceMode.expressField:
        return ListView(
          padding: EdgeInsets.all(p.cardPadding),
          children: [
            Card(
              color: Colors.teal.shade50,
              child: const ListTile(
                leading: Icon(Icons.offline_bolt),
                title: Text('وضع الأوفلاين الميداني جاهز — طابور المزامنة: 0'),
              ),
            ),
            const SizedBox(height: 12),
            _metricCard(isArabic ? 'عهدة المركبة الحالية' : 'Vehicle Custody', '80 عبوة 20 لتر', Icons.local_shipping, Colors.teal),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(isArabic ? 'تسليم فوري وتحصيل نقدي' : 'Instant Delivery & Cash Collect', style: const TextStyle(fontSize: 18)),
              onPressed: () {},
            ),
          ],
        );

      case WorkspaceExperienceMode.standard:
        return ListView(
          padding: EdgeInsets.all(p.cardPadding),
          children: [
            Row(
              children: [
                Expanded(child: _metricCard(controller.term('cash', isArabic: isArabic), '1,250.00 USD', Icons.wallet, Colors.teal)),
                const SizedBox(width: 10),
                Expanded(child: _metricCard(controller.term('ar', isArabic: isArabic), '600.00 USD', Icons.receipt_long, Colors.blue)),
              ],
            ),
            const SizedBox(height: 12),
            const Card(
              child: ListTile(
                leading: Icon(Icons.swap_horiz, color: Colors.teal),
                title: Text('الأبواب التجارية: 2 بانتظار المراجعة • فارق المطابقة 0.0000'),
                subtitle: Text('تقرير A4 اليومي: إخفاء الصفوف الفارغة مفعّل تلقائياً'),
              ),
            ),
          ],
        );
    }
  }

  Widget _metricCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color, size: 30),
        title: Text(title),
        subtitle: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _kpiTile(String title, String val, String badge) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.black54)),
            Text(val, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Chip(label: Text(badge)),
          ],
        ),
      ),
    );
  }
}
