import 'package:flutter/material.dart';
import '../models/mizan_models.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';
import 'invoice_screen.dart';
import 'vouchers_screen.dart';
import 'qr_cart_screen.dart';
import 'gates_screen.dart';
import 'fx_screen.dart';
import 'reports_screen.dart';

class WorkspaceScreen extends StatelessWidget {
  final MizanStore store;
  final ValueChanged<int> onNavigateTab;

  const WorkspaceScreen({super.key, required this.store, required this.onNavigateTab});

  String _modeTitle(WorkspaceMode m) => switch (m) {
        WorkspaceMode.easy => 'الوضع السهل',
        WorkspaceMode.standard => 'الوضع العادي',
        WorkspaceMode.professional => 'الوضع الاحترافي',
        WorkspaceMode.executive => 'الوضع التنفيذي',
        WorkspaceMode.expressField => 'وضع الميدان السريع',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ميزان — ${_modeTitle(store.mode)}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text(
              store.isOfflineMode ? 'وضع الأوفلاين الميداني • محفوظ محلياً' : 'متصل بالخادم',
              style: const TextStyle(fontSize: 11.5, color: MizanColors.muted, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'الوضع الليلي',
            onPressed: store.toggleDarkMode,
            icon: Icon(store.isDarkMode ? Icons.light_mode_rounded : Icons.dark_mode_outlined),
          ),
          PopupMenuButton<WorkspaceMode>(
            tooltip: 'تبديل الوضع',
            icon: const Icon(Icons.grid_view_rounded),
            onSelected: store.setMode,
            itemBuilder: (_) => WorkspaceMode.values
                .map((m) => PopupMenuItem(
                      value: m,
                      child: Row(
                        children: [
                          Icon(
                            store.mode == m ? Icons.radio_button_checked : Icons.radio_button_off,
                            size: 18,
                            color: MizanColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(_modeTitle(m)),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          _buildHeroSummary(context),
          const SizedBox(height: 16),
          const Text('الوصول السريع للعمليات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.05,
            children: [
              QuickActionTile(
                title: 'فاتورة جديدة',
                icon: Icons.receipt_long_rounded,
                color: MizanColors.primary,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceBuilderScreen(store: store))),
              ),
              QuickActionTile(
                title: 'قبض / صرف',
                icon: Icons.payments_rounded,
                color: MizanColors.success,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VouchersScreen(store: store))),
              ),
              QuickActionTile(
                title: 'الأصناف والجرد',
                icon: Icons.inventory_2_rounded,
                color: MizanColors.info,
                onTap: () => onNavigateTab(2),
              ),
              QuickActionTile(
                title: 'التقارير IFRS',
                icon: Icons.analytics_rounded,
                color: MizanColors.accent,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GlobalReportsScreen(store: store))),
              ),
              QuickActionTile(
                title: 'الأبواب التجارية',
                icon: Icons.swap_horiz_rounded,
                color: const Color(0xFF0D9488),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GatesScreen(store: store))),
              ),
              QuickActionTile(
                title: 'المصارفة IAS21',
                icon: Icons.currency_exchange_rounded,
                color: const Color(0xFF7C3AED),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FxScreen(store: store))),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _buildModeSpecificPanel(context),
          const SizedBox(height: 18),
          Row(
            children: [
              const Text('آخر الحركات والقيود اليومية', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VouchersScreen(store: store))),
                child: const Text('عرض الكل'),
              ),
            ],
          ),
          ...store.ledger.take(4).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MizanCard(
                  padding: const EdgeInsets.all(13),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: MizanColors.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.book_outlined, color: MizanColors.primary, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.description, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 2),
                            Text('${e.refNo} • ${fmtDate(e.date)}', style: const TextStyle(fontSize: 11.5, color: MizanColors.muted)),
                          ],
                        ),
                      ),
                      Text(fmtMoney(e.amount, e.currency), style: const TextStyle(fontWeight: FontWeight.w800, color: MizanColors.primary)),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildHeroSummary(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [MizanColors.primaryDark, MizanColors.primary],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('إجمالي السيولة النقدية (USD)', style: TextStyle(color: Color(0xFFD1FAE5), fontSize: 13)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text('طابور المزامنة: ${store.syncQueueCount}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            fmtMoney(store.totalCashUsd, 'USD'),
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _heroSub('لك عند العملاء', fmtMoney(store.totalReceivables))),
              Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.25)),
              const SizedBox(width: 12),
              Expanded(child: _heroSub('عليك للموردين', fmtMoney(store.totalPayables))),
              Container(width: 1, height: 28, color: Colors.white.withValues(alpha: 0.25)),
              const SizedBox(width: 12),
              Expanded(child: _heroSub('قيمة المخزون', fmtMoney(store.totalInventoryValue))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroSub(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFFC6F6D5), fontSize: 11)),
        const SizedBox(height: 2),
        Text(val, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildModeSpecificPanel(BuildContext context) {
    if (store.mode == WorkspaceMode.professional) {
      return MizanCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.verified_rounded, color: MizanColors.primary, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الوضع الاحترافي • ميزان المراجعة متوازن (0.0000) • IFRS 15 + IAS 21',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            ...store.accounts.take(5).map((a) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(width: 48, child: Text(a.code, style: const TextStyle(fontWeight: FontWeight.w700, color: MizanColors.muted))),
                      Expanded(child: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                      Text(
                        fmtMoney(a.balance, a.currency),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: a.balance >= 0 ? MizanColors.success : MizanColors.danger,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      );
    }

    if (store.mode == WorkspaceMode.executive) {
      return GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.35,
        children: [
          KpiTile(label: 'إجمالي المبيعات', value: fmtMoney(store.totalSalesRevenue), badge: 'حي', icon: Icons.trending_up_rounded, color: MizanColors.success),
          KpiTile(label: 'صافي الربح التقديري', value: fmtMoney(store.totalEstimatedProfit), badge: 'P&L', icon: Icons.pie_chart_rounded, color: MizanColors.primary),
          KpiTile(label: 'أصناف قرب النفاد', value: '${store.lowStockCount} صنف', badge: 'تنبيه', icon: Icons.warning_amber_rounded, color: MizanColors.accent, onTap: () => onNavigateTab(2)),
          KpiTile(label: 'أبواب بانتظار الموافقة', value: '${store.pendingGatesCount} باب', badge: 'قرار 2', icon: Icons.swap_horiz_rounded, color: MizanColors.info, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GatesScreen(store: store)))),
        ],
      );
    }

    if (store.mode == WorkspaceMode.expressField) {
      final vehicleItems = store.items.where((i) => i.warehouse == 'عهدة مركبة التوزيع').fold(0.0, (s, i) => s + i.stockQty);
      return MizanCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.local_shipping_rounded, color: MizanColors.primary),
                const SizedBox(width: 10),
                Expanded(child: Text('عهدة مركبة التوزيع: ${vehicleItems.toStringAsFixed(0)} وحدة متاحة', style: const TextStyle(fontWeight: FontWeight.w800))),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => QrCartScreen(store: store))),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('تسليم فوري وتحصيل نقدي عبر السلة الحية'),
            ),
          ],
        ),
      );
    }

    // Easy & Standard mode action strip
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceBuilderScreen(store: store))),
            icon: const Icon(Icons.add_shopping_cart_rounded),
            label: const Text('تسجيل بيع سريع'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => VouchersScreen(store: store))),
            icon: const Icon(Icons.payments_outlined),
            label: const Text('قبض أو صرف'),
          ),
        ),
      ],
    );
  }
}
