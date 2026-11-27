import 'package:flutter/material.dart';

class PosVariantOption {
  final String variantId;
  final String barcode;
  final String itemName;
  final String sizeLabel;
  final String colorLabel;
  final int priceMinor; // x10000
  final int stockUnits;

  const PosVariantOption({
    required this.variantId,
    required this.barcode,
    required this.itemName,
    required this.sizeLabel,
    required this.colorLabel,
    required this.priceMinor,
    required this.stockUnits,
  });
}

/// Touch Split-Screen POS (60% Product/Variant Grid + Live QR Carts | 40% Running Invoice & Touch Numpad).
/// Automatically adapts to single-column tabs on compact mobile screens (< 900px).
class SplitScreenPosScreen extends StatefulWidget {
  final bool isArabic;
  final bool variantsMatrixEnabled;
  final String terminalName;

  const SplitScreenPosScreen({
    super.key,
    this.isArabic = true,
    this.variantsMatrixEnabled = true,
    this.terminalName = 'كاشير #1 — بوابة الملابس',
  });

  @override
  State<SplitScreenPosScreen> createState() => _SplitScreenPosScreenState();
}

class _SplitScreenPosScreenState extends State<SplitScreenPosScreen> {
  String _selectedCategory = 'رجالي';
  final TextEditingController _barcodeCtrl = TextEditingController();
  final Map<String, int> _cart = {};
  final List<Map<String, int>> _parkedInvoices = [];

  final List<PosVariantOption> _variants = const [
    PosVariantOption(variantId: 'v1', barcode: '629000111222', itemName: 'قميص قطني كلاسيك', sizeLabel: 'M', colorLabel: 'أزرق كحلي', priceMinor: 250000, stockUnits: 18),
    PosVariantOption(variantId: 'v2', barcode: '629000111223', itemName: 'قميص قطني كلاسيك', sizeLabel: 'L', colorLabel: 'أبيض', priceMinor: 250000, stockUnits: 12),
    PosVariantOption(variantId: 'v3', barcode: '629000111224', itemName: 'بنطلون جينز رسمي', sizeLabel: '32', colorLabel: 'أسود', priceMinor: 420000, stockUnits: 9),
    PosVariantOption(variantId: 'v4', barcode: '629000111225', itemName: 'جاكيت شتوي مبطن', sizeLabel: 'XL', colorLabel: 'زيتي', priceMinor: 890000, stockUnits: 4),
  ];

  int _computeTotalMinor() {
    int sum = 0;
    for (final e in _cart.entries) {
      final v = _variants.firstWhere((x) => x.variantId == e.key);
      sum += v.priceMinor * e.value;
    }
    return sum;
  }

  void _addByBarcode(String code) {
    final hit = _variants.where((v) => v.barcode == code.trim()).firstOrNull;
    if (hit != null) {
      setState(() => _cart[hit.variantId] = (_cart[hit.variantId] ?? 0) + 1);
      _barcodeCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final catalogPane = _buildCatalogTouchPane();
    final invoicePane = _buildRunningInvoicePane();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.terminalName} • POS'),
        actions: [
          Chip(label: Text('${widget.isArabic ? 'فواتير معلّقة' : 'Parked'}: ${_parkedInvoices.length}')),
          const SizedBox(width: 12),
        ],
      ),
      body: isWide
          ? Row(
              children: [
                Expanded(flex: 6, child: catalogPane),
                const VerticalDivider(width: 1),
                Expanded(flex: 4, child: invoicePane),
              ],
            )
          : Column(
              children: [
                Expanded(flex: 5, child: catalogPane),
                const Divider(height: 1),
                Expanded(flex: 5, child: invoicePane),
              ],
            ),
    );
  }

  Widget _buildCatalogTouchPane() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          TextField(
            controller: _barcodeCtrl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.qr_code_scanner),
              hintText: widget.isArabic ? 'امسح باركود القطعة (USB / Bluetooth) أو ابحث...' : 'Scan variant barcode or search...',
              border: const OutlineInputBorder(),
            ),
            onSubmitted: _addByBarcode,
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['رجالي', 'نسائي', 'أطفال', 'سلال QR الحية']
                  .map((cat) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: ChoiceChip(
                          label: Text(cat),
                          selected: _selectedCategory == cat,
                          onSelected: (_) => setState(() => _selectedCategory = cat),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 210,
                childAspectRatio: 1.25,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: _variants.length,
              itemBuilder: (_, idx) {
                final v = _variants[idx];
                return InkWell(
                  onTap: () => setState(() => _cart[v.variantId] = (_cart[v.variantId] ?? 0) + 1),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(v.itemName, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 2),
                          if (widget.variantsMatrixEnabled)
                            Text('${v.sizeLabel} • ${v.colorLabel}', style: const TextStyle(color: Colors.teal, fontSize: 12)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('${(v.priceMinor / 10000).toStringAsFixed(2)} \$', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('×${v.stockUnits}', style: const TextStyle(fontSize: 11, color: Colors.black54)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRunningInvoicePane() {
    final totalStr = (_computeTotalMinor() / 10000).toStringAsFixed(2);
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: _cart.isEmpty
                ? Center(child: Text(widget.isArabic ? 'المس أي صنف أو امسح الباركود لبدء الفاتورة' : 'Tap item or scan barcode'))
                : ListView(
                    children: _cart.entries.map((e) {
                      final v = _variants.firstWhere((x) => x.variantId == e.key);
                      return ListTile(
                        dense: true,
                        title: Text('${v.itemName} (${v.sizeLabel}/${v.colorLabel})'),
                        subtitle: Text('${e.value} × ${(v.priceMinor / 10000).toStringAsFixed(2)}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => setState(() => _cart.remove(e.key)),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.isArabic ? 'الإجمالي المستحق' : 'Total Due', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('$totalStr USD', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.pause_circle_outline),
                  label: Text(widget.isArabic ? 'تعليق' : 'Park'),
                  onPressed: _cart.isEmpty
                      ? null
                      : () => setState(() {
                            _parkedInvoices.add(Map<String, int>.from(_cart));
                            _cart.clear();
                          }),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  icon: const Icon(Icons.point_of_sale),
                  label: Text(widget.isArabic ? 'تحصيل كاش وطباعة' : 'Cash & Print'),
                  onPressed: _cart.isEmpty ? null : () => setState(() => _cart.clear()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
