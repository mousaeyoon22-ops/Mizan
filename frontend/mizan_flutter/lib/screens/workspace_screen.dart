import 'package:flutter/material.dart';
import '../models/mizan_models.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';
import 'custom_doors_screen.dart';
import 'fx_screen.dart';

class WorkspaceScreen extends StatelessWidget {
  final MizanStore store;
  final ValueChanged<int> onNavigate;

  const WorkspaceScreen({
    super.key,
    required this.store,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final snap = store.auditSnapshot();
    final curr = store.bookCurrency;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(store.entityName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            Text(
              '${store.currentBranch} · $curr · ${store.countryPackCode}',
              style: const TextStyle(fontSize: 12, color: MizanColors.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: store.t('fx_center'),
            icon: const Icon(Icons.currency_exchange_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FxScreen(store: store))),
          ),
          IconButton(
            tooltip: store.t('custom_doors'),
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomDoorsScreen(store: store))),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: MizanColors.primary,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.t('trust_score'),
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${snap.trustScore.toStringAsFixed(1)} / 100',
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'SHA-256: ${snap.latestChainHash.substring(0, 14)}… · ${snap.verifiedEntryCount} قيد موثّق',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  MizanBadge(
                    text: snap.isBalanced ? store.t('balanced') : 'فرق توازن',
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.55,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              MizanKpiCard(
                title: store.t('cash_balance'),
                value: '${store.totalCashBalance.toStringAsFixed(2)} $curr',
                icon: Icons.account_balance_wallet_outlined,
                color: MizanColors.primary,
              ),
              MizanKpiCard(
                title: store.t('net_profit'),
                value: '${snap.netProfit.toStringAsFixed(2)} $curr',
                icon: Icons.trending_up_rounded,
                color: snap.netProfit >= 0 ? MizanColors.success : MizanColors.danger,
              ),
              MizanKpiCard(
                title: store.t('receivables'),
                value: '${store.totalReceivables.toStringAsFixed(2)} $curr',
                icon: Icons.arrow_downward_rounded,
                color: MizanColors.info,
              ),
              MizanKpiCard(
                title: store.t('payables'),
                value: '${store.totalPayables.toStringAsFixed(2)} $curr',
                icon: Icons.arrow_upward_rounded,
                color: MizanColors.accent,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('الوحدات السريعة والدورات القطاعية (5+1)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ActionChip(
                avatar: const Icon(Icons.receipt_long, size: 18),
                label: Text(store.t('nav_invoices')),
                onPressed: () => onNavigate(2),
              ),
              ActionChip(
                avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                label: Text(store.t('nav_inventory')),
                onPressed: () => onNavigate(4),
              ),
              ActionChip(
                avatar: const Icon(Icons.hub_outlined, size: 18),
                label: Text(store.t('nav_network')),
                onPressed: () => onNavigate(5),
              ),
              ActionChip(
                avatar: const Icon(Icons.currency_exchange, size: 18),
                label: Text(store.t('fx_center')),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FxScreen(store: store))),
              ),
              ActionChip(
                avatar: const Icon(Icons.tune, size: 18),
                label: Text(store.t('custom_doors')),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CustomDoorsScreen(store: store))),
              ),
              ActionChip(
                avatar: const Icon(Icons.analytics_outlined, size: 18),
                label: Text(store.t('nav_reports')),
                onPressed: () => onNavigate(6),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الدورات القطاعية المفعّلة للمنشأة', style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: SectorCycle.values.map((c) {
                      final active = store.activeCycles.contains(c);
                      return FilterChip(
                        label: Text(_cycleLabel(c)),
                        selected: active,
                        onSelected: (_) => store.toggleCycle(c),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _cycleLabel(SectorCycle c) {
    switch (c) {
      case SectorCycle.trade: return 'التجارة';
      case SectorCycle.services: return 'الخدمات';
      case SectorCycle.contracting: return 'المقاولات والمستخلصات';
      case SectorCycle.manufacturing: return 'التصنيع (BOM)';
      case SectorCycle.subscriptions: return 'الاشتراكات الدورية';
      case SectorCycle.waterDistribution: return 'توزيع المياه';
    }
  }
}
