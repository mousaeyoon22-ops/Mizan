import 'package:flutter/material.dart';
import '../models/mizan_models.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';

class InventoryScreen extends StatefulWidget {
  final MizanStore store;
  const InventoryScreen({super.key, required this.store});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _openItemForm([MizanItem? existing]) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final skuCtrl = TextEditingController(text: existing?.sku ?? 'SKU-${100 + widget.store.items.length}');
    final unitCtrl = TextEditingController(text: existing?.unit ?? 'حبة');
    final costCtrl = TextEditingController(text: (existing?.costPrice ?? 0).toString());
    final saleCtrl = TextEditingController(text: (existing?.salePrice ?? 0).toString());
    final wholeCtrl = TextEditingController(text: (existing?.wholesalePrice ?? 0).toString());
    final marketCtrl = TextEditingController(text: (existing?.marketPrice ?? 0).toString());
    final qtyCtrl = TextEditingController(text: (existing?.stockQty ?? 0).toString());
    String wh = existing?.warehouse ?? widget.store.warehouses.first;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(existing == null ? 'إضافة صنف جديد' : 'تعديل الصنف', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الصنف')),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: skuCtrl, decoration: const InputDecoration(labelText: 'الباركود / SKU'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: unitCtrl, decoration: const InputDecoration(labelText: 'الوحدة'))),
                  ],
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: wh,
                  decoration: const InputDecoration(labelText: 'المخزن'),
                  items: widget.store.warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                  onChanged: (v) => setS(() => wh = v ?? wh),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر التكلفة'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: saleCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر البيع'))),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: TextField(controller: wholeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر الجملة'))),
                    const SizedBox(width: 8),
                    Expanded(child: TextField(controller: marketCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر السوق للمقارنة'))),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية المتوفرة في المخزن')),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () {
                    if (nameCtrl.text.trim().isEmpty) return;
                    widget.store.upsertItem(MizanItem(
                      id: existing?.id ?? 'itm_${DateTime.now().millisecondsSinceEpoch}',
                      sku: skuCtrl.text.trim(),
                      name: nameCtrl.text.trim(),
                      unit: unitCtrl.text.trim().isEmpty ? 'حبة' : unitCtrl.text.trim(),
                      warehouse: wh,
                      costPrice: double.tryParse(costCtrl.text) ?? 0,
                      salePrice: double.tryParse(saleCtrl.text) ?? 0,
                      wholesalePrice: double.tryParse(wholeCtrl.text) ?? 0,
                      marketPrice: double.tryParse(marketCtrl.text) ?? 0,
                      stockQty: double.tryParse(qtyCtrl.text) ?? 0,
                    ));
                    Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('حفظ الصنف'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openStocktakeDialog(MizanItem item) {
    final actualCtrl = TextEditingController(text: item.stockQty.toStringAsFixed(0));
    final reasonCtrl = TextEditingController(text: 'جرد دوري فعلي');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('جرد مخزني: ${item.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('الرصيد الدفتري الحالي: ${item.stockQty.toStringAsFixed(0)} ${item.unit}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(controller: actualCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية الفعلية المعدودة')),
            const SizedBox(height: 10),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'سبب التسوية')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final q = double.tryParse(actualCtrl.text);
              if (q != null) {
                widget.store.applyStocktake(itemId: item.id, actualQty: q, reason: reasonCtrl.text.trim());
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم اعتماد الجرد وترحيل قيد التسوية')));
            },
            child: const Text('اعتماد الجرد'),
          ),
        ],
      ),
    );
  }

  void _openTransferDialog(MizanItem item) {
    final qtyCtrl = TextEditingController(text: '1');
    final targets = widget.store.warehouses.where((w) => w != item.warehouse).toList();
    String target = targets.isNotEmpty ? targets.first : widget.store.warehouses.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('تحويل مخزني: ${item.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('من: ${item.warehouse} (المتاح: ${item.stockQty.toStringAsFixed(0)})'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: target,
                decoration: const InputDecoration(labelText: 'إلى مخزن'),
                items: widget.store.warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                onChanged: (v) => setS(() => target = v ?? target),
              ),
              const SizedBox(height: 10),
              TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية المحوّلة')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                final q = double.tryParse(qtyCtrl.text) ?? 0;
                widget.store.transferStock(itemId: item.id, toWarehouse: target, qty: q);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تنفيذ التحويل المخزني بنجاح')));
              },
              child: const Text('تنفيذ التحويل'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.store.items
        .where((i) => i.name.contains(_query) || i.sku.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('المخازن والأصناف والجرد'),
        actions: [
          FilledButton.icon(
            onPressed: () => _openItemForm(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('صنف جديد'),
          ),
          const SizedBox(width: 12),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'الأصناف والمخزون'),
            Tab(text: 'مقارنة الأسعار'),
            Tab(text: 'الجرد والتحويل'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: [
          // Tab 1: Items CRUD
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'ابحث باسم الصنف أو الباركود...',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final it = filtered[i];
                    final low = it.stockQty <= it.minStock;
                    return MizanCard(
                      onTap: () => _openItemForm(it),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: (low ? MizanColors.danger : MizanColors.primary).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.inventory_2_rounded, color: low ? MizanColors.danger : MizanColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(it.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text('${it.sku} • ${it.warehouse}', style: const TextStyle(fontSize: 12, color: MizanColors.muted)),
                                Text('البيع: ${it.salePrice.toStringAsFixed(2)} | التكلفة: ${it.costPrice.toStringAsFixed(2)}', style: const TextStyle(fontSize: 12, color: MizanColors.primary, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('${it.stockQty.toStringAsFixed(0)} ${it.unit}', style: TextStyle(fontWeight: FontWeight.w900, color: low ? MizanColors.danger : MizanColors.ink)),
                              const Text('اضغط للتعديل', style: TextStyle(fontSize: 10.5, color: MizanColors.muted)),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          // Tab 2: Price Comparison & Margin Analyzer
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.store.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final it = widget.store.items[i];
              final cheaper = it.marketDiff <= 0;
              return MizanCard(
                onTap: () => _openItemForm(it),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (cheaper ? MizanColors.success : MizanColors.accent).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'هامش ${it.marginPercent.toStringAsFixed(1)}%',
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: cheaper ? MizanColors.success : MizanColors.accent),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _priceCol('التكلفة', it.costPrice)),
                        Expanded(child: _priceCol('الجملة', it.wholesalePrice)),
                        Expanded(child: _priceCol('سعرنا', it.salePrice, highlight: true)),
                        Expanded(child: _priceCol('السوق', it.marketPrice)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cheaper
                          ? 'سعرنا تنافسي أقل من السوق بمقدار ${it.marketDiff.abs().toStringAsFixed(2)} USD'
                          : 'سعرنا أعلى من السوق بمقدار ${it.marketDiff.toStringAsFixed(2)} USD — اضغط للتعديل',
                      style: TextStyle(fontSize: 12, color: cheaper ? MizanColors.success : MizanColors.accent, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            },
          ),

          // Tab 3: Stocktake & Warehouse Transfer
          ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.store.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final it = widget.store.items[i];
              return MizanCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                        Text('${it.stockQty.toStringAsFixed(0)} ${it.unit}', style: const TextStyle(fontWeight: FontWeight.w900, color: MizanColors.primary)),
                      ],
                    ),
                    Text(it.warehouse, style: const TextStyle(fontSize: 12, color: MizanColors.muted)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openStocktakeDialog(it),
                            icon: const Icon(Icons.fact_check_outlined, size: 18),
                            label: const Text('جرد وتسوية'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _openTransferDialog(it),
                            icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                            label: const Text('تحويل مخزني'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _priceCol(String label, double val, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: MizanColors.muted)),
        Text(
          val.toStringAsFixed(2),
          style: TextStyle(fontWeight: FontWeight.w800, color: highlight ? MizanColors.primary : null),
        ),
      ],
    );
  }
}
