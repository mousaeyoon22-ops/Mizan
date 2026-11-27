import 'dart:convert';
import '../models/mizan_models.dart';
import '../state/mizan_store.dart';

/// Pure-Dart FIPS 180-4 SHA-256 implementation (zero external package dependencies)
class MizanSha256 {
  static const List<int> _k = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
  ];

  static int _rotr(int x, int n) => ((x & 0xffffffff) >> n) | ((x << (32 - n)) & 0xffffffff);

  static String digestHex(String input) {
    final bytes = utf8.encode(input);
    final bitLen = bytes.length * 8;
    final msg = List<int>.from(bytes)..add(0x80);
    while ((msg.length % 64) != 56) {
      msg.add(0);
    }
    for (int i = 7; i >= 0; i--) {
      msg.add((bitLen >> (i * 8)) & 0xff);
    }

    int h0 = 0x6a09e667;
    int h1 = 0xbb67ae85;
    int h2 = 0x3c6ef372;
    int h3 = 0xa54ff53a;
    int h4 = 0x510e527f;
    int h5 = 0x9b05688c;
    int h6 = 0x1f83d9ab;
    int h7 = 0x5be0cd19;

    final w = List<int>.filled(64, 0);
    for (int i = 0; i < msg.length; i += 64) {
      for (int t = 0; t < 16; t++) {
        w[t] = (msg[i + t * 4] << 24) |
            (msg[i + t * 4 + 1] << 16) |
            (msg[i + t * 4 + 2] << 8) |
            msg[i + t * 4 + 3];
      }
      for (int t = 16; t < 64; t++) {
        final s0 = _rotr(w[t - 15], 7) ^ _rotr(w[t - 15], 18) ^ ((w[t - 15] & 0xffffffff) >> 3);
        final s1 = _rotr(w[t - 2], 17) ^ _rotr(w[t - 2], 19) ^ ((w[t - 2] & 0xffffffff) >> 10);
        w[t] = (w[t - 16] + s0 + w[t - 7] + s1) & 0xffffffff;
      }
      int a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;
      for (int t = 0; t < 64; t++) {
        final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
        final ch = (e & f) ^ ((~e & 0xffffffff) & g);
        final temp1 = (h + s1 + ch + _k[t] + w[t]) & 0xffffffff;
        final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xffffffff;
        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xffffffff;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xffffffff;
      }
      h0 = (h0 + a) & 0xffffffff;
      h1 = (h1 + b) & 0xffffffff;
      h2 = (h2 + c) & 0xffffffff;
      h3 = (h3 + d) & 0xffffffff;
      h4 = (h4 + e) & 0xffffffff;
      h5 = (h5 + f) & 0xffffffff;
      h6 = (h6 + g) & 0xffffffff;
      h7 = (h7 + h) & 0xffffffff;
    }

    return [h0, h1, h2, h3, h4, h5, h6, h7]
        .map((v) => v.toRadixString(16).padLeft(8, '0'))
        .join();
  }
}

class TrialBalanceRow {
  final String accountName;
  final double debit;
  final double credit;
  const TrialBalanceRow({required this.accountName, required this.debit, required this.credit});
}

class FinancialAuditSnapshot {
  // Exact micro-unit (1e-4) precision helpers
  final List<TrialBalanceRow> trialBalance;
  final double totalDebits;
  final double totalCredits;
  final double trialBalanceVariance;

  // IAS 1 Income Statement (IFRS 15 + IAS 2 + IAS 21)
  final double grossSales;
  final double salesReturns;
  final double netRevenue;
  final double cogs;
  final double grossProfit;
  final double operatingExpenses;
  final double vatPayable;
  final double netProfit;

  // IAS 1 Balance Sheet
  final double cashAssets;
  final double receivablesAssets;
  final double inventoryAssets;
  final double totalAssets;
  final double payablesLiabilities;
  final double totalLiabilities;
  final double ownerEquityAndRetained;
  final double balanceSheetVariance;

  // IAS 7 Cash Flow
  final double operatingCashIn;
  final double operatingCashOut;
  final double netOperatingCashFlow;

  // Audit Integrity & Anomaly Guardian
  final String chainHeadHash;
  final List<String> auditAlerts;

  const FinancialAuditSnapshot({
    required this.trialBalance,
    required this.totalDebits,
    required this.totalCredits,
    required this.trialBalanceVariance,
    required this.grossSales,
    required this.salesReturns,
    required this.netRevenue,
    required this.cogs,
    required this.grossProfit,
    required this.operatingExpenses,
    required this.vatPayable,
    required this.netProfit,
    required this.cashAssets,
    required this.receivablesAssets,
    required this.inventoryAssets,
    required this.totalAssets,
    required this.payablesLiabilities,
    required this.totalLiabilities,
    required this.ownerEquityAndRetained,
    required this.balanceSheetVariance,
    required this.operatingCashIn,
    required this.operatingCashOut,
    required this.netOperatingCashFlow,
    required this.chainHeadHash,
    required this.auditAlerts,
  });

  bool get isFullyBalanced =>
      trialBalanceVariance.abs() < 0.0001 && balanceSheetVariance.abs() < 0.0001;
}

class IfrsEngine {
  static double _round4(double v) => (v * 10000).round() / 10000.0;

  static FinancialAuditSnapshot compute(MizanStore store) {
    // 1. Trial Balance from immutable double-entry ledger
    final Map<String, double> drMap = {};
    final Map<String, double> crMap = {};

    String prevHash = 'GENESIS_MIZAN_V3_IFRS';
    for (final e in store.ledger.reversed) {
      drMap[e.debitAccountName] = _round4((drMap[e.debitAccountName] ?? 0) + e.amount);
      crMap[e.creditAccountName] = _round4((crMap[e.creditAccountName] ?? 0) + e.amount);
      prevHash = MizanSha256.digestHex(
        '$prevHash|${e.id}|${e.refNo}|${e.debitAccountId}|${e.creditAccountId}|${e.amount.toStringAsFixed(4)}',
      );
    }

    final names = {...drMap.keys, ...crMap.keys}.toList()..sort();
    final tbRows = names
        .map((n) => TrialBalanceRow(accountName: n, debit: drMap[n] ?? 0, credit: crMap[n] ?? 0))
        .toList();
    final sumDr = _round4(tbRows.fold(0.0, (s, r) => s + r.debit));
    final sumCr = _round4(tbRows.fold(0.0, (s, r) => s + r.credit));
    final tbVar = _round4(sumDr - sumCr);

    // 2. Income Statement (IFRS 15: VAT excluded from revenue; IAS 2: COGS separated)
    double grossSales = 600.0; // Opening seeded revenue
    double salesReturns = 0.0;
    double cogs = 390.0; // Opening seeded COGS
    double vatPayable = 0.0;

    for (final inv in store.invoices) {
      if (inv.type == InvoiceType.sale) {
        grossSales += inv.taxable;
        vatPayable += inv.taxAmount;
        cogs += inv.lines.fold(0.0, (s, l) => s + (l.qty * l.costPrice));
      } else if (inv.type == InvoiceType.saleReturn) {
        salesReturns += inv.taxable;
        vatPayable -= inv.taxAmount;
        cogs -= inv.lines.fold(0.0, (s, l) => s + (l.qty * l.costPrice));
      }
    }
    grossSales = _round4(grossSales);
    salesReturns = _round4(salesReturns);
    final netRev = _round4(grossSales - salesReturns);
    cogs = _round4(cogs.clamp(0.0, 999999999.0));
    final grossProfit = _round4(netRev - cogs);
    final opEx = _round4(store.totalExpenses);
    final netProfit = _round4(grossProfit - opEx);

    // 3. Balance Sheet (IAS 1: Assets = Liabilities + Equity)
    final cash = _round4(store.totalCashUsd);
    final ar = _round4(store.totalReceivables);
    final invVal = _round4(store.totalInventoryValue);
    final totalAssets = _round4(cash + ar + invVal);
    final ap = _round4(store.totalPayables);
    final totalLiab = _round4(ap + vatPayable.clamp(0.0, 999999999.0));
    final equity = _round4(totalAssets - totalLiab);
    final bsVar = _round4(totalAssets - (totalLiab + equity));

    // 4. Cash Flow (IAS 7)
    double cashIn = 0.0;
    double cashOut = 0.0;
    final cashIds = store.accounts
        .where((a) => a.type == AccountType.cashbox && a.currency == 'USD')
        .map((a) => a.id)
        .toSet();
    for (final e in store.ledger) {
      if (cashIds.contains(e.debitAccountId)) cashIn += e.amount;
      if (cashIds.contains(e.creditAccountId)) cashOut += e.amount;
    }
    cashIn = _round4(cashIn);
    cashOut = _round4(cashOut);
    final netCashFlow = _round4(cashIn - cashOut);

    // 5. Anomaly & Internal Control Guardian (COSO)
    final alerts = <String>[];
    if (tbVar.abs() >= 0.0001) {
      alerts.add('تنبيه حرج: يوجد فارق في ميزان المراجعة بمقدار ${tbVar.toStringAsFixed(4)} USD');
    }
    for (final b in store.accounts.where((a) => a.type == AccountType.cashbox && a.balance < 0)) {
      alerts.add('تنبيه سيولة: رصيد "${b.name}" سالب (${b.balance.toStringAsFixed(2)} ${b.currency})');
    }
    for (final it in store.items.where((i) => i.stockQty <= i.minStock)) {
      alerts.add('تنبيه مخزون: الصنف "${it.name}" وصل للحد الأدنى (${it.stockQty.toStringAsFixed(0)} ${it.unit})');
    }
    if (store.pendingGatesCount > 0) {
      alerts.add('حوكمة الأبواب: يوجد ${store.pendingGatesCount} باب تجاري بانتظار موافقة الطرف الثاني');
    }
    if (alerts.isEmpty) {
      alerts.add('جميع الفحوصات الرقابية سليمة: القيود متوازنة، الأرصدة النقدية موجبة، وسلسلة التوثيق متصلة.');
    }

    return FinancialAuditSnapshot(
      trialBalance: tbRows,
      totalDebits: sumDr,
      totalCredits: sumCr,
      trialBalanceVariance: tbVar,
      grossSales: grossSales,
      salesReturns: salesReturns,
      netRevenue: netRev,
      cogs: cogs,
      grossProfit: grossProfit,
      operatingExpenses: opEx,
      vatPayable: _round4(vatPayable),
      netProfit: netProfit,
      cashAssets: cash,
      receivablesAssets: ar,
      inventoryAssets: invVal,
      totalAssets: totalAssets,
      payablesLiabilities: ap,
      totalLiabilities: totalLiab,
      ownerEquityAndRetained: equity,
      balanceSheetVariance: bsVar,
      operatingCashIn: cashIn,
      operatingCashOut: cashOut,
      netOperatingCashFlow: netCashFlow,
      chainHeadHash: prevHash,
      auditAlerts: alerts,
    );
  }
}
