import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/mizan_models.dart';
import '../db/mizan_database.dart';
import '../engine/ifrs_engine.dart';

class MizanStore extends ChangeNotifier {
  static const _storageKey = 'mizan_v3_offline_ledger_v1';

  bool isAuthenticated = false;
  bool isOfflineMode = true;
  bool isDarkMode = false;
  bool isEnglish = false;
  bool hideEmptyA4Rows = true;
  bool contextualChatOpen = false;
  String currentUserEmail = 'owner@seha-pilot.local';
  String currentRole = 'OWNER — مالك المنشأة';
  WorkspaceMode mode = WorkspaceMode.easy;
  String entityName = 'منشأة ميزان الرئيسية';
  String bookCurrency = 'USD';
  List<String> branches = ['الفرع الرئيسي', 'فرع التوزيع الميداني'];
  String currentBranch = 'الفرع الرئيسي';
  List<String> costCenters = ['عام', 'التجارة والمبيعات', 'الخدمات والمشاريع', 'التوزيع'];
  bool isSqliteReady = false;
  int sqliteAuditCount = 0;

  List<String> warehouses = [
    'المخزن الرئيسي',
    'مخزن الفرع الثاني',
    'عهدة مركبة التوزيع',
  ];

  List<MizanAccount> accounts = [];
  List<MizanItem> items = [];
  List<MizanInvoice> invoices = [];
  List<LedgerEntry> ledger = [];
  List<TradeGate> gates = [];
  int syncQueueCount = 0;

  Map<String, bool> modules = {
    'الأبواب التجارية وتبادل المستندات': true,
    'الكتالوج التفاعلي عبر QR والسلة الحية': true,
    'تعدد اللغات (RTL/LTR)': true,
    'تعدد العملات وأسعار الصرف': true,
    'محرك فروقات العملة (IAS 21)': true,
    'سندات المصارفة المباشرة وتحويل الصناديق': true,
    'أوضاع شاشة العرض الخمسة': true,
    'مقارنة الأسعار وتحليل هامش الربح': true,
    'الجرد المخزني الفعلي والتسويات': true,
    'الدردشة التوافقية وأرشفتها القانونية': false,
    'وحدة الكاشير المتعدد وشاشة اللمس (POS)': false,
    'إدارة ورديات الكاشير وتقارير Z-Report': false,
    'مصفوفة المقاسات والألوان والباركود': false,
    'التشغيل بالأوامر الصوتية (تأكيد مزدوج)': false,
  };

  MizanStore() {
    _seedInitialData();
    loadFromDisk();
  }

  void _seedInitialData() {
    accounts = [
      MizanAccount(id: 'cash_usd', code: '1110', name: 'الصندوق الرئيسي (USD)', type: AccountType.cashbox, currency: 'USD', balance: 1250.0),
      MizanAccount(id: 'cash_sar', code: '1111', name: 'صندوق الريال (SAR)', type: AccountType.cashbox, currency: 'SAR', balance: 4500.0),
      MizanAccount(id: 'bank_main', code: '1115', name: 'البنك التجاري (USD)', type: AccountType.cashbox, currency: 'USD', balance: 3200.0),
      MizanAccount(id: 'cust_amal', code: '1120', name: 'متجر الأمل', type: AccountType.customer, currency: 'USD', phone: '777100200', balance: 600.0),
      MizanAccount(id: 'cust_noor', code: '1121', name: 'سوبرماركت النور', type: AccountType.customer, currency: 'USD', phone: '777300400', balance: 240.0),
      MizanAccount(id: 'supp_seha', code: '2110', name: 'شركة مياه صحة', type: AccountType.supplier, currency: 'USD', phone: '770555666', balance: -300.0),
      MizanAccount(id: 'emp_ahmed', code: '2120', name: 'الموزع أحمد', type: AccountType.employee, currency: 'USD', phone: '771999888', balance: 0.0),
      MizanAccount(id: 'exp_ops', code: '5110', name: 'مصروفات تشغيلية ونقل', type: AccountType.expense, currency: 'USD', balance: 120.0),
    ];

    items = [
      MizanItem(id: 'itm_water20', sku: 'WTR-020', name: 'عبوة مياه نقية 20 لتر', unit: 'عبوة', warehouse: 'المخزن الرئيسي', costPrice: 6.50, salePrice: 10.00, wholesalePrice: 8.50, marketPrice: 10.50, stockQty: 80, minStock: 15),
      MizanItem(id: 'itm_carton', sku: 'WTR-500', name: 'كرتون مياه 500 مل (24 عبوة)', unit: 'كرتون', warehouse: 'المخزن الرئيسي', costPrice: 3.20, salePrice: 5.00, wholesalePrice: 4.30, marketPrice: 4.80, stockQty: 140, minStock: 20),
      MizanItem(id: 'itm_veg', sku: 'FRSH-01', name: 'صندوق خضار طازجة (قابل للتلف)', unit: 'صندوق', warehouse: 'عهدة مركبة التوزيع', costPrice: 11.00, salePrice: 15.50, wholesalePrice: 14.00, marketPrice: 16.00, stockQty: 24, minStock: 5, perishable: true),
      MizanItem(id: 'itm_oil', sku: 'GRO-105', name: 'زيت طبخ نباتي 4 لتر', unit: 'جالون', warehouse: 'مخزن الفرع الثاني', costPrice: 7.40, salePrice: 9.80, wholesalePrice: 8.90, marketPrice: 10.00, stockQty: 35, minStock: 10),
    ];

    gates = [
      TradeGate(id: 'g1', title: 'باب المبيعات والمرتجعات', partnerName: 'متجر الأمل', status: 'ACTIVE', verificationTag: 'UBL 2.1 • SHA-256 Verified'),
      TradeGate(id: 'g2', title: 'باب التحميل والعهدة', partnerName: 'الموزع أحمد', status: 'PENDING', verificationTag: 'بانتظار موافقة الطرف الثاني (القرار 2)'),
    ];

    ledger = [
      LedgerEntry(
        id: 'led_0',
        date: DateTime.now().subtract(const Duration(hours: 3)),
        refNo: 'INV-1001',
        description: 'رصيد افتتاحي — مبيعات متجر الأمل (IFRS 15)',
        debitAccountId: 'cust_amal',
        debitAccountName: '1120 • متجر الأمل',
        creditAccountId: 'rev_sales',
        creditAccountName: '4110 • إيراد مبيعات (IFRS 15)',
        amount: 600.0,
        currency: 'USD',
        category: 'INVOICE',
      ),
    ];
  }

  Future<void> loadFromDisk() async {
    try {
      String? raw;
      try {
        raw = await MizanDatabase.loadStateJson();
        isSqliteReady = true;
        sqliteAuditCount = await MizanDatabase.auditEventCount();
      } catch (_) {
        isSqliteReady = false;
      }
      if (raw == null || raw.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        raw = prefs.getString(_storageKey);
      }
      if (raw == null || raw.isEmpty) {
        notifyListeners();
        return;
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;
      isDarkMode = data['isDarkMode'] as bool? ?? false;
      isEnglish = data['isEnglish'] as bool? ?? false;
      hideEmptyA4Rows = data['hideEmptyA4Rows'] as bool? ?? true;
      contextualChatOpen = data['contextualChatOpen'] as bool? ?? false;
      syncQueueCount = data['syncQueueCount'] as int? ?? 0;
      entityName = data['entityName'] as String? ?? entityName;
      bookCurrency = data['bookCurrency'] as String? ?? bookCurrency;
      if (data['branches'] is List) { branches = (data['branches'] as List).cast<String>(); }
      currentBranch = data['currentBranch'] as String? ?? branches.first;
      final mName = data['mode'] as String?;
      if (mName != null) {
        mode = WorkspaceMode.values.firstWhere((e) => e.name == mName, orElse: () => WorkspaceMode.easy);
      }
      if (data['warehouses'] is List) {
        warehouses = (data['warehouses'] as List).cast<String>();
      }
      if (data['accounts'] is List) {
        accounts = (data['accounts'] as List).map((e) => MizanAccount.fromJson(e as Map<String, dynamic>)).toList();
      }
      if (data['items'] is List) {
        items = (data['items'] as List).map((e) => MizanItem.fromJson(e as Map<String, dynamic>)).toList();
      }
      if (data['invoices'] is List) {
        invoices = (data['invoices'] as List).map((e) => MizanInvoice.fromJson(e as Map<String, dynamic>)).toList();
      }
      if (data['ledger'] is List) {
        ledger = (data['ledger'] as List).map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>)).toList();
      }
      if (data['gates'] is List) {
        gates = (data['gates'] as List).map((e) => TradeGate.fromJson(e as Map<String, dynamic>)).toList();
      }
      if (data['modules'] is Map) {
        final saved = (data['modules'] as Map).map((k, v) => MapEntry(k.toString(), v == true));
        modules.addAll(saved);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> saveToDisk() async {
    final payload = exportBackupJson();
    try {
      await MizanDatabase.saveStateJson(payload);
      isSqliteReady = true;
      sqliteAuditCount = await MizanDatabase.auditEventCount();
    } catch (_) {}
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, payload);
    } catch (_) {}
  }

  String exportBackupJson() {
    return jsonEncode({
      'version': '3.2.0-stage1',
      'entityName': entityName,
      'bookCurrency': bookCurrency,
      'branches': branches,
      'currentBranch': currentBranch,
      'exportedAt': DateTime.now().toIso8601String(),
      'isDarkMode': isDarkMode,
      'isEnglish': isEnglish,
      'hideEmptyA4Rows': hideEmptyA4Rows,
      'contextualChatOpen': contextualChatOpen,
      'syncQueueCount': syncQueueCount,
      'mode': mode.name,
      'warehouses': warehouses,
      'accounts': accounts.map((e) => e.toJson()).toList(),
      'items': items.map((e) => e.toJson()).toList(),
      'invoices': invoices.map((e) => e.toJson()).toList(),
      'ledger': ledger.map((e) => e.toJson()).toList(),
      'gates': gates.map((e) => e.toJson()).toList(),
      'modules': modules,
    });
  }

  Future<bool> importBackupJson(String raw) async {
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['accounts'] is! List || data['items'] is! List) return false;
      accounts = (data['accounts'] as List).map((e) => MizanAccount.fromJson(e as Map<String, dynamic>)).toList();
      items = (data['items'] as List).map((e) => MizanItem.fromJson(e as Map<String, dynamic>)).toList();
      invoices = ((data['invoices'] as List?) ?? []).map((e) => MizanInvoice.fromJson(e as Map<String, dynamic>)).toList();
      ledger = ((data['ledger'] as List?) ?? []).map((e) => LedgerEntry.fromJson(e as Map<String, dynamic>)).toList();
      gates = ((data['gates'] as List?) ?? []).map((e) => TradeGate.fromJson(e as Map<String, dynamic>)).toList();
      await saveToDisk();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> resetDemoData() async {
    invoices.clear();
    syncQueueCount = 0;
    _seedInitialData();
    await saveToDisk();
    notifyListeners();
  }

  /// Stage 1: True Zero-Start for a brand-new real business (0.00 balances, no demo debts)
  Future<void> startFreshEntity({
    required String newEntityName,
    required String mainBranch,
    required String currency,
  }) async {
    entityName = newEntityName.trim().isEmpty ? 'منشأتي الجديدة' : newEntityName.trim();
    bookCurrency = currency;
    branches = [mainBranch.trim().isEmpty ? 'الفرع الرئيسي' : mainBranch.trim()];
    currentBranch = branches.first;
    warehouses = ['المخزن الرئيسي'];
    accounts = [
      MizanAccount(id: 'cash_main', code: '1110', name: 'الصندوق الرئيسي ($currency)', type: AccountType.cashbox, currency: currency, balance: 0.0),
      MizanAccount(id: 'walkin_cash', code: '1120', name: 'عميل نقدي مباشر', type: AccountType.customer, currency: currency, balance: 0.0),
    ];
    items = [];
    invoices = [];
    ledger = [];
    gates = [];
    syncQueueCount = 0;
    try {
      await MizanDatabase.clearAll();
      await MizanDatabase.recordEffectiveSetting('entity_initialized', '$entityName|$currency');
      await MizanDatabase.appendAuditEvent(
        entityName: entityName,
        branchName: currentBranch,
        action: 'START_FRESH_ENTITY_ZERO',
        refNo: 'INIT-000',
        sha256Hash: MizanSha256.digestHex('INIT|$entityName|$currency'),
      );
    } catch (_) {}
    await saveToDisk();
    notifyListeners();
  }

  /// Stage 1: Immutable Reversing Entry (never deletes ledger history)
  void reverseLedgerEntry(LedgerEntry original) {
    final revNo = 'REV-${original.refNo}';
    // Reverse account balance effects if accounts exist
    for (final a in accounts) {
      if (a.id == original.debitAccountId) a.balance -= original.amount;
      if (a.id == original.creditAccountId) a.balance += original.amount;
    }
    final rev = LedgerEntry(
      id: 'rev_${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      refNo: revNo,
      description: 'قيد عكسي لتصحيح ${original.refNo}: ${original.description}',
      debitAccountId: original.creditAccountId,
      debitAccountName: original.creditAccountName,
      creditAccountId: original.debitAccountId,
      creditAccountName: original.debitAccountName,
      amount: original.amount,
      currency: original.currency,
      category: 'REVERSAL',
    );
    ledger.insert(0, rev);
    syncQueueCount++;
    MizanDatabase.appendAuditEvent(
      entityName: entityName,
      branchName: currentBranch,
      action: 'REVERSE_ENTRY',
      refNo: revNo,
      sha256Hash: MizanSha256.digestHex('$revNo|${original.amount}'),
    ).catchError((_) {});
    saveToDisk();
    notifyListeners();
  }

  void addBranch(String name) {
    final clean = name.trim();
    if (clean.isEmpty || branches.contains(clean)) return;
    branches.add(clean);
    MizanDatabase.recordEffectiveSetting('branch_added', clean).catchError((_) {});
    saveToDisk();
    notifyListeners();
  }

  // --- Computed KPIs ---
  double get totalCashUsd => accounts
      .where((a) => a.type == AccountType.cashbox && a.currency == 'USD')
      .fold(0.0, (s, a) => s + a.balance);

  double get totalReceivables => accounts
      .where((a) => a.type == AccountType.customer && a.balance > 0)
      .fold(0.0, (s, a) => s + a.balance);

  double get totalPayables => accounts
      .where((a) => a.type == AccountType.supplier && a.balance < 0)
      .fold(0.0, (s, a) => s + a.balance.abs());

  double get totalSalesRevenue => invoices
      .where((i) => i.type == InvoiceType.sale)
      .fold(0.0, (s, i) => s + i.netTotal) -
      invoices.where((i) => i.type == InvoiceType.saleReturn).fold(0.0, (s, i) => s + i.netTotal);

  double get totalExpenses => accounts
      .where((a) => a.type == AccountType.expense)
      .fold(0.0, (s, a) => s + a.balance);

  double get totalEstimatedProfit =>
      invoices.where((i) => i.type == InvoiceType.sale).fold(0.0, (s, i) => s + i.estimatedProfit) -
      totalExpenses;

  double get totalInventoryValue =>
      items.fold(0.0, (s, it) => s + (it.stockQty * it.costPrice));

  int get lowStockCount => items.where((i) => i.stockQty <= i.minStock).length;

  int get pendingGatesCount => gates.where((g) => g.status == 'PENDING').length;

  // --- Auth & Preferences ---
  void login({required String email, required String role, required bool offline}) {
    currentUserEmail = email.isEmpty ? 'owner@seha-pilot.local' : email;
    currentRole = role;
    isOfflineMode = offline;
    isAuthenticated = true;
    notifyListeners();
  }

  void logout() {
    isAuthenticated = false;
    notifyListeners();
  }

  void setMode(WorkspaceMode m) {
    mode = m;
    saveToDisk();
    notifyListeners();
  }

  void toggleDarkMode() {
    isDarkMode = !isDarkMode;
    saveToDisk();
    notifyListeners();
  }

  void toggleLanguage() {
    isEnglish = !isEnglish;
    saveToDisk();
    notifyListeners();
  }

  void setHideEmptyA4(bool v) {
    hideEmptyA4Rows = v;
    saveToDisk();
    notifyListeners();
  }

  void setContextualChat(bool v) {
    contextualChatOpen = v;
    saveToDisk();
    notifyListeners();
  }

  void toggleModule(String key, bool v) {
    modules[key] = v;
    saveToDisk();
    notifyListeners();
  }

  // --- CRUD: Accounts ---
  void addAccount({
    required String name,
    required AccountType type,
    String currency = 'USD',
    String phone = '',
    double openingBalance = 0.0,
  }) {
    final prefix = switch (type) {
      AccountType.cashbox => '111',
      AccountType.customer => '112',
      AccountType.supplier => '211',
      AccountType.employee => '212',
      AccountType.expense => '511',
      AccountType.asset => '121',
    };
    final code = '$prefix${accounts.length + 1}';
    final signedBalance = type == AccountType.supplier ? -openingBalance.abs() : openingBalance;
    accounts.add(MizanAccount(
      id: 'acc_${DateTime.now().millisecondsSinceEpoch}',
      code: code,
      name: name,
      type: type,
      currency: currency,
      phone: phone,
      balance: signedBalance,
    ));
    syncQueueCount++;
    saveToDisk();
    notifyListeners();
  }

  // --- CRUD: Warehouses & Items ---
  void addWarehouse(String name) {
    if (name.trim().isEmpty || warehouses.contains(name.trim())) return;
    warehouses.add(name.trim());
    saveToDisk();
    notifyListeners();
  }

  void upsertItem(MizanItem item) {
    final idx = items.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      items[idx] = item;
    } else {
      items.insert(0, item);
    }
    syncQueueCount++;
    saveToDisk();
    notifyListeners();
  }

  void deleteItem(String id) {
    items.removeWhere((i) => i.id == id);
    saveToDisk();
    notifyListeners();
  }

  void applyStocktake({required String itemId, required double actualQty, required String reason}) {
    final idx = items.indexWhere((i) => i.id == itemId);
    if (idx < 0) return;
    final it = items[idx];
    final diff = actualQty - it.stockQty;
    if (diff == 0) return;
    it.stockQty = actualQty;
    final val = (diff.abs()) * it.costPrice;
    ledger.insert(0, LedgerEntry(
      id: 'stk_${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      refNo: 'STK-${ledger.length + 101}',
      description: 'تسوية جرد: ${it.name} (${diff > 0 ? "+$diff" : "$diff"} ${it.unit}) — $reason',
      debitAccountId: diff > 0 ? 'inv_stock' : 'exp_ops',
      debitAccountName: diff > 0 ? '1130 • المخزون' : '5120 • عجز جرد مخزني',
      creditAccountId: diff > 0 ? 'rev_adj' : 'inv_stock',
      creditAccountName: diff > 0 ? '4190 • فائض جرد مخزني' : '1130 • المخزون',
      amount: val,
      currency: 'USD',
      category: 'STOCKTAKE',
    ));
    syncQueueCount++;
    saveToDisk();
    notifyListeners();
  }

  void transferStock({required String itemId, required String toWarehouse, required double qty}) {
    final idx = items.indexWhere((i) => i.id == itemId);
    if (idx < 0 || qty <= 0) return;
    final src = items[idx];
    if (src.stockQty < qty) return;
    src.stockQty -= qty;
    final existingDest = items.indexWhere((i) => i.name == src.name && i.warehouse == toWarehouse);
    if (existingDest >= 0) {
      items[existingDest].stockQty += qty;
    } else {
      items.add(MizanItem(
        id: 'itm_${DateTime.now().millisecondsSinceEpoch}',
        sku: '${src.sku}-TR',
        name: src.name,
        unit: src.unit,
        warehouse: toWarehouse,
        costPrice: src.costPrice,
        salePrice: src.salePrice,
        wholesalePrice: src.wholesalePrice,
        marketPrice: src.marketPrice,
        stockQty: qty,
        minStock: src.minStock,
        perishable: src.perishable,
      ));
    }
    syncQueueCount++;
    saveToDisk();
    notifyListeners();
  }

  // --- Real Invoice Posting (Updates Stock + Balances + Double-Entry Ledger!) ---
  MizanInvoice postInvoice({
    required InvoiceType type,
    required PaymentTerm paymentTerm,
    required MizanAccount party,
    required MizanAccount cashbox,
    required String warehouse,
    required List<InvoiceLine> lines,
    double discountPercent = 0,
    double taxPercent = 0,
    double shipping = 0,
    double partialPaid = 0,
    String note = '',
  }) {
    final invNo = 'INV-${1001 + invoices.length + 1}';
    final temp = MizanInvoice(
      id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
      number: invNo,
      date: DateTime.now(),
      type: type,
      paymentTerm: paymentTerm,
      partyId: party.id,
      partyName: party.name,
      cashboxId: cashbox.id,
      warehouse: warehouse,
      currency: cashbox.currency,
      lines: lines,
      discountPercent: discountPercent,
      taxPercent: taxPercent,
      shipping: shipping,
      paidAmount: paymentTerm == PaymentTerm.cash || paymentTerm == PaymentTerm.gateway
          ? 0
          : partialPaid,
      note: note,
    );
    final total = temp.netTotal;
    final effectivePaid = (paymentTerm == PaymentTerm.cash || paymentTerm == PaymentTerm.gateway)
        ? total
        : (paymentTerm == PaymentTerm.credit ? 0.0 : partialPaid.clamp(0.0, total));
    final remaining = total - effectivePaid;

    final inv = MizanInvoice(
      id: temp.id,
      number: invNo,
      date: temp.date,
      type: type,
      paymentTerm: paymentTerm,
      partyId: party.id,
      partyName: party.name,
      cashboxId: cashbox.id,
      warehouse: warehouse,
      currency: cashbox.currency,
      lines: lines,
      discountPercent: discountPercent,
      taxPercent: taxPercent,
      shipping: shipping,
      paidAmount: effectivePaid,
      note: note,
    );
    invoices.insert(0, inv);

    // 1. Update stock quantities
    for (final line in lines) {
      final idx = items.indexWhere((i) => i.id == line.itemId);
      if (idx >= 0) {
        if (type == InvoiceType.sale || type == InvoiceType.purchaseReturn) {
          items[idx].stockQty = (items[idx].stockQty - line.qty).clamp(0.0, 999999.0);
        } else {
          items[idx].stockQty += line.qty;
        }
      }
    }

    // 2. Update cashbox & party balances + create balanced double-entry journal
    if (type == InvoiceType.sale) {
      cashbox.balance += effectivePaid;
      party.balance += remaining;
      if (effectivePaid > 0) {
        ledger.insert(0, LedgerEntry(
          id: 'led_${DateTime.now().millisecondsSinceEpoch}_c',
          date: inv.date,
          refNo: invNo,
          description: 'تحصيل فاتورة بيع $invNo — ${party.name}',
          debitAccountId: cashbox.id,
          debitAccountName: '${cashbox.code} • ${cashbox.name}',
          creditAccountId: 'rev_sales',
          creditAccountName: '4110 • إيراد مبيعات (IFRS 15)',
          amount: effectivePaid,
          currency: cashbox.currency,
          category: 'INVOICE',
        ));
      }
      if (remaining > 0) {
        ledger.insert(0, LedgerEntry(
          id: 'led_${DateTime.now().millisecondsSinceEpoch}_r',
          date: inv.date,
          refNo: invNo,
          description: 'آجل فاتورة بيع $invNo — ${party.name}',
          debitAccountId: party.id,
          debitAccountName: '${party.code} • ${party.name}',
          creditAccountId: 'rev_sales',
          creditAccountName: '4110 • إيراد مبيعات (IFRS 15)',
          amount: remaining,
          currency: cashbox.currency,
          category: 'INVOICE',
        ));
      }
    } else if (type == InvoiceType.purchase) {
      cashbox.balance -= effectivePaid;
      party.balance -= remaining;
      ledger.insert(0, LedgerEntry(
        id: 'led_${DateTime.now().millisecondsSinceEpoch}_p',
        date: inv.date,
        refNo: invNo,
        description: 'فاتورة شراء $invNo — ${party.name}',
        debitAccountId: 'inv_stock',
        debitAccountName: '1130 • المشتريات والمخزون',
        creditAccountId: effectivePaid >= total ? cashbox.id : party.id,
        creditAccountName: effectivePaid >= total
            ? '${cashbox.code} • ${cashbox.name}'
            : '${party.code} • ${party.name}',
        amount: total,
        currency: cashbox.currency,
        category: 'INVOICE',
      ));
    } else if (type == InvoiceType.saleReturn) {
      cashbox.balance -= effectivePaid;
      party.balance -= remaining;
      ledger.insert(0, LedgerEntry(
        id: 'led_${DateTime.now().millisecondsSinceEpoch}_sr',
        date: inv.date,
        refNo: invNo,
        description: 'مرتجع مبيعات $invNo — ${party.name}',
        debitAccountId: 'rev_returns',
        debitAccountName: '4120 • مردودات مبيعات',
        creditAccountId: effectivePaid > 0 ? cashbox.id : party.id,
        creditAccountName: effectivePaid > 0
            ? '${cashbox.code} • ${cashbox.name}'
            : '${party.code} • ${party.name}',
        amount: total,
        currency: cashbox.currency,
        category: 'INVOICE',
      ));
    } else {
      cashbox.balance += effectivePaid;
      party.balance += remaining;
      ledger.insert(0, LedgerEntry(
        id: 'led_${DateTime.now().millisecondsSinceEpoch}_pr',
        date: inv.date,
        refNo: invNo,
        description: 'مرتجع مشتريات $invNo — ${party.name}',
        debitAccountId: effectivePaid > 0 ? cashbox.id : party.id,
        debitAccountName: effectivePaid > 0
            ? '${cashbox.code} • ${cashbox.name}'
            : '${party.code} • ${party.name}',
        creditAccountId: 'inv_stock',
        creditAccountName: '1130 • المخزون',
        amount: total,
        currency: cashbox.currency,
        category: 'INVOICE',
      ));
    }

    syncQueueCount++;
    saveToDisk();
    notifyListeners();
    return inv;
  }

  // --- Real Voucher / Receipt / Payment / Journal Posting ---
  void postVoucher({
    required VoucherType type,
    required MizanAccount cashbox,
    required MizanAccount counterAccount,
    required double amount,
    required String note,
  }) {
    if (amount <= 0) return;
    final refNo = '${type == VoucherType.receipt ? "RCV" : type == VoucherType.payment ? "PAY" : "JRN"}-${ledger.length + 201}';
    if (type == VoucherType.receipt) {
      cashbox.balance += amount;
      counterAccount.balance -= amount;
      ledger.insert(0, LedgerEntry(
        id: 'vch_${DateTime.now().millisecondsSinceEpoch}',
        date: DateTime.now(),
        refNo: refNo,
        description: note.isEmpty ? 'سند قبض من ${counterAccount.name}' : note,
        debitAccountId: cashbox.id,
        debitAccountName: '${cashbox.code} • ${cashbox.name}',
        creditAccountId: counterAccount.id,
        creditAccountName: '${counterAccount.code} • ${counterAccount.name}',
        amount: amount,
        currency: cashbox.currency,
        category: 'RECEIPT',
      ));
    } else if (type == VoucherType.payment) {
      cashbox.balance -= amount;
      counterAccount.balance += amount;
      ledger.insert(0, LedgerEntry(
        id: 'vch_${DateTime.now().millisecondsSinceEpoch}',
        date: DateTime.now(),
        refNo: refNo,
        description: note.isEmpty ? 'سند صرف إلى ${counterAccount.name}' : note,
        debitAccountId: counterAccount.id,
        debitAccountName: '${counterAccount.code} • ${counterAccount.name}',
        creditAccountId: cashbox.id,
        creditAccountName: '${cashbox.code} • ${cashbox.name}',
        amount: amount,
        currency: cashbox.currency,
        category: 'PAYMENT',
      ));
    } else {
      // Transfer / Journal: Debit counterAccount, Credit cashbox
      cashbox.balance -= amount;
      counterAccount.balance += amount;
      ledger.insert(0, LedgerEntry(
        id: 'vch_${DateTime.now().millisecondsSinceEpoch}',
        date: DateTime.now(),
        refNo: refNo,
        description: note.isEmpty ? 'قيد / تحويل من ${cashbox.name} إلى ${counterAccount.name}' : note,
        debitAccountId: counterAccount.id,
        debitAccountName: '${counterAccount.code} • ${counterAccount.name}',
        creditAccountId: cashbox.id,
        creditAccountName: '${cashbox.code} • ${cashbox.name}',
        amount: amount,
        currency: cashbox.currency,
        category: 'JOURNAL',
      ));
    }
    syncQueueCount++;
    saveToDisk();
    notifyListeners();
  }

  // --- Real IAS 21 Currency Exchange Posting ---
  void postFxExchange({
    required MizanAccount fromCashbox,
    required MizanAccount toCashbox,
    required double sourceAmount,
    required double bookRate,
    required double appliedRate,
  }) {
    if (sourceAmount <= 0) return;
    final expectedDest = sourceAmount * bookRate;
    final actualDest = sourceAmount * appliedRate;
    final fxDiff = actualDest - expectedDest; // negative = loss, positive = gain

    fromCashbox.balance -= sourceAmount;
    toCashbox.balance += actualDest;

    ledger.insert(0, LedgerEntry(
      id: 'fx_${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      refNo: 'FX-${ledger.length + 301}',
      description: 'مصارفة ${sourceAmount.toStringAsFixed(2)} ${fromCashbox.currency} -> ${actualDest.toStringAsFixed(2)} ${toCashbox.currency} (فارق IAS 21: ${fxDiff.toStringAsFixed(2)})',
      debitAccountId: toCashbox.id,
      debitAccountName: '${toCashbox.code} • ${toCashbox.name}',
      creditAccountId: fromCashbox.id,
      creditAccountName: '${fromCashbox.code} • ${fromCashbox.name}',
      amount: sourceAmount,
      currency: fromCashbox.currency,
      category: 'FX',
    ));
    syncQueueCount++;
    saveToDisk();
    notifyListeners();
  }

  // --- Trade Gates ---
  void approveGate(String id) {
    final idx = gates.indexWhere((g) => g.id == id);
    if (idx < 0) return;
    gates[idx].status = 'ACTIVE';
    syncQueueCount++;
    saveToDisk();
    notifyListeners();
  }

  void addGate({required String title, required String partnerName}) {
    gates.insert(0, TradeGate(
      id: 'g_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      partnerName: partnerName,
      status: 'PENDING',
      verificationTag: 'بانتظار موافقة الطرف الثاني (القرار 2)',
    ));
    syncQueueCount++;
    saveToDisk();
    notifyListeners();
  }

  List<LedgerEntry> statementForAccount(String accountId) {
    return ledger
        .where((e) => e.debitAccountId == accountId || e.creditAccountId == accountId)
        .toList();
  }
}
