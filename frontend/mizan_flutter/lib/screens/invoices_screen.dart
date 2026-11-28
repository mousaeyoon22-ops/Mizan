import 'package:flutter/material.dart';
import '../db/mizan_database.dart';
import '../models/mizan_models.dart';
import '../outputs/mizan_outputs.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';

class InvoicesScreen extends StatefulWidget {
  final MizanStore store;
  const InvoicesScreen({super.key, required this.store});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('nav_invoices'))),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          if (s.documents.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('لا توجد مستندات بعد. اضغط «مستند جديد» لإنشاء فاتورة تجارية أو خدمة أو مستخلص مقاولات أو دورة تصنيع أو توزيع مياه.'),
              ),
            ),
          ...s.documents.map((doc) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${doc.docNo} — ${doc.partyName.isEmpty ? "عميل نقدي مباشر" : doc.partyName}',
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                          MizanBadge(text: doc.sectorCycle.name, color: MizanColors.primary),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${doc.docType.name} · ${doc.docDate.toIso8601String().substring(0, 10)} · الإجمالي: ${doc.totalAmount.toStringAsFixed(2)} ${doc.currency} (المدفوع: ${doc.paidAmount.toStringAsFixed(2)})',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () async {
                              final bytes = await MizanOutputs.buildDocumentPdf(
                                doc: doc,
                                entityName: s.entityName,
                                bookCurrency: s.bookCurrency,
                              );
                              await MizanOutputs.sharePdfToWhatsApp(
                                bytes: bytes,
                                fileName: '${doc.docNo}.pdf',
                                caption: '${s.entityName} — ${doc.docNo}',
                              );
                            },
                            icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                            label: Text(s.t('export_pdf')),
                          ),
                          OutlinedButton.icon(
                            onPressed: () async {
                              final bytes = await MizanOutputs.buildDocumentPdf(
                                doc: doc,
                                entityName: s.entityName,
                                bookCurrency: s.bookCurrency,
                                thermal80mm: true,
                              );
                              await MizanOutputs.printPdfDocument(
                                bytes: bytes,
                                jobName: '${doc.docNo}_80mm',
                              );
                            },
                            icon: const Icon(Icons.print_outlined, size: 18),
                            label: Text(s.t('thermal_print')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDocumentBuilder(context),
        icon: const Icon(Icons.add),
        label: const Text('مستند / دورة جديدة'),
      ),
    );
  }

  void _openDocumentBuilder(BuildContext context) {
    final s = widget.store;
    if (s.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف صنفاً أو خدمة واحدة أولاً في شاشة المخازن.')),
      );
      return;
    }

    SectorCycle cycle = SectorCycle.trade;
    DocumentType docType = DocumentType.saleInvoice;
    PaymentTerm term = PaymentTerm.cash;
    String? partyId; // Optional on cash invoices!
    String currency = s.bookCurrency;
    MizanItem selectedItem = s.items.first;
    ItemUnit selectedUnit = selectedItem.units.isNotEmpty
        ? selectedItem.units.first
        : ItemUnit(id: 'base', itemId: selectedItem.id, name: selectedItem.baseUnit, factorToBase: 1, salePrice: selectedItem.salePrice);

    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: selectedUnit.salePrice > 0 ? selectedUnit.salePrice.toString() : selectedItem.salePrice.toString());
    final vatCtrl = TextEditingController(text: s.defaultVatPercent.toString());
    final retentionCtrl = TextEditingController(text: '0');
    final noteCtrl = TextEditingController();

    final parties = s.accounts.where((a) => a.type == AccountType.customer || a.type == AccountType.supplier).toList();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('إنشاء مستند تشغيلي (5+1 دورات)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<SectorCycle>(
                  value: cycle,
                  decoration: const InputDecoration(labelText: 'الدورة القطاعية'),
                  items: SectorCycle.values.map((c) => DropdownMenuItem(value: c, child: Text(c.name))).toList(),
                  onChanged: (v) {
                    setSt(() {
                      cycle = v ?? SectorCycle.trade;
                      if (cycle == SectorCycle.contracting) {
                        docType = DocumentType.contractCertificate;
                        retentionCtrl.text = '10';
                      } else if (cycle == SectorCycle.services) {
                        docType = DocumentType.serviceInvoice;
                      } else if (cycle == SectorCycle.manufacturing) {
                        docType = DocumentType.manufacturingOrder;
                      } else if (cycle == SectorCycle.subscriptions) {
                        docType = DocumentType.subscriptionBilling;
                      } else if (cycle == SectorCycle.waterDistribution) {
                        docType = DocumentType.waterRouteDispatch;
                      } else {
                        docType = DocumentType.saleInvoice;
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<DocumentType>(
                  value: docType,
                  decoration: const InputDecoration(labelText: 'نوع المستند'),
                  items: [
                    DocumentType.saleInvoice,
                    DocumentType.purchaseInvoice,
                    DocumentType.saleReturn,
                    DocumentType.purchaseReturn,
                    DocumentType.serviceInvoice,
                    DocumentType.contractCertificate,
                    DocumentType.manufacturingOrder,
                    DocumentType.subscriptionBilling,
                    DocumentType.waterRouteDispatch,
                  ].map((d) => DropdownMenuItem(value: d, child: Text(d.name))).toList(),
                  onChanged: (v) => setSt(() => docType = v ?? DocumentType.saleInvoice),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<PaymentTerm>(
                  value: term,
                  decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                  items: PaymentTerm.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                  onChanged: (v) => setSt(() => term = v ?? PaymentTerm.cash),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: partyId,
                  decoration: const InputDecoration(labelText: 'العميل / المورد (اختياري في النقدي)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('عميل نقدي مباشر (بدون اسم)')),
                    ...parties.map((p) => DropdownMenuItem<String?>(value: p.id, child: Text(p.name))),
                  ],
                  onChanged: (v) => setSt(() => partyId = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<MizanItem>(
                  value: selectedItem,
                  decoration: const InputDecoration(labelText: 'الصنف / الخدمة'),
                  items: s.items.map((it) => DropdownMenuItem(value: it, child: Text('${it.name} (${it.stockQty} ${it.baseUnit})'))).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setSt(() {
                      selectedItem = v;
                      selectedUnit = v.units.isNotEmpty
                          ? v.units.first
                          : ItemUnit(id: 'base', itemId: v.id, name: v.baseUnit, factorToBase: 1, salePrice: v.salePrice);
                      priceCtrl.text = (selectedUnit.salePrice > 0 ? selectedUnit.salePrice : v.salePrice).toString();
                    });
                  },
                ),
                const SizedBox(height: 8),
                if (selectedItem.units.isNotEmpty)
                  DropdownButtonFormField<ItemUnit>(
                    value: selectedUnit,
                    decoration: const InputDecoration(labelText: 'وحدة القياس (التحويل الآلي للأساس)'),
                    items: selectedItem.units
                        .map((u) => DropdownMenuItem(value: u, child: Text('${u.name} (×${u.factorToBase})')))
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setSt(() {
                        selectedUnit = v;
                        if (v.salePrice > 0) priceCtrl.text = v.salePrice.toString();
                      });
                    },
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: priceCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'السعر'))),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: TextField(controller: vatCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الضريبة %'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: retentionCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'محتجز مقاولات %'))),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: currency,
                  decoration: InputDecoration(labelText: s.t('currency')),
                  items: ['USD', 'SAR', 'YER', 'AED', 'EUR'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setSt(() => currency = v ?? s.bookCurrency),
                ),
                const SizedBox(height: 8),
                TextField(controller: noteCtrl, decoration: const InputDecoration(labelText: 'ملاحظات المستند')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(s.t('cancel'))),
            FilledButton(
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text) ?? 1;
                final price = double.tryParse(priceCtrl.text) ?? 0;
                final vat = double.tryParse(vatCtrl.text) ?? 0;
                final ret = double.tryParse(retentionCtrl.text) ?? 0;
                final sub = qty * price;
                final total = sub + (sub * vat / 100.0);
                final paid = term == PaymentTerm.cash ? total : (term == PaymentTerm.partial ? total * 0.5 : 0.0);
                final party = partyId != null ? s.accounts.firstWhere((a) => a.id == partyId) : null;
                final docId = MizanUuidV7.next();
                final doc = MizanDocument(
                  id: docId,
                  docNo: 'DOC-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
                  docType: docType,
                  sectorCycle: cycle,
                  docDate: DateTime.now(),
                  branchName: s.currentBranch,
                  warehouse: party?.defaultWarehouse ?? s.warehouses.first,
                  partyId: party?.id ?? 'acc-walkin',
                  partyName: party?.name ?? 'عميل نقدي مباشر',
                  cashboxId: 'acc-cash',
                  paymentTerm: term,
                  currency: currency,
                  fxRate: s.fxRateFor(currency),
                  subtotal: sub,
                  taxPercent: vat,
                  retentionPercent: ret,
                  totalAmount: total,
                  paidAmount: paid,
                  note: noteCtrl.text.trim(),
                  lines: [
                    DocumentLine(
                      id: MizanUuidV7.next(),
                      documentId: docId,
                      itemId: selectedItem.id,
                      mgid: selectedItem.mgid,
                      itemName: selectedItem.name,
                      unitName: selectedUnit.name,
                      unitFactor: selectedUnit.factorToBase,
                      qty: qty,
                      unitPrice: price,
                      costAtPosting: selectedItem.costPrice,
                    ),
                  ],
                );
                final err = await s.postOperationalDocument(doc);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err ?? 'تم ترحيل المستند ${doc.docNo} وتحديث المخزون والدفتر بنجاح.')),
                  );
                }
              },
              child: Text(s.t('save')),
            ),
          ],
        ),
      ),
    );
  }
}
