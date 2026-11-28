import '../db/mizan_database.dart';
import '../models/mizan_models.dart';

class TrialBalanceRow {
  final String accountId;
  final String accountName;
  final double debit;
  final double credit;

  TrialBalanceRow({
    required this.accountId,
    required this.accountName,
    required this.debit,
    required this.credit,
  });

  double get net => debit - credit;
}

class FinancialAuditSnapshot {
  final DateTime asOfDate;
  final List<TrialBalanceRow> trialBalance;
  final double totalDebit;
  final double totalCredit;
  final double totalRevenue;
  final double totalExpense;
  final double netProfit;
  final double totalAssets;
  final double totalLiabilities;
  final double totalEquity;
  final String latestChainHash;
  final int verifiedEntryCount;
  final double trustScore; // 0..100 derived from SHA-256 verified ledger

  FinancialAuditSnapshot({
    required this.asOfDate,
    required this.trialBalance,
    required this.totalDebit,
    required this.totalCredit,
    required this.totalRevenue,
    required this.totalExpense,
    required this.netProfit,
    required this.totalAssets,
    required this.totalLiabilities,
    required this.totalEquity,
    required this.latestChainHash,
    required this.verifiedEntryCount,
    required this.trustScore,
  });

  double get trialVariance => totalDebit - totalCredit;
  bool get isBalanced => trialVariance.abs() < 0.01;
}

class ParsedRemittance {
  final double? amount;
  final String currency;
  final String sender;
  final String reference;

  ParsedRemittance({
    this.amount,
    required this.currency,
    required this.sender,
    required this.reference,
  });
}

class IfrsEngine {
  static double _round4(double v) => (v * 10000).round() / 10000.0;

  /// Reproduces Trial Balance, IAS 1 Income Statement, Balance Sheet & SHA-256 Chain
  /// strictly from journal_headers + journal_lines up to [asOfDate].
  static FinancialAuditSnapshot compute({
    required List<MizanAccount> accounts,
    required List<JournalHeader> journals,
    required DateTime asOfDate,
    String? branchFilter,
  }) {
    final Map<String, MizanAccount> acctMap = {
      for (final a in accounts) a.id: a,
    };
    final Map<String, double> drMap = {};
    final Map<String, double> crMap = {};
    final Map<String, String> nameMap = {};

    String prevHash = 'GENESIS_MIZAN_V33_IFRS';
    int verified = 0;

    final filtered = journals.where((j) {
      if (j.entryDate.isAfter(asOfDate)) return false;
      if (branchFilter != null && branchFilter.isNotEmpty && j.branchName != branchFilter) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => a.entryDate.compareTo(b.entryDate));

    for (final j in filtered) {
      if (!j.isBalanced) continue;
      verified++;
      for (final l in j.lines) {
        nameMap[l.accountId] = l.accountName;
        drMap[l.accountId] = _round4((drMap[l.accountId] ?? 0) + l.debitBook);
        crMap[l.accountId] = _round4((crMap[l.accountId] ?? 0) + l.creditBook);
      }
      prevHash = MizanSha256.digestHex(
        '$prevHash|${j.id}|${j.refNo}|${j.totalDebit.toStringAsFixed(4)}|${j.totalCredit.toStringAsFixed(4)}',
      );
    }

    final ids = {...drMap.keys, ...crMap.keys}.toList()..sort();
    final List<TrialBalanceRow> tb = [];
    double sumDr = 0, sumCr = 0;
    double rev = 0, exp = 0;
    double assets = 0, liab = 0, eq = 0;

    for (final id in ids) {
      final dr = drMap[id] ?? 0.0;
      final cr = crMap[id] ?? 0.0;
      sumDr = _round4(sumDr + dr);
      sumCr = _round4(sumCr + cr);
      final acc = acctMap[id];
      final label = acc?.name ?? nameMap[id] ?? id;
      tb.add(TrialBalanceRow(accountId: id, accountName: label, debit: dr, credit: cr));

      if (acc != null) {
        switch (acc.type) {
          case AccountType.revenue:
            rev = _round4(rev + (cr - dr));
            break;
          case AccountType.expense:
            exp = _round4(exp + (dr - cr));
            break;
          case AccountType.asset:
          case AccountType.cashbox:
          case AccountType.bank:
          case AccountType.customer:
            assets = _round4(assets + (dr - cr));
            break;
          case AccountType.liability:
          case AccountType.supplier:
          case AccountType.employee:
            liab = _round4(liab + (cr - dr));
            break;
          case AccountType.equity:
            eq = _round4(eq + (cr - dr));
            break;
        }
      }
    }

    final netProfit = _round4(rev - exp);
    final totalEquity = _round4(eq + netProfit);

    // Ledger-Backed Trust & Reputation Score (0..100)
    final double balanceFactor = (sumDr - sumCr).abs() < 0.01 ? 50.0 : 0.0;
    final double volumeFactor = verified == 0 ? 35.0 : (verified >= 20 ? 50.0 : 35.0 + verified * 0.75);
    final double trust = (balanceFactor + volumeFactor).clamp(0.0, 100.0);

    return FinancialAuditSnapshot(
      asOfDate: asOfDate,
      trialBalance: tb,
      totalDebit: sumDr,
      totalCredit: sumCr,
      totalRevenue: rev,
      totalExpense: exp,
      netProfit: netProfit,
      totalAssets: assets,
      totalLiabilities: liab,
      totalEquity: totalEquity,
      latestChainHash: prevHash,
      verifiedEntryCount: verified,
      trustScore: trust,
    );
  }

  /// Smart SMS/WhatsApp Remittance Parser (extracts amount, currency, reference, sender).
  static ParsedRemittance parseRemittanceText(String text) {
    final amountMatch = RegExp(r'(\d[\d,\.]{1,12})').firstMatch(text);
    final amount = amountMatch != null
        ? double.tryParse(amountMatch.group(1)!.replaceAll(',', ''))
        : null;

    String currency = 'USD';
    final upper = text.toUpperCase();
    if (text.contains('ريال سعودي') || upper.contains('SAR') || text.contains('سعودي')) {
      currency = 'SAR';
    } else if (text.contains('ريال يمني') || upper.contains('YER') || text.contains('يمني')) {
      currency = 'YER';
    } else if (upper.contains('AED') || text.contains('درهم')) {
      currency = 'AED';
    } else if (upper.contains('EUR') || text.contains('يورو')) {
      currency = 'EUR';
    }

    final refMatch = RegExp(r'(?:رقم|حوالة|Ref|ID|#)[:\s#-]*([A-Za-z0-9\-]{4,18})', caseSensitive: false)
        .firstMatch(text);
    final ref = refMatch?.group(1) ?? 'REM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final senderMatch = RegExp(r'(?:من|المرسل|From)[:\s]+([^\n,،]{2,35})', caseSensitive: false)
        .firstMatch(text);
    final sender = senderMatch?.group(1)?.trim() ?? 'مرسل حوالة';

    return ParsedRemittance(
      amount: amount,
      currency: currency,
      sender: sender,
      reference: ref,
    );
  }
}
