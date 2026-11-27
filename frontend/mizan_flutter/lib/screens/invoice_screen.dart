import 'package:flutter/material.dart';
import '../models/mizan_models.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';

class InvoicesHubScreen extends StatelessWidget {
  final MizanStore store;
  const InvoicesHubScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفواتير والحركة التجارية'),
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceBuilderScreen(store: store))),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('فاتورة جديدة'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: store.invoices.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.receipt_long_outlined, size: 56, color: MizanColors.muted),
                    const SizedBox(height: 12),
                    const Text('لا توجد فواتير مسجلة بعد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text('أنشئ أول فاتورة بيع أو شراء لتحديث المخزون والصندوق والقيود تلقائياً.', textAlign: TextAlign.center, style: TextStyle(color: MizanColors.muted)),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceBuilderScreen(store: store))),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('إنشاء فاتورة الآن'),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: store.invoices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final inv = store.invoices[i];
                final typeLabel = switch (inv.type) {
                  InvoiceType.sale => 'فاتورة بيع',
                  InvoiceType.purchase => 'فاتورة شراء',
                  InvoiceType.saleReturn => 'مرتجع بيع',
                  InvoiceType.purchaseReturn => 'مرتجع شراء',
                };
                return MizanCard(
                  onTap: () => _showReceiptPreview(ctx, inv),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (inv.type == InvoiceType.sale ? MizanColors.success : MizanColors.info).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          inv.type == InvoiceType.sale ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          color: inv.type == InvoiceType.sale ? MizanColors.success : MizanColors.info,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${inv.number} • $typeLabel', style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('${inv.partyName} • ${inv.warehouse}', style: const TextStyle(fontSize: 12.5, color: MizanColors.muted)),
                            Text(fmtDate(inv.date), style: const TextStyle(fontSize: 11, color: MizanColors.muted)),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(fmtMoney(inv.netTotal, inv.currency), style: const TextStyle(fontWeight: FontWeight.w800, color: MizanColors.primary)),
                          if (inv.type == InvoiceType.sale)
                            Text('الربح: ${inv.estimatedProfit.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11.5, color: MizanColors.success, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  static void _showReceiptPreview(BuildContext context, MizanInvoice inv) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('معاينة الفاتورة ${inv.number} (A4 / 80mm)'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('الطرف: ${inv.partyName}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('المخزن: ${inv.warehouse} • ${fmtDate(inv.date)}', style: const TextStyle(fontSize: 12, color: MizanColors.muted)),
              const Divider(height: 18),
              ...inv.lines.map((l) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(child: Text('${l.itemName} (${l.qty} × ${l.unitPrice})')),
                        Text(l.lineTotal.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )),
              const Divider(height: 18),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الإجمالي قبل الخصم:'), Text(inv.subtotal.toStringAsFixed(2))]),
              if (inv.discountAmount > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الخصم:'), Text('-${inv.discountAmount.toStringAsFixed(2)}')]),
              if (inv.taxAmount > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الضريبة:'), Text('+${inv.taxAmount.toStringAsFixed(2)}')]),
              if (inv.shipping > 0) Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('أجور النقل:'), Text('+${inv.shipping.toStringAsFixed(2)}')]),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('صافي الفاتورة:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(fmtMoney(inv.netTotal, inv.currency), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: MizanColors.primary)),
                ],
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('المدفوع:'), Text(fmtMoney(inv.paidAmount, inv.currency))]),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('إغلاق')),
        ],
      ),
    );
  }
}

class InvoiceBuilderScreen extends StatefulWidget {
  final MizanStore store;
  const InvoiceBuilderScreen({super.key, required this.store});

  @override
  State<InvoiceBuilderScreen> createState() => _InvoiceBuilderScreenState();
}

class _InvoiceBuilderScreenState extends State<InvoiceBuilderScreen> {
  InvoiceType _type = InvoiceType.sale;
  PaymentTerm _term = PaymentTerm.cash;
  late String _warehouse;
  MizanAccount? _party;
  MizanAccount? _cashbox;
  final List<InvoiceLine> _lines = [];
  final _discCtrl = TextEditingController(text: '0');
  final _taxCtrl = TextEditingController(text: '0');
  final _shipCtrl = TextEditingController(text: '0');
  final _paidCtrl = TextEditingController(text: '0');
  final _noteCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _warehouse = widget.store.warehouses.first;
    final parties = widget.store.accounts.where((a) => a.type == AccountType.customer || a.type == AccountType.supplier).toList();
    if (parties.isNotEmpty) _party = parties.first;
    final boxes = widget.store.accounts.where((a) => a.type == AccountType.cashbox).toList();
    if (boxes.isNotEmpty) _cashbox = boxes.first;
  }

  @override
  void dispose() {
    _discCtrl.dispose();
    _taxCtrl.dispose();
    _shipCtrl.dispose();
    _paidCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double get _subtotal => _lines.fold(0.0, (s, l) => s + l.lineTotal);
  double get _discPct => double.tryParse(_discCtrl.text) ?? 0.0;
  double get _taxPct => double.tryParse(_taxCtrl.text) ?? 0.0;
  double get _ship => double.tryParse(_shipCtrl.text) ?? 0.0;
  double get _discAmt => _subtotal * (_discPct / 100.0);
  double get _taxAmt => (_subtotal - _discAmt) * (_taxPct / 100.0);
  double get _netTotal => (_subtotal - _discAmt) + _taxAmt + _ship;
  double get _profit => _lines.fold(0.0, (s, l) => s + l.lineProfit) - _discAmt;

  void _addLinePicker() {
    if (widget.store.items.isEmpty) return;
    MizanItem selected = widget.store.items.first;
    final qtyCtrl = TextEditingController(text: '1');
    final priceCtrl = TextEditingController(text: (_type == InvoiceType.purchase ? selected.costPrice : selected.salePrice).toStringAsFixed(2));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إضافة صنف للفاتورة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              DropdownButtonFormField<MizanItem>(
                value: selected,
                decoration: const InputDecoration(labelText: 'اختر الصنف'),
                items: widget.store.items
                    .map((it) => DropdownMenuItem(value: it, child: Text('${it.name} (متاح: ${it.stockQty.toStringAsFixed(0)})')))
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  setS(() {
                    selected = v;
                    priceCtrl.text = (_type == InvoiceType.purchase ? v.costPrice : v.salePrice).toStringAsFixed(2);
                  });
                },
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'الكمية'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'السعر'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  final q = double.tryParse(qtyCtrl.text) ?? 1;
                  final pr = double.tryParse(priceCtrl.text) ?? selected.salePrice;
                  if (q <= 0) return;
                  setState(() {
                    _lines.add(InvoiceLine(
                      itemId: selected.id,
                      itemName: selected.name,
                      unit: selected.unit,
                      qty: q,
                      unitPrice: pr,
                      costPrice: selected.costPrice,
                    ));
                  });
                  Navigator.pop(ctx);
                },
                child: const Text('إضافة السطر'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    if (_lines.isEmpty || _party == null || _cashbox == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أضف صنفاً واحداً على الأقل واختر الطرف والصندوق')));
      return;
    }
    final inv = widget.store.postInvoice(
      type: _type,
      paymentTerm: _term,
      party: _party!,
      cashbox: _cashbox!,
      warehouse: _warehouse,
      lines: List.of(_lines),
      discountPercent: _discPct,
      taxPercent: _taxPct,
      shipping: _ship,
      partialPaid: double.tryParse(_paidCtrl.text) ?? 0.0,
      note: _noteCtrl.text.trim(),
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم ترحيل الفاتورة ${inv.number} وتحديث المخزون والأرصدة بنجاح')));
  }

  @override
  Widget build(BuildContext context) {
    final parties = widget.store.accounts.where((a) => a.type == AccountType.customer || a.type == AccountType.supplier).toList();
    final boxes = widget.store.accounts.where((a) => a.type == AccountType.cashbox).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء فاتورة جديدة'),
        actions: [
          TextButton.icon(onPressed: _save, icon: const Icon(Icons.check_rounded), label: const Text('حفظ وترحيل')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<InvoiceType>(
            segments: const [
              ButtonSegment(value: InvoiceType.sale, label: Text('بيع')),
              ButtonSegment(value: InvoiceType.purchase, label: Text('شراء')),
              ButtonSegment(value: InvoiceType.saleReturn, label: Text('مرتجع بيع')),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 10),
          SegmentedButton<PaymentTerm>(
            segments: const [
              ButtonSegment(value: PaymentTerm.cash, label: Text('نقدي')),
              ButtonSegment(value: PaymentTerm.credit, label: Text('آجل')),
              ButtonSegment(value: PaymentTerm.partial, label: Text('نصف آجل')),
            ],
            selected: {_term},
            onSelectionChanged: (s) => setState(() => _term = s.first),
          ),
          const SizedBox(height: 12),
          MizanCard(
            child: Column(
              children: [
                DropdownButtonFormField<MizanAccount>(
                  value: _party,
                  decoration: const InputDecoration(labelText: 'العميل / المورد', prefixIcon: Icon(Icons.person_outline_rounded)),
                  items: parties.map((p) => DropdownMenuItem(value: p, child: Text('${p.name} (${fmtMoney(p.balance, p.currency)})'))).toList(),
                  onChanged: (v) => setState(() => _party = v),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<MizanAccount>(
                        value: _cashbox,
                        decoration: const InputDecoration(labelText: 'الصندوق'),
                        items: boxes.map((b) => DropdownMenuItem(value: b, child: Text(b.name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _cashbox = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _warehouse,
                        decoration: const InputDecoration(labelText: 'المخزن'),
                        items: widget.store.warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _warehouse = v ?? _warehouse),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('أصناف الفاتورة', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              const Spacer(),
              FilledButton.tonalIcon(
                onPressed: _addLinePicker,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('إضافة صنف'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_lines.isEmpty)
            const MizanCard(child: Center(child: Text('اضغط "إضافة صنف" لإدراج الأصناف في الفاتورة', style: TextStyle(color: MizanColors.muted))))
          else
            ..._lines.asMap().entries.map((entry) {
              final idx = entry.key;
              final l = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: MizanCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.itemName, style: const TextStyle(fontWeight: FontWeight.w700)),
                            Text('${l.qty} ${l.unit} × ${l.unitPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: MizanColors.muted)),
                          ],
                        ),
                      ),
                      Text(l.lineTotal.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.w800, color: MizanColors.primary)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: MizanColors.danger, size: 20),
                        onPressed: () => setState(() => _lines.removeAt(idx)),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 12),
          MizanCard(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: _discCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الخصم %'), onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _taxCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الضريبة %'), onChanged: (_) => setState(() {}))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: _shipCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'النقل'), onChanged: (_) => setState(() {}))),
                  ],
                ),
                if (_term == PaymentTerm.partial) ...[
                  const SizedBox(height: 10),
                  TextField(controller: _paidCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المبلغ المستلم الآن (دفعة)')),
                ],
                const SizedBox(height: 10),
                TextField(controller: _noteCtrl, decoration: const InputDecoration(labelText: 'ملاحظات الفاتورة')),
                const Divider(height: 22),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الإجمالي الصافي:', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), Text(fmtMoney(_netTotal, _cashbox?.currency ?? 'USD'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: MizanColors.primary))]),
                if (_type == InvoiceType.sale) ...[
                  const SizedBox(height: 4),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الربح التقديري:', style: TextStyle(color: MizanColors.success, fontWeight: FontWeight.w700)), Text(fmtMoney(_profit, _cashbox?.currency ?? 'USD'), style: const TextStyle(color: MizanColors.success, fontWeight: FontWeight.w800))]),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save_rounded),
            label: const Text('حفظ وترحيل الفاتورة بقيد متوازن'),
          ),
        ],
      ),
    );
  }
}
