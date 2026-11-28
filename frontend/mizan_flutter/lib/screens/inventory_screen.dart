import 'package:flutter/material.dart';
import '../db/mizan_database.dart';
import '../models/mizan_models.dart';
import '../outputs/mizan_outputs.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';

class InventoryScreen extends StatelessWidget {
  final MizanStore store;
  const InventoryScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(store.t('nav_inventory')),
        actions: [
          IconButton(
            tooltip: store.t('import_csv'),
            icon: const Icon(Icons.upload_file_outlined),
            onPressed: () => _handleCsvDryRunImport(context),
          ),
          IconButton(
            tooltip: store.t('export_csv'),
            icon: const Icon(Icons.download_outlined),
            onPressed: () => MizanOutputs.exportItemsCsv(store.items),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(14),
        itemCount: store.items.length,
        itemBuilder: (ctx, i) {
          final it = store.items[i];
          return Card(
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
                          it.localAlias.isNotEmpty ? '${it.localAlias} (${it.name})' : it.name,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      MizanBadge(text: it.mgid, color: MizanColors.info),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'المخزن: ${it.warehouse} (${it.binLocation}) · الرصيد: ${it.stockQty.toStringAsFixed(1)} ${it.baseUnit} · البيع: ${it.salePrice} · التكلفة: ${it.costPrice}',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  if (it.expiryDate.isNotEmpty || it.barcode.isNotEmpty)
                    Text(
                      'باركود: ${it.barcode} · دفعة: ${it.batchNo} · صلاحية: ${it.expiryDate}',
                      style: const TextStyle(fontSize: 11.5, color: MizanColors.muted),
                    ),
                  if (it.units.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: it.units
                          .map((u) => MizanBadge(text: '${u.name} ×${u.factorToBase}', color: MizanColors.primary))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: () => _openStocktakeDialog(context, it),
                        child: const Text('جرد مخزني'),
                      ),
                      OutlinedButton(
                        onPressed: () => _openTransferDialog(context, it),
                        child: const Text('تحويل مخزني'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddMultiUnitItemDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('صنف بـ 3 وحدات'),
      ),
    );
  }

  Future<void> _handleCsvDryRunImport(BuildContext context) async {
    final res = await MizanOutputs.pickCsvForDryRun();
    if (res == null || !context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('معاينة الاستيراد التجريبي (Dry-Run): ${res.fileName}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('عدد الصفوف الصالحة للاستيراد: ${res.previewRows.length}'),
              if (res.warnings.isNotEmpty) Text('تحذيرات: ${res.warnings.join(" | ")}', style: const TextStyle(color: MizanColors.danger)),
              const SizedBox(height: 8),
              ...res.previewRows.take(5).map((r) => Text('• ${r.values.take(3).join(" — ")}', style: const TextStyle(fontSize: 12))),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
          FilledButton(
            onPressed: () async {
              final count = await store.importItemsFromDryRun(res.previewRows);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تم اعتماد استيراد $count صنف مع توليد معرّفات MGID.')));
              }
            },
            child: const Text('اعتماد الاستيراد'),
          ),
        ],
      ),
    );
  }

  void _openStocktakeDialog(BuildContext context, MizanItem it) {
    final ctrl = TextEditingController(text: it.stockQty.toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('جرد أعمى / فعلي: ${it.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: 'الكمية الفعلية بوحدة الأساس (${it.baseUnit})'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
          FilledButton(
            onPressed: () async {
              final qty = double.tryParse(ctrl.text) ?? it.stockQty;
              await store.applyStocktake(itemId: it.id, actualBaseQty: qty);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('ترحيل تسوية الجرد'),
          ),
        ],
      ),
    );
  }

  void _openTransferDialog(BuildContext context, MizanItem it) {
    String target = store.warehouses.first;
    final qtyCtrl = TextEditingController(text: '10');
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: Text('تحويل مخزني: ${it.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: target,
                decoration: const InputDecoration(labelText: 'المخزن المستلم'),
                items: store.warehouses.map((w) => DropdownMenuItem(value: w, child: Text(w))).toList(),
                onChanged: (v) => setSt(() => target = v ?? target),
              ),
              const SizedBox(height: 8),
              TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'الكمية (${it.baseUnit})')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
            FilledButton(
              onPressed: () async {
                await store.transferStock(itemId: it.id, targetWarehouse: target, qtyBase: double.tryParse(qtyCtrl.text) ?? 0);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('تنفيذ التحويل'),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddMultiUnitItemDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final baseUnitCtrl = TextEditingController(text: 'حبة');
    final u2NameCtrl = TextEditingController(text: 'شدة');
    final u2FactorCtrl = TextEditingController(text: '6');
    final u3NameCtrl = TextEditingController(text: 'كرتون');
    final u3FactorCtrl = TextEditingController(text: '24');
    final costCtrl = TextEditingController(text: '1.0');
    final saleCtrl = TextEditingController(text: '1.5');
    final qtyCtrl = TextEditingController(text: '100');
    final barcodeCtrl = TextEditingController();
    final expiryCtrl = TextEditingController(text: '2027-12-31');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة صنف بـ 3 وحدات قياس + MGID'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'اسم الصنف')),
              const SizedBox(height: 8),
              TextField(controller: baseUnitCtrl, decoration: const InputDecoration(labelText: 'الوحدة 1 (الأساس ×1)')),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: u2NameCtrl, decoration: const InputDecoration(labelText: 'الوحدة 2'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: u2FactorCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المعامل'))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: u3NameCtrl, decoration: const InputDecoration(labelText: 'الوحدة 3'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: u3FactorCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'المعامل'))),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: TextField(controller: costCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'التكلفة'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: saleCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'سعر البيع'))),
                ],
              ),
              const SizedBox(height: 8),
              TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'الكمية الافتتاحية (بالأساس)')),
              const SizedBox(height: 8),
              TextField(controller: barcodeCtrl, decoration: const InputDecoration(labelText: 'الباركود')),
              const SizedBox(height: 8),
              TextField(controller: expiryCtrl, decoration: const InputDecoration(labelText: 'تاريخ الصلاحية (YYYY-MM-DD)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
          FilledButton(
            onPressed: () async {
              if (nameCtrl.text.trim().isEmpty) return;
              final id = MizanUuidV7.next();
              final sale = double.tryParse(saleCtrl.text) ?? 0;
              final f2 = double.tryParse(u2FactorCtrl.text) ?? 6;
              final f3 = double.tryParse(u3FactorCtrl.text) ?? 24;
              await store.upsertItem(MizanItem(
                id: id,
                mgid: MizanSha256.generateMgid('ITM', nameCtrl.text.trim(), baseUnitCtrl.text.trim()),
                sku: 'SKU-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                name: nameCtrl.text.trim(),
                baseUnit: baseUnitCtrl.text.trim(),
                units: [
                  ItemUnit(id: MizanUuidV7.next(), itemId: id, name: baseUnitCtrl.text.trim(), factorToBase: 1, salePrice: sale, isDefaultSale: true),
                  ItemUnit(id: MizanUuidV7.next(), itemId: id, name: u2NameCtrl.text.trim(), factorToBase: f2, salePrice: sale * f2 * 0.96),
                  ItemUnit(id: MizanUuidV7.next(), itemId: id, name: u3NameCtrl.text.trim(), factorToBase: f3, salePrice: sale * f3 * 0.92, isDefaultPurchase: true),
                ],
                warehouse: store.warehouses.first,
                barcode: barcodeCtrl.text.trim(),
                expiryDate: expiryCtrl.text.trim(),
                costPrice: double.tryParse(costCtrl.text) ?? 0,
                salePrice: sale,
                wholesalePrice: sale * 0.9,
                marketPrice: sale * 1.05,
                stockQty: double.tryParse(qtyCtrl.text) ?? 0,
              ));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(store.t('save')),
          ),
        ],
      ),
    );
  }
}
