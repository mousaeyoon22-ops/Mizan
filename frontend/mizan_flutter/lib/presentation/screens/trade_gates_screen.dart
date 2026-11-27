import 'package:flutter/material.dart';
import '../../core/l10n/mizan_localizations.dart';

class TradeGatesScreen extends StatefulWidget {
  final MizanStrings strings;
  const TradeGatesScreen({super.key, required this.strings});

  @override
  State<TradeGatesScreen> createState() => _TradeGatesScreenState();
}

class _TradeGatesScreenState extends State<TradeGatesScreen> {
  bool _chatOpenForCounterparties = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('trade_gates'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(s.t('gate_decisions'), style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          SwitchListTile(
            title: const Text('مفتاح الدردشة التوافقية مع الأطراف'),
            subtitle: Text(_chatOpenForCounterparties ? 'مفتوحة للأبواب المعتمدة فقط' : 'مغلقة (استقبال مستندات رسمية فقط)'),
            value: _chatOpenForCounterparties,
            onChanged: (v) => setState(() => _chatOpenForCounterparties = v),
          ),
          const Divider(),
          const ListTile(
            leading: Icon(Icons.verified_outlined, color: Colors.teal),
            title: Text('باب المبيعات والمرتجعات • متجر الأمل'),
            subtitle: Text('UBL 2.1 • SHA-256 Verified • Variance: 0.0000'),
            trailing: Chip(label: Text('ACTIVE')),
          ),
          const ListTile(
            leading: Icon(Icons.local_shipping_outlined),
            title: Text('باب التحميل والعهدة • الموزع أحمد'),
            subtitle: Text('بانتظار موافقة الطرف الثاني على الباب (القرار 2)'),
            trailing: Chip(label: Text('PENDING')),
          ),
        ],
      ),
    );
  }
}
