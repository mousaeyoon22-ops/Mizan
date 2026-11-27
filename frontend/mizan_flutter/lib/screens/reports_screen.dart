import 'package:flutter/material.dart';
import '../engine/ifrs_engine.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';

class GlobalReportsScreen extends StatefulWidget {
  final MizanStore store;
  const GlobalReportsScreen({super.key, required this.store});

  @override
  State<GlobalReportsScreen> createState() => _GlobalReportsScreenState();
}

class _GlobalReportsScreenState extends State<GlobalReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snap = IfrsEngine.compute(widget.store);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقارير المالية العالمية (IFRS / IAS)'),
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          tabs: const [
            Tab(text: 'قائمة الدخل (IAS 1)'),
            Tab(text: 'الميزانية العمومية'),
            Tab(text: 'ميزان المراجعة'),
            Tab(text: 'التدقيق و SHA-256'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // 1. Income Statement
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _badgeBanner(
                snap.isFullyBalanced
                    ? 'مطابق لمعايير IFRS 15 (فصل الضريبة) + IAS 2 (تكلفة المبيعات)'
                    : 'يوجد فارق يتطلب المراجعة',
                snap.isFullyBalanced ? MizanColors.success : MizanColors.danger,
              ),
              const SizedBox(height: 12),
              MizanCard(
                child: Column(
                  children: [
                    _row('إجمالي المبيعات (بدون ضريبة IFRS 15)', snap.grossSales),
                    _row('(-) مردودات المبيعات', -snap.salesReturns),
                    const Divider(),
                    _row('صافي الإيرادات (Net Revenue)', snap.netRevenue, bold: true),
                    _row('(-) تكلفة البضاعة المباعة (COGS / IAS 2)', -snap.cogs),
                    const Divider(),
                    _row('مجمل الربح (Gross Profit)', snap.grossProfit, bold: true, color: MizanColors.primary),
                    _row('(-) المصروفات التشغيلية', -snap.operatingExpenses),
                    const Divider(),
                    _row(
                      'صافي الربح / الخسارة (Net Profit)',
                      snap.netProfit,
                      bold: true,
                      color: snap.netProfit >= 0 ? MizanColors.success : MizanColors.danger,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              MizanCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ملخص التدفقات النقدية (IAS 7)', style: TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    _row('التدفقات النقدية الداخلة', snap.operatingCashIn, color: MizanColors.success),
                    _row('التدفقات النقدية الخارجة', -snap.operatingCashOut, color: MizanColors.danger),
                    const Divider(),
                    _row('صافي التدفق النقدي التشغيلي', snap.netOperatingCashFlow, bold: true),
                  ],
                ),
              ),
            ],
          ),

          // 2. Balance Sheet
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _badgeBanner(
                'معادلة الميزانية: الأصول = الالتزامات + حقوق الملكية (فارق ${snap.balanceSheetVariance.toStringAsFixed(4)})',
                MizanColors.primary,
              ),
              const SizedBox(height: 12),
              MizanCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الأصول (Assets)', style: TextStyle(fontWeight: FontWeight.w800, color: MizanColors.primary)),
                    const SizedBox(height: 6),
                    _row('النقدية والصناديق (USD)', snap.cashAssets),
                    _row('الذمم المدينة (العملاء)', snap.receivablesAssets),
                    _row('المخزون بالتكلفة (IAS 2)', snap.inventoryAssets),
                    const Divider(),
                    _row('إجمالي الأصول', snap.totalAssets, bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              MizanCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الالتزامات وحقوق الملكية (Liabilities & Equity)', style: TextStyle(fontWeight: FontWeight.w800, color: MizanColors.info)),
                    const SizedBox(height: 6),
                    _row('الذمم الدائنة (الموردون)', snap.payablesLiabilities),
                    _row('ضريبة القيمة المضافة المستحقة (VAT)', snap.vatPayable),
                    _row('إجمالي الالتزامات', snap.totalLiabilities, bold: true),
                    const Divider(),
                    _row('حقوق الملكية والأرباح المحتجزة', snap.ownerEquityAndRetained, bold: true, color: MizanColors.success),
                    _row('إجمالي الالتزامات وحقوق الملكية', snap.totalLiabilities + snap.ownerEquityAndRetained, bold: true),
                  ],
                ),
              ),
            ],
          ),

          // 3. Trial Balance
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _badgeBanner(
                'إجمالي المدين: ${snap.totalDebits.toStringAsFixed(4)}  |  إجمالي الدائن: ${snap.totalCredits.toStringAsFixed(4)}  |  الفارق: ${snap.trialBalanceVariance.toStringAsFixed(4)}',
                snap.trialBalanceVariance.abs() < 0.0001 ? MizanColors.success : MizanColors.danger,
              ),
              const SizedBox(height: 12),
              MizanCard(
                child: Column(
                  children: [
                    Row(
                      children: const [
                        Expanded(flex: 5, child: Text('الحساب', style: TextStyle(fontWeight: FontWeight.w800))),
                        Expanded(flex: 3, child: Text('مدين (Dr)', textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w800))),
                        Expanded(flex: 3, child: Text('دائن (Cr)', textAlign: TextAlign.end, style: TextStyle(fontWeight: FontWeight.w800))),
                      ],
                    ),
                    const Divider(height: 18),
                    ...snap.trialBalance.map((r) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(flex: 5, child: Text(r.accountName, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                              Expanded(flex: 3, child: Text(r.debit.toStringAsFixed(2), textAlign: TextAlign.end, style: const TextStyle(fontSize: 12.5))),
                              Expanded(flex: 3, child: Text(r.credit.toStringAsFixed(2), textAlign: TextAlign.end, style: const TextStyle(fontSize: 12.5))),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ],
          ),

          // 4. Audit Guardian & SHA-256 Hash Chain
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              MizanCard(
                color: MizanColors.primarySoft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('بصمة سلسلة التوثيق غير القابلة للتلاعب (SHA-256 Head)', style: TextStyle(fontWeight: FontWeight.w800, color: MizanColors.primaryDark)),
                    const SizedBox(height: 6),
                    SelectableText(
                      snap.chainHeadHash,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, color: MizanColors.ink),
                    ),
                    const SizedBox(height: 6),
                    Text('عدد القيود الموثّقة في السلسلة: ${widget.store.ledger.length} قيد (حذف القيود مقفل — التصحيح بالقيود العكسية فقط)', style: const TextStyle(fontSize: 12, color: MizanColors.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text('المراقب المحاسبي الذكي (COSO Controls)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              ...snap.auditAlerts.map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: MizanCard(
                      padding: const EdgeInsets.all(13),
                      child: Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: MizanColors.primary, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(a, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
                        ],
                      ),
                    ),
                  )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badgeBanner(String text, Color c) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_rounded, color: c, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: c, fontSize: 12.5))),
        ],
      ),
    );
  }

  Widget _row(String label, double val, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500))),
          Text(
            fmtMoney(val, 'USD'),
            style: TextStyle(fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}
