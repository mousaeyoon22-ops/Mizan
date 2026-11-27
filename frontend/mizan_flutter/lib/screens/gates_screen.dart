import 'package:flutter/material.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';

class GatesScreen extends StatelessWidget {
  final MizanStore store;
  const GatesScreen({super.key, required this.store});

  void _addGateDialog(BuildContext context) {
    final titleCtrl = TextEditingController(text: 'باب مبيعات ومرتجعات');
    final partnerCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إنشاء باب تجاري جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'نوع الباب التجاري')),
            const SizedBox(height: 10),
            TextField(controller: partnerCtrl, decoration: const InputDecoration(labelText: 'اسم الطرف الثاني (عميل / موزع)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              if (partnerCtrl.text.trim().isEmpty) return;
              store.addGate(title: titleCtrl.text.trim(), partnerName: partnerCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('إرسال طلب الباب'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الأبواب التجارية'),
        actions: [
          IconButton(onPressed: () => _addGateDialog(context), icon: const Icon(Icons.add_circle_outline_rounded)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MizanCard(
            color: MizanColors.primarySoft,
            child: const Text('القرارات الثلاثة المستقلة: اقتران ← موافقة الباب ← ترحيل محاسبي مستقل', style: TextStyle(fontWeight: FontWeight.w700, color: MizanColors.primaryDark)),
          ),
          const SizedBox(height: 10),
          SwitchListTile(
            value: store.contextualChatOpen,
            onChanged: store.setContextualChat,
            title: const Text('مفتاح الدردشة التوافقية مع الأطراف', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(store.contextualChatOpen ? 'مفتوحة ومؤرشفة مع المستندات' : 'مغلقة (استقبال مستندات رسمية فقط)'),
          ),
          const SizedBox(height: 10),
          ...store.gates.map((g) {
            final active = g.status == 'ACTIVE';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: MizanCard(
                child: Row(
                  children: [
                    Icon(active ? Icons.verified_rounded : Icons.hourglass_top_rounded, color: active ? MizanColors.success : MizanColors.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${g.title} • ${g.partnerName}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(g.verificationTag, style: const TextStyle(fontSize: 12, color: MizanColors.muted)),
                        ],
                      ),
                    ),
                    if (active)
                      const Chip(label: Text('ACTIVE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)))
                    else
                      FilledButton.tonal(
                        onPressed: () => store.approveGate(g.id),
                        child: const Text('اعتماد'),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
