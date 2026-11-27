import 'package:flutter/material.dart';
import '../models/mizan_models.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';

class QrCartScreen extends StatefulWidget {
  final MizanStore store;
  const QrCartScreen({super.key, required this.store});

  @override
  State<QrCartScreen> createState() => _QrCartScreenState();
}

class _QrCartScreenState extends State<QrCartScreen> {
  final Map<String, double> _cart = {};
  PaymentTerm _term = PaymentTerm.cash;

  double get _total {
    double s = 0;
    for (final it in widget.store.items) {
      s += (_cart[it.id] ?? 0) * it.salePrice;
    }
    return s;
  }

  void _submitOrder() {
    final lines = <InvoiceLine>[];
    for (final it in widget.store.items) {
      final q = _cart[it.id] ?? 0;
      if (q > 0) {
        lines.add(InvoiceLine(itemId: it.id, itemName: it.name, unit: it.unit, qty: q, unitPrice: it.salePrice, costPrice: it.costPrice));
      }
    }
    if (lines.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر صنفاً واحداً على الأقل')));
      return;
    }
    final customer = widget.store.accounts.firstWhere((a) => a.type == AccountType.customer, orElse: () => widget.store.accounts.first);
    final cashbox = widget.store.accounts.firstWhere((a) => a.type == AccountType.cashbox, orElse: () => widget.store.accounts.first);
    final inv = widget.store.postInvoice(
      type: InvoiceType.sale,
      paymentTerm: _term,
      party: customer,
      cashbox: cashbox,
      warehouse: widget.store.warehouses.first,
      lines: lines,
      note: 'طلب سلة حية عبر QR',
    );
    setState(() => _cart.clear());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم حجز وترحيل الطلب ${inv.number} بنجاح')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('مسح QR والسلة الحية')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MizanCard(
            color: MizanColors.primarySoft,
            child: Row(
              children: const [
                Icon(Icons.wifi_tethering_rounded, color: MizanColors.primary),
                SizedBox(width: 10),
                Expanded(child: Text('السلة الحية متصلة بكاشير المتجر • State: LIVE_CART', style: TextStyle(fontWeight: FontWeight.w700, color: MizanColors.primaryDark))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...widget.store.items.map((it) {
            final q = _cart[it.id] ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MizanCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(it.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text('${fmtMoney(it.salePrice)} • المتاح: ${it.stockQty.toStringAsFixed(0)} ${it.unit}', style: const TextStyle(fontSize: 12, color: MizanColors.muted)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: q > 0 ? () => setState(() => _cart[it.id] = q - 1) : null, icon: const Icon(Icons.remove_circle_outline_rounded)),
                    Text(q.toStringAsFixed(0), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    IconButton(onPressed: () => setState(() => _cart[it.id] = q + 1), icon: const Icon(Icons.add_circle_outline_rounded, color: MizanColors.primary)),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 10),
          const Text('وسيلة الدفع وإثبات الجدية', style: TextStyle(fontWeight: FontWeight.w800)),
          RadioListTile<PaymentTerm>(value: PaymentTerm.gateway, groupValue: _term, onChanged: (v) => setState(() => _term = v!), title: const Text('بوابة تمرير (تفويض مسبق آمن)')),
          RadioListTile<PaymentTerm>(value: PaymentTerm.cash, groupValue: _term, onChanged: (v) => setState(() => _term = v!), title: const Text('نقداً عند المعاينة (كاش)')),
          RadioListTile<PaymentTerm>(value: PaymentTerm.credit, groupValue: _term, onChanged: (v) => setState(() => _term = v!), title: const Text('آجل (ضمن السقف المعتمد)')),
          RadioListTile<PaymentTerm>(value: PaymentTerm.partial, groupValue: _term, onChanged: (v) => setState(() => _term = v!), title: const Text('نصف آجل (دفعة + ذمة)')),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الإجمالي:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              Text(fmtMoney(_total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: MizanColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _submitOrder, icon: const Icon(Icons.check_rounded), label: const Text('إرسال الطلب وحجز الأصناف')),
        ],
      ),
    );
  }
}
