import 'package:flutter/material.dart';
import '../outputs/mizan_outputs.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';

class ReportsScreen extends StatefulWidget {
  final MizanStore store;
  const ReportsScreen({super.key, required this.store});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTime _asOfDate = DateTime.now().add(const Duration(minutes: 5));
  String? _branchFilter;

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final snap = s.auditSnapshot(asOf: _asOfDate, branch: _branchFilter);
    final curr = s.bookCurrency;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.t('nav_reports')),
          actions: [
            IconButton(
              tooltip: 'إعادة إنتاج التقرير بتاريخ سابق',
              icon: const Icon(Icons.history_rounded),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2035),
                );
                if (picked != null) {
                  setState(() => _asOfDate = DateTime(picked.year, picked.month, picked.day, 23, 59, 59));
                }
              },
            ),
            IconButton(
              tooltip: s.t('export_pdf'),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () async {
                final bytes = await MizanOutputs.buildIfrsReportPdf(
                  snap: snap,
                  entityName: s.entityName,
                  bookCurrency: curr,
                );
                await MizanOutputs.sharePdfToWhatsApp(
                  bytes: bytes,
                  fileName: 'mizan_ifrs_report.pdf',
                  caption: '${s.entityName} — IFRS Audit Report',
                );
              },
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'ميزان المراجعة'),
              Tab(text: 'قائمة الدخل والميزانية'),
              Tab(text: 'سلسلة SHA-256'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'تاريخ التقرير: ${_asOfDate.toIso8601String().substring(0, 10)}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    MizanBadge(
                      text: snap.isBalanced ? s.t('balanced') : 'فرق ${snap.trialVariance.toStringAsFixed(2)}',
                      color: snap.isBalanced ? MizanColors.success : MizanColors.danger,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...snap.trialBalance.map((row) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(row.accountName, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('مدين: ${row.debit.toStringAsFixed(2)} · دائن: ${row.credit.toStringAsFixed(2)}'),
                        trailing: Text(
                          '${row.net.toStringAsFixed(2)} $curr',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    )),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(14),
              children: [
                MizanKpiCard(
                  title: 'إجمالي الإيرادات (IAS 1)',
                  value: '${snap.totalRevenue.toStringAsFixed(2)} $curr',
                  icon: Icons.trending_up,
                  color: MizanColors.success,
                ),
                const SizedBox(height: 8),
                MizanKpiCard(
                  title: 'إجمالي المصروفات والتكلفة',
                  value: '${snap.totalExpense.toStringAsFixed(2)} $curr',
                  icon: Icons.trending_down,
                  color: MizanColors.danger,
                ),
                const SizedBox(height: 8),
                MizanKpiCard(
                  title: s.t('net_profit'),
                  value: '${snap.netProfit.toStringAsFixed(2)} $curr',
                  icon: Icons.account_balance,
                  color: MizanColors.primary,
                ),
                const Divider(height: 24),
                MizanKpiCard(
                  title: 'إجمالي الأصول',
                  value: '${snap.totalAssets.toStringAsFixed(2)} $curr',
                  icon: Icons.pie_chart_outline,
                  color: MizanColors.info,
                ),
                const SizedBox(height: 8),
                MizanKpiCard(
                  title: 'الالتزامات + حقوق الملكية',
                  value: '${(snap.totalLiabilities + snap.totalEquity).toStringAsFixed(2)} $curr',
                  subtitle: 'الالتزامات: ${snap.totalLiabilities.toStringAsFixed(2)} · الملكية: ${snap.totalEquity.toStringAsFixed(2)}',
                  icon: Icons.balance,
                  color: MizanColors.accent,
                ),
              ],
            ),
            ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('رأس سلسلة التدقيق SHA-256', style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        SelectableText(snap.latestChainHash, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                ...s.auditEvents.map((e) => Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        title: Text('${e['action']} — ${e['ref_no']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${e['event_time']} · ${(e['sha256_hash'] as String).substring(0, 14)}…'),
                      ),
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
