import 'dart:convert';

enum WorkspaceMode { easy, standard, professional, executive, expressField }

enum AccountType {
  asset,
  liability,
  equity,
  revenue,
  expense,
  customer,
  supplier,
  cashbox,
  bank,
  employee,
}

enum SectorCycle {
  trade,
  services,
  contracting,
  manufacturing,
  subscriptions,
  waterDistribution,
}

enum DocumentType {
  saleInvoice,
  purchaseInvoice,
  saleReturn,
  purchaseReturn,
  serviceQuote,
  serviceInvoice,
  contractCertificate,
  manufacturingOrder,
  subscriptionBilling,
  waterRouteDispatch,
  receiptVoucher,
  paymentVoucher,
  transferVoucher,
  compoundJournal,
}

enum PaymentTerm { cash, credit, partial, gateway }

enum ApprovalStatus { draft, pendingApproval, posted, reversed }

class ItemUnit {
  final String id;
  final String itemId;
  final String name;
  final double factorToBase; // e.g., Piece=1, Pack=6, Carton=24
  final String barcode;
  final double salePrice;
  final bool isDefaultSale;
  final bool isDefaultPurchase;

  ItemUnit({
    required this.id,
    required this.itemId,
    required this.name,
    required this.factorToBase,
    this.barcode = '',
    this.salePrice = 0.0,
    this.isDefaultSale = false,
    this.isDefaultPurchase = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'item_id': itemId,
        'name': name,
        'factor_to_base': factorToBase,
        'barcode': barcode,
        'sale_price': salePrice,
        'is_default_sale': isDefaultSale ? 1 : 0,
        'is_default_purchase': isDefaultPurchase ? 1 : 0,
      };

  factory ItemUnit.fromMap(Map<String, dynamic> m) => ItemUnit(
        id: m['id'] as String,
        itemId: m['item_id'] as String,
        name: m['name'] as String,
        factorToBase: (m['factor_to_base'] as num).toDouble(),
        barcode: m['barcode'] as String? ?? '',
        salePrice: (m['sale_price'] as num?)?.toDouble() ?? 0.0,
        isDefaultSale: (m['is_default_sale'] as int? ?? 0) == 1,
        isDefaultPurchase: (m['is_default_purchase'] as int? ?? 0) == 1,
      );
}

class MizanAccount {
  final String id;
  final String code;
  final String? parentId;
  final String name;
  final Map<String, String> nameI18n;
  final AccountType type;
  final String currency;
  final String phone;
  final double creditLimit;
  final String defaultWarehouse;
  double balance;

  MizanAccount({
    required this.id,
    required this.code,
    this.parentId,
    required this.name,
    this.nameI18n = const {},
    required this.type,
    this.currency = 'USD',
    this.phone = '',
    this.creditLimit = 0.0,
    this.defaultWarehouse = 'المخزن الرئيسي',
    this.balance = 0.0,
  });

  bool get isOverCreditLimit => creditLimit > 0 && balance > creditLimit;

  Map<String, dynamic> toMap() => {
        'id': id,
        'code': code,
        'parent_id': parentId,
        'name': name,
        'name_i18n': jsonEncode(nameI18n),
        'type': type.name,
        'currency': currency,
        'phone': phone,
        'credit_limit': creditLimit,
        'default_warehouse': defaultWarehouse,
        'balance': balance,
      };

  factory MizanAccount.fromMap(Map<String, dynamic> m) {
    Map<String, String> i18n = {};
    final raw = m['name_i18n'];
    if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      i18n = decoded.map((k, v) => MapEntry(k, v.toString()));
    }
    return MizanAccount(
      id: m['id'] as String,
      code: m['code'] as String,
      parentId: m['parent_id'] as String?,
      name: m['name'] as String,
      nameI18n: i18n,
      type: AccountType.values.firstWhere(
        (e) => e.name == m['type'],
        orElse: () => AccountType.asset,
      ),
      currency: m['currency'] as String? ?? 'USD',
      phone: m['phone'] as String? ?? '',
      creditLimit: (m['credit_limit'] as num?)?.toDouble() ?? 0.0,
      defaultWarehouse: m['default_warehouse'] as String? ?? 'المخزن الرئيسي',
      balance: (m['balance'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class MizanItem {
  final String id;
  final String mgid; // Canonical Mizan Global Item/Service ID
  final String sku;
  final String name;
  final String localAlias;
  final Map<String, String> nameI18n;
  final bool isService;
  final String baseUnit;
  final List<ItemUnit> units;
  final String warehouse;
  final String binLocation;
  final String barcode;
  final String batchNo;
  final String expiryDate;
  final String serialNo;
  final String imagePath;
  double costPrice;
  double salePrice;
  double wholesalePrice;
  double marketPrice;
  double stockQty; // Always tracked in baseUnit
  double minStock;
  double bomWastePercent;
  final List<Map<String, dynamic>> bomComponents;

  MizanItem({
    required this.id,
    required this.mgid,
    required this.sku,
    required this.name,
    this.localAlias = '',
    this.nameI18n = const {},
    this.isService = false,
    required this.baseUnit,
    this.units = const [],
    required this.warehouse,
    this.binLocation = 'A-01',
    this.barcode = '',
    this.batchNo = '',
    this.expiryDate = '',
    this.serialNo = '',
    this.imagePath = '',
    required this.costPrice,
    required this.salePrice,
    required this.wholesalePrice,
    required this.marketPrice,
    required this.stockQty,
    this.minStock = 5,
    this.bomWastePercent = 0.0,
    this.bomComponents = const [],
  });

  double get marginPercent =>
      salePrice > 0 ? ((salePrice - costPrice) / salePrice) * 100 : 0;

  Map<String, dynamic> toPublicMgidPayload() => {
        'mgid': mgid,
        'canonical_name': name,
        'name_i18n': nameI18n,
        'is_service': isService,
        'base_unit': baseUnit,
        'barcode': barcode,
        'units': units
            .map((u) => {
                  'name': u.name,
                  'factor_to_base': u.factorToBase,
                  'barcode': u.barcode,
                })
            .toList(),
        // Private fields (costPrice, margin, stockQty, wholesalePrice) strictly excluded!
      };

  Map<String, dynamic> toMap() => {
        'id': id,
        'mgid': mgid,
        'sku': sku,
        'name': name,
        'local_alias': localAlias,
        'name_i18n': jsonEncode(nameI18n),
        'is_service': isService ? 1 : 0,
        'base_unit': baseUnit,
        'warehouse': warehouse,
        'bin_location': binLocation,
        'barcode': barcode,
        'batch_no': batchNo,
        'expiry_date': expiryDate,
        'serial_no': serialNo,
        'image_path': imagePath,
        'cost_price': costPrice,
        'sale_price': salePrice,
        'wholesale_price': wholesalePrice,
        'market_price': marketPrice,
        'stock_qty': stockQty,
        'min_stock': minStock,
        'bom_waste_percent': bomWastePercent,
        'bom_json': jsonEncode(bomComponents),
      };

  factory MizanItem.fromMap(Map<String, dynamic> m, List<ItemUnit> units) {
    Map<String, String> i18n = {};
    final raw = m['name_i18n'];
    if (raw is String && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      i18n = decoded.map((k, v) => MapEntry(k, v.toString()));
    }
    List<Map<String, dynamic>> bom = [];
    final rawBom = m['bom_json'];
    if (rawBom is String && rawBom.isNotEmpty) {
      bom = (jsonDecode(rawBom) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return MizanItem(
      id: m['id'] as String,
      mgid: m['mgid'] as String? ?? 'MGID-GEN-${m['sku']}',
      sku: m['sku'] as String,
      name: m['name'] as String,
      localAlias: m['local_alias'] as String? ?? '',
      nameI18n: i18n,
      isService: (m['is_service'] as int? ?? 0) == 1,
      baseUnit: m['base_unit'] as String? ?? 'حبة',
      units: units,
      warehouse: m['warehouse'] as String? ?? 'المخزن الرئيسي',
      binLocation: m['bin_location'] as String? ?? 'A-01',
      barcode: m['barcode'] as String? ?? '',
      batchNo: m['batch_no'] as String? ?? '',
      expiryDate: m['expiry_date'] as String? ?? '',
      serialNo: m['serial_no'] as String? ?? '',
      imagePath: m['image_path'] as String? ?? '',
      costPrice: (m['cost_price'] as num?)?.toDouble() ?? 0.0,
      salePrice: (m['sale_price'] as num?)?.toDouble() ?? 0.0,
      wholesalePrice: (m['wholesale_price'] as num?)?.toDouble() ?? 0.0,
      marketPrice: (m['market_price'] as num?)?.toDouble() ?? 0.0,
      stockQty: (m['stock_qty'] as num?)?.toDouble() ?? 0.0,
      minStock: (m['min_stock'] as num?)?.toDouble() ?? 5.0,
      bomWastePercent: (m['bom_waste_percent'] as num?)?.toDouble() ?? 0.0,
      bomComponents: bom,
    );
  }
}

class FxRateRecord {
  final String id;
  final String currencyCode;
  final String currencyName;
  final double rateToBook; // 1 unit of currencyCode = rateToBook in bookCurrency
  final DateTime effectiveFrom;

  FxRateRecord({
    required this.id,
    required this.currencyCode,
    required this.currencyName,
    required this.rateToBook,
    required this.effectiveFrom,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'currency_code': currencyCode,
        'currency_name': currencyName,
        'rate_to_book': rateToBook,
        'effective_from': effectiveFrom.toIso8601String(),
      };

  factory FxRateRecord.fromMap(Map<String, dynamic> m) => FxRateRecord(
        id: m['id'] as String,
        currencyCode: m['currency_code'] as String,
        currencyName: m['currency_name'] as String,
        rateToBook: (m['rate_to_book'] as num).toDouble(),
        effectiveFrom: DateTime.parse(m['effective_from'] as String),
      );
}

class DocumentLine {
  final String id;
  final String documentId;
  final String itemId;
  final String mgid;
  final String itemName;
  final String unitName;
  final double unitFactor;
  final double qty;
  final double unitPrice;
  final double costAtPosting;

  DocumentLine({
    required this.id,
    required this.documentId,
    required this.itemId,
    this.mgid = '',
    required this.itemName,
    required this.unitName,
    this.unitFactor = 1.0,
    required this.qty,
    required this.unitPrice,
    this.costAtPosting = 0.0,
  });

  double get baseQty => qty * unitFactor;
  double get lineTotal => qty * unitPrice;

  Map<String, dynamic> toMap() => {
        'id': id,
        'document_id': documentId,
        'item_id': itemId,
        'mgid': mgid,
        'item_name': itemName,
        'unit_name': unitName,
        'unit_factor': unitFactor,
        'qty': qty,
        'unit_price': unitPrice,
        'cost_at_posting': costAtPosting,
      };

  factory DocumentLine.fromMap(Map<String, dynamic> m) => DocumentLine(
        id: m['id'] as String,
        documentId: m['document_id'] as String,
        itemId: m['item_id'] as String,
        mgid: m['mgid'] as String? ?? '',
        itemName: m['item_name'] as String,
        unitName: m['unit_name'] as String? ?? 'حبة',
        unitFactor: (m['unit_factor'] as num?)?.toDouble() ?? 1.0,
        qty: (m['qty'] as num).toDouble(),
        unitPrice: (m['unit_price'] as num).toDouble(),
        costAtPosting: (m['cost_at_posting'] as num?)?.toDouble() ?? 0.0,
      );
}

class MizanDocument {
  final String id;
  final String docNo;
  final DocumentType docType;
  final SectorCycle sectorCycle;
  final DateTime docDate;
  final String branchName;
  final String costCenter;
  final String warehouse;
  final String partyId;
  final String partyName;
  final String cashboxId;
  final PaymentTerm paymentTerm;
  final String currency;
  final double fxRate; // Locked exchange rate on document
  final double subtotal;
  final double discountPercent;
  final double taxPercent;
  final double shipping;
  final double retentionPercent; // For contracting certificates
  final double totalAmount;
  final double paidAmount;
  final ApprovalStatus status;
  final String note;
  final Map<String, dynamic> customData;
  final List<DocumentLine> lines;

  MizanDocument({
    required this.id,
    required this.docNo,
    required this.docType,
    required this.sectorCycle,
    required this.docDate,
    required this.branchName,
    this.costCenter = 'عام',
    required this.warehouse,
    required this.partyId,
    required this.partyName,
    required this.cashboxId,
    required this.paymentTerm,
    required this.currency,
    this.fxRate = 1.0,
    required this.subtotal,
    this.discountPercent = 0.0,
    this.taxPercent = 0.0,
    this.shipping = 0.0,
    this.retentionPercent = 0.0,
    required this.totalAmount,
    required this.paidAmount,
    this.status = ApprovalStatus.posted,
    this.note = '',
    this.customData = const {},
    this.lines = const [],
  });

  double get totalInBook => totalAmount * fxRate;

  Map<String, dynamic> toMap() => {
        'id': id,
        'doc_no': docNo,
        'doc_type': docType.name,
        'sector_cycle': sectorCycle.name,
        'doc_date': docDate.toIso8601String(),
        'branch_name': branchName,
        'cost_center': costCenter,
        'warehouse': warehouse,
        'party_id': partyId,
        'party_name': partyName,
        'cashbox_id': cashboxId,
        'payment_term': paymentTerm.name,
        'currency': currency,
        'fx_rate': fxRate,
        'subtotal': subtotal,
        'discount_percent': discountPercent,
        'tax_percent': taxPercent,
        'shipping': shipping,
        'retention_percent': retentionPercent,
        'total_amount': totalAmount,
        'paid_amount': paidAmount,
        'status': status.name,
        'note': note,
        'custom_data_json': jsonEncode(customData),
      };

  factory MizanDocument.fromMap(
    Map<String, dynamic> m,
    List<DocumentLine> lines,
  ) {
    Map<String, dynamic> custom = {};
    final raw = m['custom_data_json'];
    if (raw is String && raw.isNotEmpty) {
      custom = Map<String, dynamic>.from(jsonDecode(raw) as Map);
    }
    return MizanDocument(
      id: m['id'] as String,
      docNo: m['doc_no'] as String,
      docType: DocumentType.values.firstWhere(
        (e) => e.name == m['doc_type'],
        orElse: () => DocumentType.saleInvoice,
      ),
      sectorCycle: SectorCycle.values.firstWhere(
        (e) => e.name == m['sector_cycle'],
        orElse: () => SectorCycle.trade,
      ),
      docDate: DateTime.parse(m['doc_date'] as String),
      branchName: m['branch_name'] as String? ?? 'الفرع الرئيسي',
      costCenter: m['cost_center'] as String? ?? 'عام',
      warehouse: m['warehouse'] as String? ?? 'المخزن الرئيسي',
      partyId: m['party_id'] as String? ?? '',
      partyName: m['party_name'] as String? ?? '',
      cashboxId: m['cashbox_id'] as String? ?? '',
      paymentTerm: PaymentTerm.values.firstWhere(
        (e) => e.name == m['payment_term'],
        orElse: () => PaymentTerm.cash,
      ),
      currency: m['currency'] as String? ?? 'USD',
      fxRate: (m['fx_rate'] as num?)?.toDouble() ?? 1.0,
      subtotal: (m['subtotal'] as num?)?.toDouble() ?? 0.0,
      discountPercent: (m['discount_percent'] as num?)?.toDouble() ?? 0.0,
      taxPercent: (m['tax_percent'] as num?)?.toDouble() ?? 0.0,
      shipping: (m['shipping'] as num?)?.toDouble() ?? 0.0,
      retentionPercent: (m['retention_percent'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (m['total_amount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (m['paid_amount'] as num?)?.toDouble() ?? 0.0,
      status: ApprovalStatus.values.firstWhere(
        (e) => e.name == m['status'],
        orElse: () => ApprovalStatus.posted,
      ),
      note: m['note'] as String? ?? '',
      customData: custom,
      lines: lines,
    );
  }
}

class JournalLine {
  final String id;
  final String headerId;
  final String accountId;
  final String accountName;
  final double debit;
  final double credit;
  final String currency;
  final double fxRate;
  final String costCenter;
  final String memo;

  JournalLine({
    required this.id,
    required this.headerId,
    required this.accountId,
    required this.accountName,
    required this.debit,
    required this.credit,
    this.currency = 'USD',
    this.fxRate = 1.0,
    this.costCenter = 'عام',
    this.memo = '',
  });

  double get debitBook => debit * fxRate;
  double get creditBook => credit * fxRate;

  Map<String, dynamic> toMap() => {
        'id': id,
        'header_id': headerId,
        'account_id': accountId,
        'account_name': accountName,
        'debit': debit,
        'credit': credit,
        'currency': currency,
        'fx_rate': fxRate,
        'cost_center': costCenter,
        'memo': memo,
      };

  factory JournalLine.fromMap(Map<String, dynamic> m) => JournalLine(
        id: m['id'] as String,
        headerId: m['header_id'] as String,
        accountId: m['account_id'] as String,
        accountName: m['account_name'] as String,
        debit: (m['debit'] as num).toDouble(),
        credit: (m['credit'] as num).toDouble(),
        currency: m['currency'] as String? ?? 'USD',
        fxRate: (m['fx_rate'] as num?)?.toDouble() ?? 1.0,
        costCenter: m['cost_center'] as String? ?? 'عام',
        memo: m['memo'] as String? ?? '',
      );
}

class JournalHeader {
  final String id;
  final String refNo;
  final DateTime entryDate;
  final String branchName;
  final String description;
  final String category;
  final String? sourceDocId;
  final String? reversedOfId;
  final String sha256Hash;
  final ApprovalStatus status;
  final List<JournalLine> lines;

  JournalHeader({
    required this.id,
    required this.refNo,
    required this.entryDate,
    required this.branchName,
    required this.description,
    required this.category,
    this.sourceDocId,
    this.reversedOfId,
    required this.sha256Hash,
    this.status = ApprovalStatus.posted,
    required this.lines,
  });

  double get totalDebit => lines.fold(0.0, (s, l) => s + l.debitBook);
  double get totalCredit => lines.fold(0.0, (s, l) => s + l.creditBook);
  bool get isBalanced => (totalDebit - totalCredit).abs() < 0.005;

  Map<String, dynamic> toMap() => {
        'id': id,
        'ref_no': refNo,
        'entry_date': entryDate.toIso8601String(),
        'branch_name': branchName,
        'description': description,
        'category': category,
        'source_doc_id': sourceDocId,
        'reversed_of_id': reversedOfId,
        'sha256_hash': sha256Hash,
        'status': status.name,
      };

  factory JournalHeader.fromMap(
    Map<String, dynamic> m,
    List<JournalLine> lines,
  ) =>
      JournalHeader(
        id: m['id'] as String,
        refNo: m['ref_no'] as String,
        entryDate: DateTime.parse(m['entry_date'] as String),
        branchName: m['branch_name'] as String? ?? 'الفرع الرئيسي',
        description: m['description'] as String? ?? '',
        category: m['category'] as String? ?? 'JOURNAL',
        sourceDocId: m['source_doc_id'] as String?,
        reversedOfId: m['reversed_of_id'] as String?,
        sha256Hash: m['sha256_hash'] as String? ?? '',
        status: ApprovalStatus.values.firstWhere(
          (e) => e.name == m['status'],
          orElse: () => ApprovalStatus.posted,
        ),
        lines: lines,
      );
}

class FixedAsset {
  final String id;
  final String name;
  final String accountId;
  final double acquisitionCost;
  final double salvageValue;
  final int usefulLifeMonths;
  final DateTime acquisitionDate;
  double accumulatedDepreciation;

  FixedAsset({
    required this.id,
    required this.name,
    required this.accountId,
    required this.acquisitionCost,
    this.salvageValue = 0.0,
    required this.usefulLifeMonths,
    required this.acquisitionDate,
    this.accumulatedDepreciation = 0.0,
  });

  double get monthlyDepreciation => usefulLifeMonths > 0
      ? (acquisitionCost - salvageValue) / usefulLifeMonths
      : 0.0;

  double get netBookValue => acquisitionCost - accumulatedDepreciation;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'account_id': accountId,
        'acquisition_cost': acquisitionCost,
        'salvage_value': salvageValue,
        'useful_life_months': usefulLifeMonths,
        'acquisition_date': acquisitionDate.toIso8601String(),
        'accumulated_depreciation': accumulatedDepreciation,
      };

  factory FixedAsset.fromMap(Map<String, dynamic> m) => FixedAsset(
        id: m['id'] as String,
        name: m['name'] as String,
        accountId: m['account_id'] as String,
        acquisitionCost: (m['acquisition_cost'] as num).toDouble(),
        salvageValue: (m['salvage_value'] as num?)?.toDouble() ?? 0.0,
        usefulLifeMonths: m['useful_life_months'] as int? ?? 60,
        acquisitionDate: DateTime.parse(m['acquisition_date'] as String),
        accumulatedDepreciation:
            (m['accumulated_depreciation'] as num?)?.toDouble() ?? 0.0,
      );
}

class BudgetLine {
  final String id;
  final String accountId;
  final String accountName;
  final String periodLabel;
  final double plannedAmount;

  BudgetLine({
    required this.id,
    required this.accountId,
    required this.accountName,
    required this.periodLabel,
    required this.plannedAmount,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'account_id': accountId,
        'account_name': accountName,
        'period_label': periodLabel,
        'planned_amount': plannedAmount,
      };

  factory BudgetLine.fromMap(Map<String, dynamic> m) => BudgetLine(
        id: m['id'] as String,
        accountId: m['account_id'] as String,
        accountName: m['account_name'] as String,
        periodLabel: m['period_label'] as String,
        plannedAmount: (m['planned_amount'] as num).toDouble(),
      );
}

class CustomDoorSchema {
  final String id;
  final String title;
  final String targetRole;
  final bool requiresApproval;
  final bool postsToLedger;
  final String debitAccountId;
  final String creditAccountId;
  final List<Map<String, String>> fields; // [{name, type}]

  CustomDoorSchema({
    required this.id,
    required this.title,
    this.targetRole = 'ALL',
    this.requiresApproval = false,
    this.postsToLedger = false,
    this.debitAccountId = '',
    this.creditAccountId = '',
    required this.fields,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'target_role': targetRole,
        'requires_approval': requiresApproval ? 1 : 0,
        'posts_to_ledger': postsToLedger ? 1 : 0,
        'debit_account_id': debitAccountId,
        'credit_account_id': creditAccountId,
        'fields_json': jsonEncode(fields),
      };

  factory CustomDoorSchema.fromMap(Map<String, dynamic> m) {
    final decoded = (jsonDecode(m['fields_json'] as String) as List)
        .map((e) => Map<String, String>.from(e as Map))
        .toList();
    return CustomDoorSchema(
      id: m['id'] as String,
      title: m['title'] as String,
      targetRole: m['target_role'] as String? ?? 'ALL',
      requiresApproval: (m['requires_approval'] as int? ?? 0) == 1,
      postsToLedger: (m['posts_to_ledger'] as int? ?? 0) == 1,
      debitAccountId: m['debit_account_id'] as String? ?? '',
      creditAccountId: m['credit_account_id'] as String? ?? '',
      fields: decoded,
    );
  }
}

class PairedGate {
  final String id;
  final String gateCode;
  final String partnerName;
  final String gateType;
  final List<String> allowedDocTypes;
  final bool allowMgidPropagation;
  final bool isolateCosts;
  final String status;

  PairedGate({
    required this.id,
    required this.gateCode,
    required this.partnerName,
    required this.gateType,
    this.allowedDocTypes = const ['saleInvoice', 'purchaseInvoice', 'rfq'],
    this.allowMgidPropagation = true,
    this.isolateCosts = true,
    this.status = 'PAIRED',
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'gate_code': gateCode,
        'partner_name': partnerName,
        'gate_type': gateType,
        'allowed_docs_json': jsonEncode(allowedDocTypes),
        'allow_mgid': allowMgidPropagation ? 1 : 0,
        'isolate_costs': isolateCosts ? 1 : 0,
        'status': status,
      };

  factory PairedGate.fromMap(Map<String, dynamic> m) => PairedGate(
        id: m['id'] as String,
        gateCode: m['gate_code'] as String,
        partnerName: m['partner_name'] as String,
        gateType: m['gate_type'] as String,
        allowedDocTypes:
            List<String>.from(jsonDecode(m['allowed_docs_json'] as String) as List),
        allowMgidPropagation: (m['allow_mgid'] as int? ?? 1) == 1,
        isolateCosts: (m['isolate_costs'] as int? ?? 1) == 1,
        status: m['status'] as String? ?? 'PAIRED',
      );
}

class StorefrontListing {
  final String id;
  final String itemId;
  final String mgid;
  final String publicTitle;
  final double publicPrice;
  final String currency;
  final String visibility; // PUBLIC, PAIRED_ONLY
  final bool isActive;

  StorefrontListing({
    required this.id,
    required this.itemId,
    required this.mgid,
    required this.publicTitle,
    required this.publicPrice,
    required this.currency,
    this.visibility = 'PUBLIC',
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'item_id': itemId,
        'mgid': mgid,
        'public_title': publicTitle,
        'public_price': publicPrice,
        'currency': currency,
        'visibility': visibility,
        'is_active': isActive ? 1 : 0,
      };

  factory StorefrontListing.fromMap(Map<String, dynamic> m) =>
      StorefrontListing(
        id: m['id'] as String,
        itemId: m['item_id'] as String,
        mgid: m['mgid'] as String,
        publicTitle: m['public_title'] as String,
        publicPrice: (m['public_price'] as num).toDouble(),
        currency: m['currency'] as String? ?? 'USD',
        visibility: m['visibility'] as String? ?? 'PUBLIC',
        isActive: (m['is_active'] as int? ?? 1) == 1,
      );
}

class StorefrontOrder {
  final String id;
  final String buyerName;
  final String listingId;
  final String itemId;
  final String itemTitle;
  final double qty;
  final double unitPrice;
  final String currency;
  final String status; // PENDING_APPROVAL, APPROVED_POSTED, REJECTED
  final DateTime createdAt;

  StorefrontOrder({
    required this.id,
    required this.buyerName,
    required this.listingId,
    required this.itemId,
    required this.itemTitle,
    required this.qty,
    required this.unitPrice,
    required this.currency,
    this.status = 'PENDING_APPROVAL',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'buyer_name': buyerName,
        'listing_id': listingId,
        'item_id': itemId,
        'item_title': itemTitle,
        'qty': qty,
        'unit_price': unitPrice,
        'currency': currency,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };

  factory StorefrontOrder.fromMap(Map<String, dynamic> m) => StorefrontOrder(
        id: m['id'] as String,
        buyerName: m['buyer_name'] as String,
        listingId: m['listing_id'] as String,
        itemId: m['item_id'] as String,
        itemTitle: m['item_title'] as String,
        qty: (m['qty'] as num).toDouble(),
        unitPrice: (m['unit_price'] as num).toDouble(),
        currency: m['currency'] as String? ?? 'USD',
        status: m['status'] as String? ?? 'PENDING_APPROVAL',
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class SyncOutboxItem {
  final String id;
  final String idempotencyKey;
  final String entityType;
  final String payloadJson;
  final String status; // PENDING, SYNCED
  final DateTime createdAt;

  SyncOutboxItem({
    required this.id,
    required this.idempotencyKey,
    required this.entityType,
    required this.payloadJson,
    this.status = 'PENDING',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'idempotency_key': idempotencyKey,
        'entity_type': entityType,
        'payload_json': payloadJson,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };

  factory SyncOutboxItem.fromMap(Map<String, dynamic> m) => SyncOutboxItem(
        id: m['id'] as String,
        idempotencyKey: m['idempotency_key'] as String,
        entityType: m['entity_type'] as String,
        payloadJson: m['payload_json'] as String,
        status: m['status'] as String? ?? 'PENDING',
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class CountrySectorPack {
  final String code;
  final String nameAr;
  final String nameEn;
  final String defaultCurrency;
  final double defaultVatPercent;
  final String fiscalYearStart;
  final String complianceScope;

  const CountrySectorPack({
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.defaultCurrency,
    required this.defaultVatPercent,
    required this.fiscalYearStart,
    required this.complianceScope,
  });

  static const List<CountrySectorPack> builtIn = [
    CountrySectorPack(
      code: 'YE',
      nameAr: 'اليمن — تجارة وتوزيع ومياه',
      nameEn: 'Yemen — Trade & Distribution',
      defaultCurrency: 'YER',
      defaultVatPercent: 5.0,
      fiscalYearStart: '01-01',
      complianceScope: 'Multi-currency YER/SAR/USD + Field Water Distribution',
    ),
    CountrySectorPack(
      code: 'SA',
      nameAr: 'السعودية — حزمة ضريبة القيمة المضافة 15%',
      nameEn: 'Saudi Arabia — VAT 15% Pack',
      defaultCurrency: 'SAR',
      defaultVatPercent: 15.0,
      fiscalYearStart: '01-01',
      complianceScope: 'VAT 15% + QR TLV Invoice Fields Ready',
    ),
    CountrySectorPack(
      code: 'AE',
      nameAr: 'الإمارات — ضريبة 5% ومتعدد الفروع',
      nameEn: 'UAE — VAT 5% Multi-Branch',
      defaultCurrency: 'AED',
      defaultVatPercent: 5.0,
      fiscalYearStart: '01-01',
      complianceScope: 'FTA VAT 5% + Multi-Entity Reporting',
    ),
    CountrySectorPack(
      code: 'EG',
      nameAr: 'مصر — ضريبة 14% والمقاولات',
      nameEn: 'Egypt — VAT 14% & Contracting',
      defaultCurrency: 'EGP',
      defaultVatPercent: 14.0,
      fiscalYearStart: '01-01',
      complianceScope: 'VAT 14% + Contracting Certificates & Retention',
    ),
    CountrySectorPack(
      code: 'GL',
      nameAr: 'عالمي — معيار IFRS الحر (0%)',
      nameEn: 'Global — Open IFRS Standard (0%)',
      defaultCurrency: 'USD',
      defaultVatPercent: 0.0,
      fiscalYearStart: '01-01',
      complianceScope: 'IFRS / IAS 1 / IAS 21 Multi-Currency Standard',
    ),
  ];
}
