enum WorkspaceMode { easy, standard, professional, executive, expressField }

enum AccountType { customer, supplier, cashbox, employee, expense, asset }

enum InvoiceType { sale, purchase, saleReturn, purchaseReturn }

enum PaymentTerm { cash, credit, partial, gateway }

enum VoucherType { receipt, payment, transfer, journal }

class MizanAccount {
  final String id;
  final String code;
  final String name;
  final AccountType type;
  final String currency;
  final String phone;
  double balance; // Positive = Debit (asset/receivable), Negative = Credit (payable)

  MizanAccount({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    this.currency = 'USD',
    this.phone = '',
    this.balance = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'type': type.name,
        'currency': currency,
        'phone': phone,
        'balance': balance,
      };

  factory MizanAccount.fromJson(Map<String, dynamic> j) => MizanAccount(
        id: j['id'] as String,
        code: j['code'] as String? ?? '1000',
        name: j['name'] as String,
        type: AccountType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => AccountType.customer,
        ),
        currency: j['currency'] as String? ?? 'USD',
        phone: j['phone'] as String? ?? '',
        balance: (j['balance'] as num?)?.toDouble() ?? 0.0,
      );
}

class MizanItem {
  final String id;
  final String sku;
  final String name;
  final String unit;
  final String warehouse;
  double costPrice;
  double salePrice;
  double wholesalePrice;
  double marketPrice; // For price comparison
  double stockQty;
  double minStock;
  bool perishable;

  MizanItem({
    required this.id,
    required this.sku,
    required this.name,
    required this.unit,
    required this.warehouse,
    required this.costPrice,
    required this.salePrice,
    required this.wholesalePrice,
    required this.marketPrice,
    required this.stockQty,
    this.minStock = 5,
    this.perishable = false,
  });

  double get marginPercent =>
      salePrice > 0 ? ((salePrice - costPrice) / salePrice) * 100.0 : 0.0;

  double get marketDiff => salePrice - marketPrice;

  Map<String, dynamic> toJson() => {
        'id': id,
        'sku': sku,
        'name': name,
        'unit': unit,
        'warehouse': warehouse,
        'costPrice': costPrice,
        'salePrice': salePrice,
        'wholesalePrice': wholesalePrice,
        'marketPrice': marketPrice,
        'stockQty': stockQty,
        'minStock': minStock,
        'perishable': perishable,
      };

  factory MizanItem.fromJson(Map<String, dynamic> j) => MizanItem(
        id: j['id'] as String,
        sku: j['sku'] as String? ?? '',
        name: j['name'] as String,
        unit: j['unit'] as String? ?? 'حبة',
        warehouse: j['warehouse'] as String? ?? 'المخزن الرئيسي',
        costPrice: (j['costPrice'] as num?)?.toDouble() ?? 0.0,
        salePrice: (j['salePrice'] as num?)?.toDouble() ?? 0.0,
        wholesalePrice: (j['wholesalePrice'] as num?)?.toDouble() ?? 0.0,
        marketPrice: (j['marketPrice'] as num?)?.toDouble() ?? 0.0,
        stockQty: (j['stockQty'] as num?)?.toDouble() ?? 0.0,
        minStock: (j['minStock'] as num?)?.toDouble() ?? 5.0,
        perishable: j['perishable'] as bool? ?? false,
      );
}

class InvoiceLine {
  final String itemId;
  final String itemName;
  final String unit;
  double qty;
  double unitPrice;
  double costPrice;

  InvoiceLine({
    required this.itemId,
    required this.itemName,
    required this.unit,
    required this.qty,
    required this.unitPrice,
    required this.costPrice,
  });

  double get lineTotal => qty * unitPrice;
  double get lineProfit => qty * (unitPrice - costPrice);

  Map<String, dynamic> toJson() => {
        'itemId': itemId,
        'itemName': itemName,
        'unit': unit,
        'qty': qty,
        'unitPrice': unitPrice,
        'costPrice': costPrice,
      };

  factory InvoiceLine.fromJson(Map<String, dynamic> j) => InvoiceLine(
        itemId: j['itemId'] as String,
        itemName: j['itemName'] as String,
        unit: j['unit'] as String? ?? 'حبة',
        qty: (j['qty'] as num).toDouble(),
        unitPrice: (j['unitPrice'] as num).toDouble(),
        costPrice: (j['costPrice'] as num?)?.toDouble() ?? 0.0,
      );
}

class MizanInvoice {
  final String id;
  final String number;
  final DateTime date;
  final InvoiceType type;
  final PaymentTerm paymentTerm;
  final String partyId;
  final String partyName;
  final String cashboxId;
  final String warehouse;
  final String currency;
  final List<InvoiceLine> lines;
  final double discountPercent;
  final double taxPercent;
  final double shipping;
  final double paidAmount;
  final String note;

  MizanInvoice({
    required this.id,
    required this.number,
    required this.date,
    required this.type,
    required this.paymentTerm,
    required this.partyId,
    required this.partyName,
    required this.cashboxId,
    required this.warehouse,
    required this.currency,
    required this.lines,
    this.discountPercent = 0,
    this.taxPercent = 0,
    this.shipping = 0,
    this.paidAmount = 0,
    this.note = '',
  });

  double get subtotal => lines.fold(0.0, (s, l) => s + l.lineTotal);
  double get discountAmount => subtotal * (discountPercent / 100.0);
  double get taxable => subtotal - discountAmount;
  double get taxAmount => taxable * (taxPercent / 100.0);
  double get netTotal => taxable + taxAmount + shipping;
  double get estimatedProfit =>
      lines.fold(0.0, (s, l) => s + l.lineProfit) - discountAmount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'date': date.toIso8601String(),
        'type': type.name,
        'paymentTerm': paymentTerm.name,
        'partyId': partyId,
        'partyName': partyName,
        'cashboxId': cashboxId,
        'warehouse': warehouse,
        'currency': currency,
        'lines': lines.map((e) => e.toJson()).toList(),
        'discountPercent': discountPercent,
        'taxPercent': taxPercent,
        'shipping': shipping,
        'paidAmount': paidAmount,
        'note': note,
      };

  factory MizanInvoice.fromJson(Map<String, dynamic> j) => MizanInvoice(
        id: j['id'] as String,
        number: j['number'] as String,
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        type: InvoiceType.values.firstWhere(
          (e) => e.name == j['type'],
          orElse: () => InvoiceType.sale,
        ),
        paymentTerm: PaymentTerm.values.firstWhere(
          (e) => e.name == j['paymentTerm'],
          orElse: () => PaymentTerm.cash,
        ),
        partyId: j['partyId'] as String? ?? '',
        partyName: j['partyName'] as String? ?? '',
        cashboxId: j['cashboxId'] as String? ?? '',
        warehouse: j['warehouse'] as String? ?? 'المخزن الرئيسي',
        currency: j['currency'] as String? ?? 'USD',
        lines: ((j['lines'] as List?) ?? [])
            .map((e) => InvoiceLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        discountPercent: (j['discountPercent'] as num?)?.toDouble() ?? 0.0,
        taxPercent: (j['taxPercent'] as num?)?.toDouble() ?? 0.0,
        shipping: (j['shipping'] as num?)?.toDouble() ?? 0.0,
        paidAmount: (j['paidAmount'] as num?)?.toDouble() ?? 0.0,
        note: j['note'] as String? ?? '',
      );
}

class LedgerEntry {
  final String id;
  final DateTime date;
  final String refNo;
  final String description;
  final String debitAccountId;
  final String debitAccountName;
  final String creditAccountId;
  final String creditAccountName;
  final double amount;
  final String currency;
  final String category; // INVOICE, RECEIPT, PAYMENT, FX, STOCKTAKE

  LedgerEntry({
    required this.id,
    required this.date,
    required this.refNo,
    required this.description,
    required this.debitAccountId,
    required this.debitAccountName,
    required this.creditAccountId,
    required this.creditAccountName,
    required this.amount,
    this.currency = 'USD',
    this.category = 'JOURNAL',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'refNo': refNo,
        'description': description,
        'debitAccountId': debitAccountId,
        'debitAccountName': debitAccountName,
        'creditAccountId': creditAccountId,
        'creditAccountName': creditAccountName,
        'amount': amount,
        'currency': currency,
        'category': category,
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> j) => LedgerEntry(
        id: j['id'] as String,
        date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
        refNo: j['refNo'] as String? ?? '',
        description: j['description'] as String? ?? '',
        debitAccountId: j['debitAccountId'] as String? ?? '',
        debitAccountName: j['debitAccountName'] as String? ?? '',
        creditAccountId: j['creditAccountId'] as String? ?? '',
        creditAccountName: j['creditAccountName'] as String? ?? '',
        amount: (j['amount'] as num?)?.toDouble() ?? 0.0,
        currency: j['currency'] as String? ?? 'USD',
        category: j['category'] as String? ?? 'JOURNAL',
      );
}

class TradeGate {
  final String id;
  final String title;
  final String partnerName;
  String status; // ACTIVE, PENDING
  final String verificationTag;

  TradeGate({
    required this.id,
    required this.title,
    required this.partnerName,
    required this.status,
    required this.verificationTag,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'partnerName': partnerName,
        'status': status,
        'verificationTag': verificationTag,
      };

  factory TradeGate.fromJson(Map<String, dynamic> j) => TradeGate(
        id: j['id'] as String,
        title: j['title'] as String,
        partnerName: j['partnerName'] as String,
        status: j['status'] as String? ?? 'PENDING',
        verificationTag: j['verificationTag'] as String? ?? 'UBL 2.1 • SHA-256',
      );
}
