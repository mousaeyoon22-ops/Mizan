import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../db/mizan_database.dart';
import '../engine/ifrs_engine.dart';
import '../l10n/mizan_l10n.dart';
import '../models/mizan_models.dart';

class MizanStore extends ChangeNotifier {
  bool isLoaded = false;
  bool isAuthenticated = false;
  bool isDarkMode = false;
  String languageCode = 'ar';
  WorkspaceMode mode = WorkspaceMode.standard;

  String currentUserEmail = 'owner@mizan.local';
  String currentRole = 'OWNER — مالك المنشأة';
  String entityName = 'منشأة ميزان العالمية';
  String bookCurrency = 'USD';
  String countryPackCode = 'YE';
  double defaultVatPercent = 5.0;
  DateTime? fiscalLockDate;
  int activeSqliteTables = 18;
  String storefrontHandle = 'mizan-main-store';
  String syncEndpointUrl = 'https://api.mizan-cloud.local/v1/sync';

  List<String> branches = ['الفرع الرئيسي', 'فرع التوزيع الميداني'];
  String currentBranch = 'الفرع الرئيسي';
  List<String> warehouses = ['المخزن الرئيسي', 'مخزن التوزيع الميداني'];
  List<String> costCenters = [
    'عام',
    'التجارة والمبيعات',
    'الخدمات والمشاريع',
    'المقاولات',
    'التصنيع',
    'الاشتراكات',
    'توزيع المياه',
  ];

  Set<SectorCycle> activeCycles = {
    SectorCycle.trade,
    SectorCycle.services,
    SectorCycle.contracting,
    SectorCycle.manufacturing,
    SectorCycle.subscriptions,
    SectorCycle.waterDistribution,
  };

  List<MizanAccount> accounts = [];
  List<MizanItem> items = [];
  List<FxRateRecord> fxRates = [];
  List<MizanDocument> documents = [];
  List<JournalHeader> journals = [];
  List<FixedAsset> fixedAssets = [];
  List<BudgetLine> budgets = [];
  List<CustomDoorSchema> customDoors = [];
  List<PairedGate> pairedGates = [];
  List<StorefrontListing> storefrontListings = [];
  List<StorefrontOrder> storefrontOrders = [];
  List<SyncOutboxItem> syncOutbox = [];
  List<Map<String, dynamic>> auditEvents = [];

  MizanStore() {
    loadAll();
  }

  String t(String key) => MizanL10n.tr(languageCode, key);
  bool get isRtl => MizanL10n.isRtl(languageCode);

  double fxRateFor(String currencyCode, {DateTime? asOf}) {
    if (currencyCode == bookCurrency) return 1.0;
    final cutoff = asOf ?? DateTime.now();
    final matches = fxRates
        .where((r) => r.currencyCode == currencyCode && !r.effectiveFrom.isAfter(cutoff))
        .toList()
      ..sort((a, b) => b.effectiveFrom.compareTo(a.effectiveFrom));
    if (matches.isNotEmpty) return matches.first.rateToBook;
    final any = fxRates.where((r) => r.currencyCode == currencyCode).toList();
    return any.isNotEmpty ? any.first.rateToBook : 1.0;
  }

  FinancialAuditSnapshot auditSnapshot({DateTime? asOf, String? branch}) {
    return IfrsEngine.compute(
      accounts: accounts,
      journals: journals,
      asOfDate: asOf ?? DateTime.now().add(const Duration(minutes: 1)),
      branchFilter: branch,
    );
  }

  double get totalCashBalance => accounts
      .where((a) => a.type == AccountType.cashbox || a.type == AccountType.bank)
      .fold(0.0, (s, a) => s + a.balance);

  double get totalReceivables => accounts
      .where((a) => a.type == AccountType.customer)
      .fold(0.0, (s, a) => s + (a.balance > 0 ? a.balance : 0));

  double get totalPayables => accounts
      .where((a) => a.type == AccountType.supplier)
      .fold(0.0, (s, a) => s + (a.balance < 0 ? -a.balance : a.balance));

  Future<void> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode = prefs.getBool('mizan_dark') ?? false;
    languageCode = prefs.getString('mizan_lang') ?? 'ar';
    entityName = prefs.getString('mizan_entity') ?? entityName;
    bookCurrency = prefs.getString('mizan_book_curr') ?? 'USD';
    countryPackCode = prefs.getString('mizan_country') ?? 'YE';
    defaultVatPercent = prefs.getDouble('mizan_vat') ?? 5.0;
    currentBranch = prefs.getString('mizan_branch') ?? 'الفرع الرئيسي';
    storefrontHandle = prefs.getString('mizan_storefront') ?? 'mizan-main-store';
    final lockStr = prefs.getString('mizan_fiscal_lock');
    fiscalLockDate = lockStr != null ? DateTime.tryParse(lockStr) : null;
    final modeIdx = prefs.getInt('mizan_mode') ?? 1;
    mode = WorkspaceMode.values[modeIdx.clamp(0, WorkspaceMode.values.length - 1)];

    final db = await MizanDatabase.instance();
    activeSqliteTables = await MizanDatabase.countTables();

    final accRows = await db.query('accounts', orderBy: 'code ASC');
    if (accRows.isEmpty) {
      await _seedDefaultRelationalData(db);
    }

    await _reloadRelationalTables(db);
    isLoaded = true;
    notifyListeners();
  }

  Future<void> _reloadRelationalTables(Database db) async {
    final bRows = await db.query('branches');
    if (bRows.isNotEmpty) {
      branches = bRows.map((e) => e['name'] as String).toList();
      if (!branches.contains(currentBranch)) currentBranch = branches.first;
    }

    final wRows = await db.query('warehouses');
    if (wRows.isNotEmpty) {
      warehouses = wRows.map((e) => e['name'] as String).toList();
    }

    final accRows = await db.query('accounts', orderBy: 'code ASC');
    accounts = accRows.map((m) => MizanAccount.fromMap(m)).toList();

    final unitRows = await db.query('item_units');
    final Map<String, List<ItemUnit>> unitsByItem = {};
    for (final u in unitRows) {
      final unit = ItemUnit.fromMap(u);
      unitsByItem.putIfAbsent(unit.itemId, () => []).add(unit);
    }
    final itemRows = await db.query('items', orderBy: 'sku ASC');
    items = itemRows
        .map((m) => MizanItem.fromMap(m, unitsByItem[m['id'] as String] ?? []))
        .toList();

    final fxRows = await db.query('fx_rates', orderBy: 'effective_from DESC');
    fxRates = fxRows.map((m) => FxRateRecord.fromMap(m)).toList();

    final docLineRows = await db.query('document_lines');
    final Map<String, List<DocumentLine>> linesByDoc = {};
    for (final dl in docLineRows) {
      final line = DocumentLine.fromMap(dl);
      linesByDoc.putIfAbsent(line.documentId, () => []).add(line);
    }
    final docRows = await db.query('documents', orderBy: 'doc_date DESC');
    documents = docRows
        .map((m) => MizanDocument.fromMap(m, linesByDoc[m['id'] as String] ?? []))
        .toList();

    final jLineRows = await db.query('journal_lines');
    final Map<String, List<JournalLine>> linesByJournal = {};
    for (final jl in jLineRows) {
      final line = JournalLine.fromMap(jl);
      linesByJournal.putIfAbsent(line.headerId, () => []).add(line);
    }
    final jHeaderRows = await db.query('journal_headers', orderBy: 'entry_date DESC');
    journals = jHeaderRows
        .map((m) => JournalHeader.fromMap(m, linesByJournal[m['id'] as String] ?? []))
        .toList();

    final faRows = await db.query('fixed_assets');
    fixedAssets = faRows.map((m) => FixedAsset.fromMap(m)).toList();

    final budRows = await db.query('budgets');
    budgets = budRows.map((m) => BudgetLine.fromMap(m)).toList();

    final doorRows = await db.query('custom_schemas');
    customDoors = doorRows.map((m) => CustomDoorSchema.fromMap(m)).toList();

    final gateRows = await db.query('paired_gates');
    pairedGates = gateRows.map((m) => PairedGate.fromMap(m)).toList();

    final listRows = await db.query('storefront_listings');
    storefrontListings = listRows.map((m) => StorefrontListing.fromMap(m)).toList();

    final ordRows = await db.query('storefront_orders', orderBy: 'created_at DESC');
    storefrontOrders = ordRows.map((m) => StorefrontOrder.fromMap(m)).toList();

    final outRows = await db.query('sync_outbox', orderBy: 'created_at DESC');
    syncOutbox = outRows.map((m) => SyncOutboxItem.fromMap(m)).toList();

    auditEvents = await db.query('audit_events', orderBy: 'id DESC', limit: 60);
  }

  Future<void> _seedDefaultRelationalData(Database db) async {
    await db.insert('branches', {'id': 'br-1', 'name': 'الفرع الرئيسي', 'is_active': 1},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('branches', {'id': 'br-2', 'name': 'فرع التوزيع الميداني', 'is_active': 1},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('warehouses', {'id': 'wh-1', 'name': 'المخزن الرئيسي', 'branch_name': 'الفرع الرئيسي'},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert('warehouses', {'id': 'wh-2', 'name': 'مخزن التوزيع الميداني', 'branch_name': 'فرع التوزيع الميداني'},
        conflictAlgorithm: ConflictAlgorithm.ignore);

    final baseAccounts = [
      MizanAccount(id: 'acc-cash', code: '1101', name: 'الصندوق الرئيسي', nameI18n: {'en': 'Main Cashbox', 'fr': 'Caisse Principale', 'tr': 'Ana Kasa', 'ur': 'مرکزی کیش باکس'}, type: AccountType.cashbox, currency: bookCurrency),
      MizanAccount(id: 'acc-bank', code: '1102', name: 'الحساب البنكي', nameI18n: {'en': 'Main Bank', 'fr': 'Banque', 'tr': 'Ana Banka', 'ur': 'مرکزی بینک'}, type: AccountType.bank, currency: bookCurrency),
      MizanAccount(id: 'acc-walkin', code: '1200', name: 'عميل نقدي مباشر', nameI18n: {'en': 'Walk-in Cash Customer', 'fr': 'Client Comptant', 'tr': 'Peşin Müşteri', 'ur': 'نقد گاہک'}, type: AccountType.customer, currency: bookCurrency),
      MizanAccount(id: 'acc-cust-1', code: '1201', name: 'شركة النور للتجارة', nameI18n: {'en': 'Al-Noor Trading Co.'}, type: AccountType.customer, currency: bookCurrency, creditLimit: 5000),
      MizanAccount(id: 'acc-inv', code: '1301', name: 'المخزون السلعي', nameI18n: {'en': 'Inventory Asset'}, type: AccountType.asset, currency: bookCurrency),
      MizanAccount(id: 'acc-fa', code: '1501', name: 'الأصول الثابتة والمعدات', nameI18n: {'en': 'Fixed Assets & Equipment'}, type: AccountType.asset, currency: bookCurrency),
      MizanAccount(id: 'acc-sup-1', code: '2101', name: 'مصنع مياه صحة', nameI18n: {'en': 'Seha Water Factory'}, type: AccountType.supplier, currency: bookCurrency),
      MizanAccount(id: 'acc-vat', code: '2201', name: 'ضريبة القيمة المضافة المستحقة', nameI18n: {'en': 'VAT Payable'}, type: AccountType.liability, currency: bookCurrency),
      MizanAccount(id: 'acc-ret', code: '2202', name: 'تأمينات ومحتجزات المقاولات', nameI18n: {'en': 'Contracting Retention'}, type: AccountType.liability, currency: bookCurrency),
      MizanAccount(id: 'acc-eq', code: '3101', name: 'رأس المال', nameI18n: {'en': 'Owner Equity'}, type: AccountType.equity, currency: bookCurrency),
      MizanAccount(id: 'acc-rev', code: '4101', name: 'إيرادات المبيعات والخدمات', nameI18n: {'en': 'Sales & Service Revenue'}, type: AccountType.revenue, currency: bookCurrency),
      MizanAccount(id: 'acc-fx', code: '4901', name: 'أرباح وخسائر فروق العملة (IAS 21)', nameI18n: {'en': 'FX Gain/Loss (IAS 21)'}, type: AccountType.revenue, currency: bookCurrency),
      MizanAccount(id: 'acc-cogs', code: '5101', name: 'تكلفة البضاعة المباعة والتصنيع', nameI18n: {'en': 'COGS & Production Cost'}, type: AccountType.expense, currency: bookCurrency),
      MizanAccount(id: 'acc-exp', code: '5201', name: 'مصروفات تشغيلية وإهلاك', nameI18n: {'en': 'Operating & Depreciation Expense'}, type: AccountType.expense, currency: bookCurrency),
    ];
    for (final a in baseAccounts) {
      await db.insert('accounts', a.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final now = DateTime.now();
    final defaultFx = [
      FxRateRecord(id: 'fx-usd', currencyCode: 'USD', currencyName: 'US Dollar — دولار أمريكي', rateToBook: 1.0, effectiveFrom: now),
      FxRateRecord(id: 'fx-sar', currencyCode: 'SAR', currencyName: 'Saudi Riyal — ريال سعودي', rateToBook: 0.2667, effectiveFrom: now),
      FxRateRecord(id: 'fx-yer', currencyCode: 'YER', currencyName: 'Yemeni Rial — ريال يمني', rateToBook: 0.00188, effectiveFrom: now),
      FxRateRecord(id: 'fx-aed', currencyCode: 'AED', currencyName: 'UAE Dirham — درهم إماراتي', rateToBook: 0.2723, effectiveFrom: now),
      FxRateRecord(id: 'fx-eur', currencyCode: 'EUR', currencyName: 'Euro — يورو أوروبي', rateToBook: 1.085, effectiveFrom: now),
    ];
    for (final r in defaultFx) {
      await db.insert('fx_rates', r.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    // Seed 2 rich multi-unit items with canonical MGID
    final waterId = 'item-water-1';
    final waterMgid = MizanSha256.generateMgid('WTR', 'مياه صحة نقية 500 مل', 'عبوة');
    final waterItem = MizanItem(
      id: waterId,
      mgid: waterMgid,
      sku: 'WTR-500',
      name: 'مياه صحة نقية 500 مل',
      nameI18n: {'en': 'Seha Pure Water 500ml', 'fr': 'Eau Pure Seha 500ml', 'tr': 'Seha Saf Su 500ml', 'ur': 'صحت صاف پانی 500ml'},
      baseUnit: 'عبوة',
      warehouse: 'المخزن الرئيسي',
      binLocation: 'A-01',
      barcode: '6291000050012',
      batchNo: 'B2026-11',
      expiryDate: '2027-11-30',
      costPrice: 0.15,
      salePrice: 0.25,
      wholesalePrice: 0.20,
      marketPrice: 0.28,
      stockQty: 240,
      minStock: 48,
    );
    await db.insert('items', waterItem.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    for (final u in [
      ItemUnit(id: 'u-w-1', itemId: waterId, name: 'عبوة (أساس)', factorToBase: 1, barcode: '6291000050012', salePrice: 0.25, isDefaultSale: true),
      ItemUnit(id: 'u-w-2', itemId: waterId, name: 'شدة (6 عبوات)', factorToBase: 6, barcode: '6291000050067', salePrice: 1.40),
      ItemUnit(id: 'u-w-3', itemId: waterId, name: 'كرتون (24 عبوة)', factorToBase: 24, barcode: '6291000050241', salePrice: 5.20, isDefaultPurchase: true),
    ]) {
      await db.insert('item_units', u.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }

    final srvId = 'item-srv-1';
    final srvItem = MizanItem(
      id: srvId,
      mgid: MizanSha256.generateMgid('SRV', 'باقة صيانة ودعم فني شهري', 'ساعة'),
      sku: 'SRV-001',
      name: 'باقة صيانة ودعم فني شهري',
      nameI18n: {'en': 'Monthly Technical Support Plan'},
      isService: true,
      baseUnit: 'ساعة',
      warehouse: 'المخزن الرئيسي',
      costPrice: 10.0,
      salePrice: 35.0,
      wholesalePrice: 28.0,
      marketPrice: 40.0,
      stockQty: 0,
    );
    await db.insert('items', srvItem.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    await db.insert(
      'item_units',
      ItemUnit(id: 'u-s-1', itemId: srvId, name: 'ساعة عمل', factorToBase: 1, salePrice: 35.0, isDefaultSale: true).toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert(
      'paired_gates',
      PairedGate(
        id: 'gate-1',
        gateCode: 'MZN-GATE-SEHA-01',
        partnerName: 'مصنع مياه صحة — بوابة التوريد',
        gateType: 'توريد وتوزيع B2B',
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await db.insert(
      'storefront_listings',
      StorefrontListing(
        id: 'sf-1',
        itemId: waterId,
        mgid: waterMgid,
        publicTitle: 'كرتون مياه صحة نقية 500 مل (24 عبوة)',
        publicPrice: 5.20,
        currency: bookCurrency,
        visibility: 'PUBLIC',
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    await MizanDatabase.saveEffectiveSetting('entity_name', entityName);
    await MizanDatabase.saveEffectiveSetting('book_currency', bookCurrency);
    await MizanDatabase.saveEffectiveSetting('vat_percent', defaultVatPercent.toString());
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mizan_dark', isDarkMode);
    await prefs.setString('mizan_lang', languageCode);
    await prefs.setString('mizan_entity', entityName);
    await prefs.setString('mizan_book_curr', bookCurrency);
    await prefs.setString('mizan_country', countryPackCode);
    await prefs.setDouble('mizan_vat', defaultVatPercent);
    await prefs.setString('mizan_branch', currentBranch);
    await prefs.setString('mizan_storefront', storefrontHandle);
    await prefs.setInt('mizan_mode', mode.index);
    if (fiscalLockDate != null) {
      await prefs.setString('mizan_fiscal_lock', fiscalLockDate!.toIso8601String());
    } else {
      await prefs.remove('mizan_fiscal_lock');
    }
  }

  void login(String email) {
    currentUserEmail = email.trim().isEmpty ? 'owner@mizan.local' : email.trim();
    isAuthenticated = true;
    notifyListeners();
  }

  void logout() {
    isAuthenticated = false;
    notifyListeners();
  }

  Future<void> setLanguage(String code) async {
    languageCode = code;
    await _savePrefs();
    notifyListeners();
  }

  Future<void> toggleDarkMode() async {
    isDarkMode = !isDarkMode;
    await _savePrefs();
    notifyListeners();
  }

  Future<void> setMode(WorkspaceMode newMode) async {
    mode = newMode;
    await _savePrefs();
    notifyListeners();
  }

  void toggleCycle(SectorCycle cycle) {
    if (activeCycles.contains(cycle)) {
      activeCycles.remove(cycle);
    } else {
      activeCycles.add(cycle);
    }
    MizanDatabase.saveEffectiveSetting(
      'active_cycles',
      activeCycles.map((e) => e.name).join(','),
    );
    notifyListeners();
  }

  Future<void> setFiscalLockDate(DateTime? dt) async {
    fiscalLockDate = dt;
    await _savePrefs();
    await MizanDatabase.saveEffectiveSetting(
      'fiscal_lock_date',
      dt?.toIso8601String() ?? 'UNLOCKED',
    );
    notifyListeners();
  }

  /// True 0.00 Zero-Start Fresh Entity Reset (preserves relational schema & core COA at 0.00).
  Future<void> startFreshEntity({
    required String newEntityName,
    required String newBranchName,
    required String newBookCurrency,
  }) async {
    final db = await MizanDatabase.instance();
    for (final tbl in [
      'documents',
      'document_lines',
      'journal_headers',
      'journal_lines',
      'fixed_assets',
      'budgets',
      'storefront_orders',
      'sync_outbox',
      'accounts',
      'items',
      'item_units',
      'branches',
      'warehouses',
    ]) {
      await db.delete(tbl);
    }

    entityName = newEntityName.trim().isEmpty ? 'منشأة جديدة' : newEntityName.trim();
    currentBranch = newBranchName.trim().isEmpty ? 'الفرع الرئيسي' : newBranchName.trim();
    bookCurrency = newBookCurrency;
    fiscalLockDate = null;

    await db.insert('branches', {'id': 'br-1', 'name': currentBranch, 'is_active': 1});
    await db.insert('warehouses', {'id': 'wh-1', 'name': 'المخزن الرئيسي', 'branch_name': currentBranch});

    final zeroAccounts = [
      MizanAccount(id: 'acc-cash', code: '1101', name: 'الصندوق الرئيسي', nameI18n: {'en': 'Main Cashbox'}, type: AccountType.cashbox, currency: bookCurrency),
      MizanAccount(id: 'acc-bank', code: '1102', name: 'الحساب البنكي', nameI18n: {'en': 'Main Bank'}, type: AccountType.bank, currency: bookCurrency),
      MizanAccount(id: 'acc-walkin', code: '1200', name: 'عميل نقدي مباشر', nameI18n: {'en': 'Walk-in Cash Customer'}, type: AccountType.customer, currency: bookCurrency),
      MizanAccount(id: 'acc-inv', code: '1301', name: 'المخزون السلعي', nameI18n: {'en': 'Inventory'}, type: AccountType.asset, currency: bookCurrency),
      MizanAccount(id: 'acc-vat', code: '2201', name: 'ضريبة القيمة المضافة', nameI18n: {'en': 'VAT Payable'}, type: AccountType.liability, currency: bookCurrency),
      MizanAccount(id: 'acc-eq', code: '3101', name: 'رأس المال', nameI18n: {'en': 'Owner Equity'}, type: AccountType.equity, currency: bookCurrency),
      MizanAccount(id: 'acc-rev', code: '4101', name: 'إيرادات المبيعات والخدمات', nameI18n: {'en': 'Sales Revenue'}, type: AccountType.revenue, currency: bookCurrency),
      MizanAccount(id: 'acc-fx', code: '4901', name: 'فروق العملة (IAS 21)', nameI18n: {'en': 'FX Gain/Loss'}, type: AccountType.revenue, currency: bookCurrency),
      MizanAccount(id: 'acc-cogs', code: '5101', name: 'تكلفة المبيعات', nameI18n: {'en': 'COGS'}, type: AccountType.expense, currency: bookCurrency),
      MizanAccount(id: 'acc-exp', code: '5201', name: 'مصروفات تشغيلية', nameI18n: {'en': 'Operating Expenses'}, type: AccountType.expense, currency: bookCurrency),
    ];
    for (final a in zeroAccounts) {
      await db.insert('accounts', a.toMap());
    }

    await MizanDatabase.saveEffectiveSetting('entity_name', entityName);
    await MizanDatabase.saveEffectiveSetting('book_currency', bookCurrency);
    await MizanDatabase.logAuditEvent(
      entityName: entityName,
      branchName: currentBranch,
      action: 'START_FRESH_ENTITY_ZERO',
      refNo: 'ZERO-0.00',
      sha256Hash: MizanSha256.digestHex('ZERO|$entityName|$currentBranch|$bookCurrency|${DateTime.now().toIso8601String()}'),
    );
    await _savePrefs();
    await _reloadRelationalTables(db);
    notifyListeners();
  }

  Future<void> addBranch(String name) async {
    if (name.trim().isEmpty) return;
    final db = await MizanDatabase.instance();
    await db.insert('branches', {'id': MizanUuidV7.next(), 'name': name.trim(), 'is_active': 1},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await _reloadRelationalTables(db);
    notifyListeners();
  }

  Future<void> addWarehouse(String name) async {
    if (name.trim().isEmpty) return;
    final db = await MizanDatabase.instance();
    await db.insert('warehouses', {'id': MizanUuidV7.next(), 'name': name.trim(), 'branch_name': currentBranch},
        conflictAlgorithm: ConflictAlgorithm.ignore);
    await _reloadRelationalTables(db);
    notifyListeners();
  }

  Future<void> addAccount(MizanAccount acc) async {
    final db = await MizanDatabase.instance();
    await db.insert('accounts', acc.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await _queueOutbox(db, 'account', acc.toMap());
    await _reloadRelationalTables(db);
    notifyListeners();
  }

  Future<void> upsertItem(MizanItem item) async {
    final db = await MizanDatabase.instance();
    await db.insert('items', item.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await db.delete('item_units', where: 'item_id = ?', whereArgs: [item.id]);
    for (final u in item.units) {
      await db.insert('item_units', u.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await _queueOutbox(db, 'item', item.toMap());
    await _reloadRelationalTables(db);
    notifyListeners();
  }

  Future<void> transferStock({
    required String itemId,
    required String targetWarehouse,
    required double qtyBase,
  }) async {
    final db = await MizanDatabase.instance();
    final idx = items.indexWhere((i) => i.id == itemId);
    if (idx == -1) return;
    final src = items[idx];
    if (qtyBase <= 0 || qtyBase > src.stockQty) return;
    await db.update('items', {'stock_qty': src.stockQty - qtyBase}, where: 'id = ?', whereArgs: [src.id]);

    final copyId = MizanUuidV7.next();
    final transferred = MizanItem(
      id: copyId,
      mgid: src.mgid,
      sku: '${src.sku}-TR',
      name: src.name,
      localAlias: src.localAlias,
      nameI18n: src.nameI18n,
      baseUnit: src.baseUnit,
      units: src.units
          .map((u) => ItemUnit(
                id: MizanUuidV7.next(),
                itemId: copyId,
                name: u.name,
                factorToBase: u.factorToBase,
                barcode: u.barcode,
                salePrice: u.salePrice,
              ))
          .toList(),
      warehouse: targetWarehouse,
      binLocation: src.binLocation,
      barcode: src.barcode,
      costPrice: src.costPrice,
      salePrice: src.salePrice,
      wholesalePrice: src.wholesalePrice,
      marketPrice: src.marketPrice,
      stockQty: qtyBase,
      minStock: src.minStock,
    );
    await upsertItem(transferred);
  }

  Future<void> applyStocktake({required String itemId, required double actualBaseQty}) async {
    final db = await MizanDatabase.instance();
    final item = items.firstWhere((i) => i.id == itemId);
    final diff = actualBaseQty - item.stockQty;
    await db.update('items', {'stock_qty': actualBaseQty}, where: 'id = ?', whereArgs: [itemId]);
    if (diff.abs() > 0.001) {
      final val = diff.abs() * item.costPrice;
      if (val > 0) {
        await postCompoundJournal(
          description: 'تسوية جرد مخزني للصنف ${item.name} (فرق ${diff.toStringAsFixed(2)} ${item.baseUnit})',
          category: 'STOCKTAKE',
          lines: diff > 0
              ? [
                  JournalLine(id: MizanUuidV7.next(), headerId: '', accountId: 'acc-inv', accountName: 'المخزون السلعي', debit: val, credit: 0, currency: bookCurrency),
                  JournalLine(id: MizanUuidV7.next(), headerId: '', accountId: 'acc-rev', accountName: 'إيرادات المبيعات والخدمات', debit: 0, credit: val, currency: bookCurrency),
                ]
              : [
                  JournalLine(id: MizanUuidV7.next(), headerId: '', accountId: 'acc-exp', accountName: 'مصروفات تشغيلية وإهلاك', debit: val, credit: 0, currency: bookCurrency),
                  JournalLine(id: MizanUuidV7.next(), headerId: '', accountId: 'acc-inv', accountName: 'المخزون السلعي', debit: 0, credit: val, currency: bookCurrency),
                ],
        );
      }
    }
    await _reloadRelationalTables(db);
    notifyListeners();
  }

  Future<int> importItemsFromDryRun(List<Map<String, String>> rows) async {
    int count = 0;
    for (final r in rows) {
      final name = r['Name'] ?? r['الاسم'] ?? r.values.first;
      if (name.trim().isEmpty) continue;
      final baseUnit = r['BaseUnit'] ?? r['الوحدة'] ?? 'حبة';
      final id = MizanUuidV7.next();
      final sku = r['SKU'] ?? 'IMP-${1000 + count}';
      final mgid = (r['MGID'] != null && r['MGID']!.startsWith('MGID-'))
          ? r['MGID']!
          : MizanSha256.generateMgid('IMP', name, baseUnit);
      final cost = double.tryParse(r['CostPrice'] ?? r['التكلفة'] ?? '0') ?? 0;
      final sale = double.tryParse(r['SalePrice'] ?? r['السعر'] ?? '0') ?? 0;
      final qty = double.tryParse(r['StockQty'] ?? r['الكمية'] ?? '0') ?? 0;
      await upsertItem(MizanItem(
        id: id,
        mgid: mgid,
        sku: sku,
        name: name,
        baseUnit: baseUnit,
        units: [ItemUnit(id: MizanUuidV7.next(), itemId: id, name: baseUnit, factorToBase: 1, salePrice: sale, isDefaultSale: true)],
        warehouse: r['Warehouse'] ?? warehouses.first,
        barcode: r['Barcode'] ?? '',
        costPrice: cost,
        salePrice: sale,
        wholesalePrice: sale * 0.9,
        marketPrice: sale * 1.05,
        stockQty: qty,
      ));
      count++;
    }
    return count;
  }

  /// Posts a strictly balanced multi-line compound journal entry and updates account balances.
  Future<String?> postCompoundJournal({
    required String description,
    required String category,
    required List<JournalLine> lines,
    String? sourceDocId,
    String? reversedOfId,
    DateTime? entryDate,
  }) async {
    final dt = entryDate ?? DateTime.now();
    if (fiscalLockDate != null && !dt.isAfter(fiscalLockDate!)) {
      return 'الفترة المالية مقفلة حتى ${fiscalLockDate!.toIso8601String().substring(0, 10)}';
    }
    final totalDr = lines.fold(0.0, (s, l) => s + l.debitBook);
    final totalCr = lines.fold(0.0, (s, l) => s + l.creditBook);
    if (lines.length < 2 || (totalDr - totalCr).abs() > 0.01 || totalDr <= 0) {
      return 'القيد غير متوازن (مدين ${totalDr.toStringAsFixed(2)} ≠ دائن ${totalCr.toStringAsFixed(2)})';
    }

    final db = await MizanDatabase.instance();
    final headerId = MizanUuidV7.next();
    final refNo = 'JV-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
    final prevHash = journals.isNotEmpty ? journals.first.sha256Hash : 'GENESIS_MIZAN_V33_IFRS';
    final hash = MizanSha256.digestHex('$prevHash|$headerId|$refNo|$totalDr|$totalCr|$description');

    final header = JournalHeader(
      id: headerId,
      refNo: refNo,
      entryDate: dt,
      branchName: currentBranch,
      description: description,
      category: category,
      sourceDocId: sourceDocId,
      reversedOfId: reversedOfId,
      sha256Hash: hash,
      lines: lines
          .map((l) => JournalLine(
                id: MizanUuidV7.next(),
                headerId: headerId,
                accountId: l.accountId,
                accountName: l.accountName,
                debit: l.debit,
                credit: l.credit,
                currency: l.currency,
                fxRate: l.fxRate,
                costCenter: l.costCenter,
                memo: l.memo,
              ))
          .toList(),
    );

    await db.transaction((txn) async {
      await txn.insert('journal_headers', header.toMap());
      for (final l in header.lines) {
        await txn.insert('journal_lines', l.toMap());
        await txn.rawUpdate(
          'UPDATE accounts SET balance = balance + ? WHERE id = ?',
          [l.debitBook - l.creditBook, l.accountId],
        );
      }
    });

    await MizanDatabase.logAuditEvent(
      entityName: entityName,
      branchName: currentBranch,
      action: category,
      refNo: refNo,
      sha256Hash: hash,
    );
    await _queueOutbox(db, 'journal', header.toMap());
    await _reloadRelationalTables(db);
    notifyListeners();
    return null;
  }

  /// Non-deletable reversing entry: flips every debit/credit line of an existing journal.
  Future<String?> reverseJournal(String headerId) async {
    final orig = journals.firstWhere((j) => j.id == headerId);
    final flipped = orig.lines
        .map((l) => JournalLine(
              id: MizanUuidV7.next(),
              headerId: '',
              accountId: l.accountId,
              accountName: l.accountName,
              debit: l.credit,
              credit: l.debit,
              currency: l.currency,
              fxRate: l.fxRate,
              costCenter: l.costCenter,
              memo: 'عكس: ${l.memo}',
            ))
        .toList();
    return postCompoundJournal(
      description: 'قيد عكسي لمرجع ${orig.refNo} — ${orig.description}',
      category: 'REVERSAL',
      reversedOfId: orig.id,
      lines: flipped,
    );
  }

  /// Unified Operational Document Posting Engine across all 5+1 Sector Cycles.
  Future<String?> postOperationalDocument(MizanDocument doc) async {
    if (fiscalLockDate != null && !doc.docDate.isAfter(fiscalLockDate!)) {
      return 'الفترة المالية مقفلة حتى ${fiscalLockDate!.toIso8601String().substring(0, 10)}';
    }
    final db = await MizanDatabase.instance();
    await db.transaction((txn) async {
      await txn.insert('documents', doc.toMap());
      for (final l in doc.lines) {
        await txn.insert('document_lines', l.toMap());
        final isOut = doc.docType == DocumentType.saleInvoice ||
            doc.docType == DocumentType.purchaseReturn ||
            doc.docType == DocumentType.waterRouteDispatch ||
            doc.docType == DocumentType.manufacturingOrder;
        final isIn = doc.docType == DocumentType.purchaseInvoice ||
            doc.docType == DocumentType.saleReturn;
        if (isOut) {
          await txn.rawUpdate(
            'UPDATE items SET stock_qty = stock_qty - ? WHERE id = ? AND is_service = 0',
            [l.baseQty, l.itemId],
          );
        } else if (isIn) {
          await txn.rawUpdate(
            'UPDATE items SET stock_qty = stock_qty + ? WHERE id = ? AND is_service = 0',
            [l.baseQty, l.itemId],
          );
        }
      }
    });

    // Build balanced compound journal lines
    final partyId = doc.partyId.isEmpty ? 'acc-walkin' : doc.partyId;
    final partyName = doc.partyName.isEmpty ? 'عميل نقدي مباشر' : doc.partyName;
    final cashId = doc.cashboxId.isEmpty ? 'acc-cash' : doc.cashboxId;
    final taxAmt = doc.subtotal * (doc.taxPercent / 100.0);
    final retentionAmt = doc.subtotal * (doc.retentionPercent / 100.0);
    final netRevenue = doc.totalAmount - taxAmt;
    final unpaid = (doc.totalAmount - doc.paidAmount - retentionAmt).clamp(0.0, doc.totalAmount);

    final List<JournalLine> jLines = [];
    final isPurchase = doc.docType == DocumentType.purchaseInvoice || doc.docType == DocumentType.saleReturn;

    if (!isPurchase) {
      if (doc.paidAmount > 0) {
        jLines.add(JournalLine(id: '', headerId: '', accountId: cashId, accountName: 'الصندوق الرئيسي', debit: doc.paidAmount, credit: 0, currency: doc.currency, fxRate: doc.fxRate, costCenter: doc.costCenter));
      }
      if (unpaid > 0) {
        jLines.add(JournalLine(id: '', headerId: '', accountId: partyId, accountName: partyName, debit: unpaid, credit: 0, currency: doc.currency, fxRate: doc.fxRate, costCenter: doc.costCenter));
      }
      if (retentionAmt > 0) {
        jLines.add(JournalLine(id: '', headerId: '', accountId: 'acc-ret', accountName: 'تأمينات ومحتجزات المقاولات', debit: retentionAmt, credit: 0, currency: doc.currency, fxRate: doc.fxRate, costCenter: doc.costCenter));
      }
      jLines.add(JournalLine(id: '', headerId: '', accountId: 'acc-rev', accountName: 'إيرادات المبيعات والخدمات', debit: 0, credit: netRevenue, currency: doc.currency, fxRate: doc.fxRate, costCenter: doc.costCenter));
      if (taxAmt > 0) {
        jLines.add(JournalLine(id: '', headerId: '', accountId: 'acc-vat', accountName: 'ضريبة القيمة المضافة المستحقة', debit: 0, credit: taxAmt, currency: doc.currency, fxRate: doc.fxRate, costCenter: doc.costCenter));
      }
    } else {
      jLines.add(JournalLine(id: '', headerId: '', accountId: 'acc-inv', accountName: 'المخزون السلعي', debit: doc.totalAmount, credit: 0, currency: doc.currency, fxRate: doc.fxRate, costCenter: doc.costCenter));
      if (doc.paidAmount > 0) {
        jLines.add(JournalLine(id: '', headerId: '', accountId: cashId, accountName: 'الصندوق الرئيسي', debit: 0, credit: doc.paidAmount, currency: doc.currency, fxRate: doc.fxRate, costCenter: doc.costCenter));
      }
      if (unpaid > 0) {
        jLines.add(JournalLine(id: '', headerId: '', accountId: partyId, accountName: partyName, debit: 0, credit: unpaid, currency: doc.currency, fxRate: doc.fxRate, costCenter: doc.costCenter));
      }
    }

    final err = await postCompoundJournal(
      description: '${doc.docNo} (${doc.sectorCycle.name}) — $partyName',
      category: doc.docType.name.toUpperCase(),
      sourceDocId: doc.id,
      entryDate: doc.docDate,
      lines: jLines,
    );
    await _queueOutbox(db, 'document', doc.toMap());
    return err;
  }

  Future<void> addFxRate(FxRateRecord rate) async {
    final db = await MizanDatabase.instance();
    await db.insert('fx_rates', rate.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await _reloadRelationalTables(db);
    notifyListeners();
  }

  /// IAS 21 Automated Foreign Currency Revaluation Posting.
  Future<String?> postFxRevaluation({
    required String accountId,
    required double revaluationDiffBook,
  }) async {
    if (revaluationDiffBook.abs() < 0.01) return 'لا يوجد فرق تقييم للترحيل.';
    final acc = accounts.firstWhere((a) => a.id == accountId);
    final absVal = revaluationDiffBook.abs();
    return postCompoundJournal(
      description: 'إعادة تقييم فروق صرف IAS 21 لحساب ${acc.name}',
      category: 'FX_IAS21',
      lines: revaluationDiffBook > 0
          ? [
              JournalLine(id: '', headerId: '', accountId: acc.id, accountName: acc.name, debit: absVal, credit: 0, currency: bookCurrency),
              JournalLine(id: '', headerId: '', accountId: 'acc-fx', accountName: 'أرباح وخسائر فروق العملة (IAS 21)', debit: 0, credit: absVal, currency: bookCurrency),
            ]
          : [
              JournalLine(id: '', headerId: '', accountId: 'acc-fx', accountName: 'أرباح وخسائر فروق العملة (IAS 21)', debit: absVal, credit: 0, currency: bookCurrency),
              JournalLine(id: '', headerId: '', accountId: acc.id, accountName: acc.name, debit: 0, credit: absVal, currency: bookCurrency),
            ],
    );
  }

  Future<void> addFixedAsset(FixedAsset asset) async {
    final db = await MizanDatabase.instance();
    await db.insert('fixed_assets', asset.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await _reloadRelationalTables(db);
    notifyListeners();
  }

  Future<String?> runMonthlyDepreciation(String assetId) async {
    final asset = fixedAssets.firstWhere((a) => a.id == assetId);
    final dep = asset.monthlyDepreciation;
    if (dep <= 0 || asset.netBookValue <= asset.salvageValue) return 'الأصل مهلك بالكامل.';
    final db = await MizanDatabase.instance();
    await db.update(
      'fixed_assets',
      {'accumulated_depreciation': asset.accumulatedDepreciation + dep},
      where: 'id = ?',
      whereArgs: [assetId],
    );
    return postCompoundJournal(
      description: 'قسط إهلاك شهري للأصل الثابت: ${asset.name}',
      category: 'DEPRECIATION',
      lines: [
        JournalLine(id: '', headerId: '', accountId: 'acc-exp', accountName: 'مصروفات تشغيلية وإهلاك', debit: dep, credit: 0, currency: bookCurrency),
        JournalLine(id: '', headerId: '', accountId: 'acc-fa', accountName: 'الأصول الثابتة والمعدات', debit: 0, credit: dep, currency: bookCurrency),
      ],
    );
  }

  Future<void> addBudget(BudgetLine budget) async {
    final db = await MizanDatabase.instance();
    await db.insert('budgets', budget.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await _reloadRelationalTables(db);
    notifyListeners();
  }

  Future<void> addCustomDoor(CustomDoorSchema door) async {
    final db = await MizanDatabase.instance();
    await db.insert('custom_schemas', door.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await MizanDatabase.saveEffectiveSetting('custom_door_${door.id}', door.title);
    await _reloadRelationalTables(db);
    notifyListeners();
  }

  Future<void> applyCountryPack(CountrySectorPack pack) async {
    countryPackCode = pack.code;
    bookCurrency = pack.defaultCurrency;
    defaultVatPercent = pack.defaultVatPercent;
    await MizanDatabase.saveEffectiveSetting('country_pack', pack.code);
    await MizanDatabase.saveEffectiveSetting('book_currency', pack.defaultCurrency);
    await MizanDatabase.saveEffectiveSetting('vat_percent', pack.defaultVatPercent.toString());
    await _savePrefs();
    notifyListeners();
  }

  Future<void> addPairedGate(PairedGate gate) async {
    final db = await MizanDatabase.instance();
    await db.insert('paired_gates', gate.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await _queueOutbox(db, 'paired_gate', gate.toMap());
    await _reloadRelationalTables(db);
    notifyListeners();
  }

  Future<void> publishToStorefront({
    required MizanItem item,
    required double publicPrice,
    required String visibility,
  }) async {
    final db = await MizanDatabase.instance();
    final listing = StorefrontListing(
      id: MizanUuidV7.next(),
      itemId: item.id,
      mgid: item.mgid,
      publicTitle: item.name,
      publicPrice: publicPrice,
      currency: bookCurrency,
      visibility: visibility,
    );
    await db.insert('storefront_listings', listing.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    await _reloadRelationalTables(db);
    notifyListeners();
  }

  Future<void> receiveStorefrontOrder({
    required StorefrontListing listing,
    required String buyerName,
    required double qty,
  }) async {
    final db = await MizanDatabase.instance();
    final ord = StorefrontOrder(
      id: MizanUuidV7.next(),
      buyerName: buyerName,
      listingId: listing.id,
      itemId: listing.itemId,
      itemTitle: listing.publicTitle,
      qty: qty,
      unitPrice: listing.publicPrice,
      currency: listing.currency,
      status: 'PENDING_APPROVAL',
      createdAt: DateTime.now(),
    );
    await db.insert('storefront_orders', ord.toMap());
    await _reloadRelationalTables(db);
    notifyListeners();
  }

  /// Domain 9: Approves an isolated storefront order and posts it to the ledger.
  Future<String?> approveStorefrontOrder(String orderId) async {
    final ord = storefrontOrders.firstWhere((o) => o.id == orderId);
    final total = ord.qty * ord.unitPrice;
    final doc = MizanDocument(
      id: MizanUuidV7.next(),
      docNo: 'SF-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      docType: DocumentType.saleInvoice,
      sectorCycle: SectorCycle.trade,
      docDate: DateTime.now(),
      branchName: currentBranch,
      warehouse: warehouses.first,
      partyId: 'acc-walkin',
      partyName: ord.buyerName,
      cashboxId: 'acc-cash',
      paymentTerm: PaymentTerm.cash,
      currency: ord.currency,
      fxRate: fxRateFor(ord.currency),
      subtotal: total,
      totalAmount: total,
      paidAmount: total,
      note: 'طلب معتمد من الصفحة التجارية',
      lines: [
        DocumentLine(
          id: MizanUuidV7.next(),
          documentId: '',
          itemId: ord.itemId,
          itemName: ord.itemTitle,
          unitName: 'وحدة',
          qty: ord.qty,
          unitPrice: ord.unitPrice,
        ),
      ],
    );
    final err = await postOperationalDocument(doc);
    if (err == null) {
      final db = await MizanDatabase.instance();
      await db.update('storefront_orders', {'status': 'APPROVED_POSTED'}, where: 'id = ?', whereArgs: [orderId]);
      await _reloadRelationalTables(db);
      notifyListeners();
    }
    return err;
  }

  /// Domain 10: Controlled Viral MGID Propagation with Strict Cost Isolation & Local Alias.
  Future<String> propagateMgidPayload(String jsonPayload, {String localAlias = ''}) async {
    try {
      final m = jsonDecode(jsonPayload) as Map<String, dynamic>;
      final mgid = m['mgid'] as String;
      final existing = items.where((i) => i.mgid == mgid).toList();
      if (existing.isNotEmpty) {
        return 'الصنف المعرّف بـ $mgid موجود مسبقاً (تم منع التكرار تلقائياً).';
      }
      final newId = MizanUuidV7.next();
      final unitsRaw = (m['units'] as List? ?? []);
      final units = unitsRaw.isEmpty
          ? [ItemUnit(id: MizanUuidV7.next(), itemId: newId, name: m['base_unit']?.toString() ?? 'حبة', factorToBase: 1)]
          : unitsRaw
              .map((u) => ItemUnit(
                    id: MizanUuidV7.next(),
                    itemId: newId,
                    name: u['name'].toString(),
                    factorToBase: (u['factor_to_base'] as num).toDouble(),
                    barcode: u['barcode']?.toString() ?? '',
                  ))
              .toList();
      await upsertItem(MizanItem(
        id: newId,
        mgid: mgid,
        sku: 'MGID-${mgid.substring(mgid.length - 5)}',
        name: m['canonical_name'].toString(),
        localAlias: localAlias,
        isService: m['is_service'] == true,
        baseUnit: m['base_unit']?.toString() ?? 'حبة',
        units: units,
        warehouse: warehouses.first,
        barcode: m['barcode']?.toString() ?? '',
        costPrice: 0.0, // Cost strictly isolated!
        salePrice: 0.0,
        wholesalePrice: 0.0,
        marketPrice: 0.0,
        stockQty: 0.0,
      ));
      return 'تم استلام ونشر الصنف $mgid بنجاح مع عزل كامل للتكاليف الخاصة.';
    } catch (e) {
      return 'تعذر قراءة حزمة MGID: $e';
    }
  }

  /// Network Layer: Multi-Party Netting / Clearing (3+ parties with mutual consent).
  Future<String?> executeMultiPartyNetting({
    required String partyAId,
    required String partyBId,
    required String partyCId,
    required double amount,
  }) async {
    if (amount <= 0) return 'أدخل مبلغ مقاصة صحيحاً.';
    final a = accounts.firstWhere((x) => x.id == partyAId);
    final b = accounts.firstWhere((x) => x.id == partyBId);
    final c = accounts.firstWhere((x) => x.id == partyCId);
    return postCompoundJournal(
      description: 'مقاصة ثلاثية بموافقة الأطراف: ${a.name} ↔ ${b.name} ↔ ${c.name}',
      category: 'MULTI_PARTY_NETTING',
      lines: [
        JournalLine(id: '', headerId: '', accountId: b.id, accountName: b.name, debit: amount, credit: 0, currency: bookCurrency, memo: 'تسوية مقاصة ثلاثية'),
        JournalLine(id: '', headerId: '', accountId: a.id, accountName: a.name, debit: 0, credit: amount, currency: bookCurrency, memo: 'تسوية مقاصة ثلاثية'),
        JournalLine(id: '', headerId: '', accountId: c.id, accountName: c.name, debit: amount, credit: 0, currency: bookCurrency, memo: 'إغلاق حلقة المقاصة'),
        JournalLine(id: '', headerId: '', accountId: b.id, accountName: b.name, debit: 0, credit: amount, currency: bookCurrency, memo: 'إغلاق حلقة المقاصة'),
      ],
    );
  }

  Future<void> _queueOutbox(Database db, String type, Map<String, dynamic> payload) async {
    final id = MizanUuidV7.next();
    await db.insert(
      'sync_outbox',
      SyncOutboxItem(
        id: id,
        idempotencyKey: 'IDEMP-$type-$id',
        entityType: type,
        payloadJson: jsonEncode(payload),
        createdAt: DateTime.now(),
      ).toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<void> markOutboxSyncedDemo() async {
    final db = await MizanDatabase.instance();
    await db.update('sync_outbox', {'status': 'SYNCED'}, where: "status = 'PENDING'");
    await _reloadRelationalTables(db);
    notifyListeners();
  }
}
