import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../db/mizan_database.dart';
import '../models/mizan_models.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';

class NetworkHubScreen extends StatelessWidget {
  final MizanStore store;
  const NetworkHubScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(store.t('nav_network')),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'البوابات و MGID'),
              Tab(text: 'الصفحة التجارية'),
              Tab(text: 'المقاصة و RFQ'),
              Tab(text: 'مزامنة Outbox'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildGatesAndMgidTab(context),
            _buildStorefrontTab(context),
            _buildNettingAndRfqTab(context),
            _buildSyncOutboxTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildGatesAndMgidTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: () => _openAddGateDialog(context),
              icon: const Icon(Icons.link_rounded),
              label: const Text('اقتران بوابة جديدة'),
            ),
            OutlinedButton.icon(
              onPressed: () => _openImportMgidDialog(context),
              icon: const Icon(Icons.hub_outlined),
              label: const Text('استلام صنف MGID'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Text('البوابات المقترنة (عزل التكاليف مفعّل 100%)', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...store.pairedGates.map((g) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(g.partnerName, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('الرمز: ${g.gateCode} · ${g.gateType} · انتشار MGID: ${g.allowMgidPropagation ? "مفعّل" : "معطّل"}'),
                trailing: const MizanBadge(text: 'معزول التكلفة', color: MizanColors.success),
              ),
            )),
        const SizedBox(height: 12),
        const Text('نشر تعريفات الأصناف عبر MGID (بدون كشف التكلفة أو المخزون)', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        ...store.items.map((it) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${it.mgid} · ${it.units.length} وحدات قياس'),
                trailing: IconButton(
                  tooltip: 'مشاركة حزمة MGID المعيارية',
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () {
                    final payload = jsonEncode(it.toPublicMgidPayload());
                    Clipboard.setData(ClipboardData(text: payload));
                    Share.share(payload, subject: 'Mizan MGID Package: ${it.mgid}');
                  },
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildStorefrontTab(BuildContext context) {
    final publicUrl = 'https://mizan.store/@${store.storefrontHandle}';
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                MizanVisualQrBox(data: publicUrl, size: 92),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(store.entityName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text(publicUrl, style: const TextStyle(fontSize: 12, color: MizanColors.info)),
                      const SizedBox(height: 6),
                      const MizanBadge(text: 'معزول عن الدفتر حتى الاعتماد', color: MizanColors.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (store.items.isNotEmpty)
          FilledButton.icon(
            onPressed: () async {
              final it = store.items.first;
              await store.publishToStorefront(item: it, publicPrice: it.salePrice, visibility: 'PUBLIC');
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('تم نشر «${it.name}» على الصفحة التجارية.')),
                );
              }
            },
            icon: const Icon(Icons.storefront_outlined),
            label: const Text('نشر أول صنف في الكتالوج العام'),
          ),
        const SizedBox(height: 12),
        const Text('المعروض في الصفحة التجارية', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ...store.storefrontListings.map((l) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(l.publicTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('${l.publicPrice} ${l.currency} · ${l.visibility} · ${l.mgid}'),
                trailing: OutlinedButton(
                  onPressed: () async {
                    await store.receiveStorefrontOrder(listing: l, buyerName: 'عميل من الصفحة العامة', qty: 2);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ورد طلب جديد إلى صندوق الاعتماد المعزول.')),
                      );
                    }
                  },
                  child: const Text('تجربة طلب'),
                ),
              ),
            )),
        const SizedBox(height: 12),
        const Text('صندوق الطلبات الواردة (معزول عن الدفتر حتى اعتمادك)', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        ...store.storefrontOrders.map((o) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text('${o.buyerName} — ${o.itemTitle}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('الكمية: ${o.qty} × ${o.unitPrice} ${o.currency} · الحالة: ${o.status}'),
                trailing: o.status == 'PENDING_APPROVAL'
                    ? FilledButton(
                        onPressed: () async {
                          final err = await store.approveStorefrontOrder(o.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(err ?? 'تم اعتماد الطلب وترحيله كفاتورة مبيعات متوازنة.')),
                            );
                          }
                        },
                        child: const Text('اعتماد وترحيل'),
                      )
                    : const MizanBadge(text: 'مرحّل', color: MizanColors.success),
              ),
            )),
      ],
    );
  }

  Widget _buildNettingAndRfqTab(BuildContext context) {
    final snap = store.auditSnapshot();
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.verified_user_outlined, color: MizanColors.success, size: 32),
            title: const Text('مؤشر الثقة الدفتري (SHA-256 Trust Score)', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('الدرجة الحالية: ${snap.trustScore.toStringAsFixed(1)}/100 من واقع ${snap.verifiedEntryCount} قيد موثّق ومتوازن.'),
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('المقاصة متعددة الأطراف (Multi-Party Netting)', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('تسوية مديونيات ثلاثية بموافقة الأطراف بقيد مزدوج متوازن دون حركة نقدية فائضة.', style: TextStyle(fontSize: 13)),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () => _openNettingDialog(context),
                  icon: const Icon(Icons.sync_alt_rounded),
                  label: const Text('تنفيذ مقاصة ثلاثية متوازنة'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Card(
          child: ListTile(
            leading: Icon(Icons.bolt_outlined, color: MizanColors.accent),
            title: Text('نبض الأسعار ومطابقة العرض والطلب (Price Pulse & RFQ)', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('تُحدث الأسعار المرجعية المرتبطة بمعرّف MGID للمشترين المقترنين دون تعديل تكلفة البضاعة التاريخية المقفلة (COGS).'),
          ),
        ),
      ],
    );
  }

  Widget _buildSyncOutboxTab(BuildContext context) {
    final pending = store.syncOutbox.where((e) => e.status == 'PENDING').length;
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('طابور المزامنة Offline-First (معلق: $pending)', style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('المنفذ السحابي المجهّز: ${store.syncEndpointUrl}', style: const TextStyle(fontSize: 12, color: MizanColors.muted)),
                const SizedBox(height: 6),
                const Text(
                  'ملاحظة هندسية: كل عملية تحفظ محلياً بمفتاح منع تكرار (UUID v7 + Idempotency Key). عند ربط خادم السحابة الفعلي، تُرفع هذه الحزم دون أي تكرار للمستندات.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => store.markOutboxSyncedDemo(),
                  icon: const Icon(Icons.cloud_done_outlined),
                  label: const Text('اختبار تفريغ طابور المزامنة'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...store.syncOutbox.take(25).map((item) => Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                title: Text('${item.entityType.toUpperCase()} · ${item.idempotencyKey}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                subtitle: Text(item.createdAt.toIso8601String().substring(0, 19)),
                trailing: MizanBadge(
                  text: item.status,
                  color: item.status == 'SYNCED' ? MizanColors.success : MizanColors.accent,
                ),
              ),
            )),
      ],
    );
  }

  void _openAddGateDialog(BuildContext context) {
    final partnerCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'توريد ومبيعات B2B');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إنشاء بوابة اقتران جديدة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: partnerCtrl, decoration: const InputDecoration(labelText: 'اسم الشريك / المنشأة')),
            const SizedBox(height: 8),
            TextField(controller: typeCtrl, decoration: const InputDecoration(labelText: 'نوع البوابة')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
          FilledButton(
            onPressed: () async {
              if (partnerCtrl.text.trim().isEmpty) return;
              await store.addPairedGate(PairedGate(
                id: MizanUuidV7.next(),
                gateCode: 'MZN-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
                partnerName: partnerCtrl.text.trim(),
                gateType: typeCtrl.text.trim(),
              ));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(store.t('save')),
          ),
        ],
      ),
    );
  }

  void _openImportMgidDialog(BuildContext context) {
    final jsonCtrl = TextEditingController();
    final aliasCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('استلام صنف عبر MGID (بعزل التكاليف)'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: jsonCtrl, maxLines: 4, decoration: const InputDecoration(labelText: 'الصق حزمة MGID JSON')),
              const SizedBox(height: 8),
              TextField(controller: aliasCtrl, decoration: const InputDecoration(labelText: 'تسمية محلية خاصة بك (Local Alias - اختياري)')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
          FilledButton(
            onPressed: () async {
              final msg = await store.propagateMgidPayload(jsonCtrl.text, localAlias: aliasCtrl.text.trim());
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
              }
            },
            child: const Text('استلام واعتماد الصنف'),
          ),
        ],
      ),
    );
  }

  void _openNettingDialog(BuildContext context) {
    if (store.accounts.length < 3) return;
    String a = store.accounts[0].id;
    String b = store.accounts[1].id;
    String c = store.accounts[2].id;
    final amtCtrl = TextEditingController(text: '250');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          title: const Text('مقاصة ثلاثية بموافقة الأطراف'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: a,
                decoration: const InputDecoration(labelText: 'الطرف الأول'),
                items: store.accounts.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name))).toList(),
                onChanged: (v) => setSt(() => a = v ?? a),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: b,
                decoration: const InputDecoration(labelText: 'الطرف الثاني'),
                items: store.accounts.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name))).toList(),
                onChanged: (v) => setSt(() => b = v ?? b),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: c,
                decoration: const InputDecoration(labelText: 'الطرف الثالث'),
                items: store.accounts.map((x) => DropdownMenuItem(value: x.id, child: Text(x.name))).toList(),
                onChanged: (v) => setSt(() => c = v ?? c),
              ),
              const SizedBox(height: 8),
              TextField(controller: amtCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ المقاصة')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(store.t('cancel'))),
            FilledButton(
              onPressed: () async {
                final err = await store.executeMultiPartyNetting(
                  partyAId: a,
                  partyBId: b,
                  partyCId: c,
                  amount: double.tryParse(amtCtrl.text) ?? 0,
                );
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err ?? 'تم ترحيل قيد المقاصة الثلاثية المتوازن بنجاح.')),
                  );
                }
              },
              child: const Text('تنفيذ المقاصة'),
            ),
          ],
        ),
      ),
    );
  }
}
