import 'package:flutter/material.dart';
import '../../core/l10n/mizan_localizations.dart';
import '../../core/money/money_minor.dart';
import '../../domain/models/mizan_models.dart';
import 'live_camera_dispute_screen.dart';

/// Implements the Viral QR Self-Checkout & P2P Authorize/Capture Flow:
/// 1) Buyer scans Store QR -> Loads catalog
/// 2) Buyer builds Live Cart synced via SignalR to Cashier
/// 3) Buyer selects Payment Commitment (Pre-Auth PSP / Cash / Credit / Partial)
/// 4) Buyer inspects goods -> Releases funds OR opens Live-Camera-Only Dispute
class QrLiveCartScreen extends StatefulWidget {
  final MizanStrings strings;
  const QrLiveCartScreen({super.key, required this.strings});

  @override
  State<QrLiveCartScreen> createState() => _QrLiveCartScreenState();
}

class _QrLiveCartScreenState extends State<QrLiveCartScreen> {
  PaymentMode _paymentMode = PaymentMode.gatewayPreAuth;
  String _orderState = 'LIVE_CART';
  DateTime? _deliveredAtUtc;

  final List<CatalogItem> _catalog = [
    CatalogItem(
      id: 'itm-1', orgId: 'org-water', sku: 'WTR-20L', name: 'عبوة مياه نقية 20 لتر',
      salePrice: MoneyMinor.parse('10.0000', 'USD'), isPerishable: false, qtyAvailableMinor: 800000,
    ),
    CatalogItem(
      id: 'itm-2', orgId: 'org-fresh', sku: 'VEG-TOM', name: 'صندوق خضار طازجة (قابل للتلف)',
      salePrice: MoneyMinor.parse('15.5000', 'USD'), isPerishable: true, qtyAvailableMinor: 120000,
    ),
  ];

  final Map<String, int> _cartQtyMinor = {'itm-1': 20000}; // 2.0000 units

  MoneyMinor _computeTotal() {
    var total = MoneyMinor.zero('USD');
    for (final item in _catalog) {
      final qty = _cartQtyMinor[item.id] ?? 0;
      if (qty > 0) total = total + item.salePrice.multiplyByQtyMinor(qty);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final total = _computeTotal();

    return Scaffold(
      appBar: AppBar(title: Text(s.t('qr_cart'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.wifi_tethering, color: Colors.teal),
                const SizedBox(width: 8),
                Expanded(child: Text('${s.t('live_cart_active')} • State: $_orderState')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ..._catalog.map((item) {
            final qtyUnits = (_cartQtyMinor[item.id] ?? 0) ~/ MoneyMinor.scale;
            return Card(
              child: ListTile(
                title: Text(item.name),
                subtitle: Text('${item.salePrice.formatDisplay()} ${item.isPerishable ? "• 30m Dispute Window" : ""}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: qtyUnits > 0
                          ? () => setState(() => _cartQtyMinor[item.id] = (qtyUnits - 1) * MoneyMinor.scale)
                          : null,
                    ),
                    Text('$qtyUnits', style: const TextStyle(fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () => setState(() => _cartQtyMinor[item.id] = (qtyUnits + 1) * MoneyMinor.scale),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Text(s.t('payment_mode'), style: const TextStyle(fontWeight: FontWeight.bold)),
          RadioListTile<PaymentMode>(
            title: Text(s.t('pay_preauth')),
            value: PaymentMode.gatewayPreAuth,
            groupValue: _paymentMode,
            onChanged: (v) => setState(() => _paymentMode = v!),
          ),
          RadioListTile<PaymentMode>(
            title: Text(s.t('pay_cash')),
            value: PaymentMode.cash,
            groupValue: _paymentMode,
            onChanged: (v) => setState(() => _paymentMode = v!),
          ),
          RadioListTile<PaymentMode>(
            title: Text(s.t('pay_credit')),
            value: PaymentMode.credit,
            groupValue: _paymentMode,
            onChanged: (v) => setState(() => _paymentMode = v!),
          ),
          RadioListTile<PaymentMode>(
            title: Text(s.t('pay_partial')),
            value: PaymentMode.partialCredit,
            groupValue: _paymentMode,
            onChanged: (v) => setState(() => _paymentMode = v!),
          ),
          const Divider(),
          ListTile(
            title: const Text('الإجمالي / Total', style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: Text(total.formatDisplay(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          FilledButton(
            onPressed: () => setState(() {
              _orderState = 'INSPECTING';
              _deliveredAtUtc = DateTime.now().toUtc();
            }),
            child: Text(s.t('submit_order')),
          ),
          const SizedBox(height: 8),
          if (_orderState == 'INSPECTING') ...[
            FilledButton.tonal(
              onPressed: () => setState(() => _orderState = 'COMPLETED'),
              child: Text(s.t('confirm_release')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.videocam_outlined, color: Colors.red),
              label: Text(s.t('open_dispute'), style: const TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LiveCameraDisputeScreen(
                    strings: s,
                    orderId: 'ORD-LIVE-01',
                    isPerishable: (_cartQtyMinor['itm-2'] ?? 0) > 0,
                    deliveredAtUtc: _deliveredAtUtc ?? DateTime.now().toUtc(),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
