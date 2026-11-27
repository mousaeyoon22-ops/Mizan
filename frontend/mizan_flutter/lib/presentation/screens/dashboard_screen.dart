import 'package:flutter/material.dart';
import '../../core/l10n/mizan_localizations.dart';
import '../../core/money/money_minor.dart';

class DashboardScreen extends StatefulWidget {
  final MizanStrings strings;
  final VoidCallback onToggleLocale;

  const DashboardScreen({super.key, required this.strings, required this.onToggleLocale});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedOrg = 'محطة مياه صحة (UID-8841)';
  String _displayCurrency = 'USD';
  int _pendingOutboxCount = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final arBalance = MoneyMinor.parse('600.0000', _displayCurrency);
    final invBalance = MoneyMinor.parse('450.0000', _displayCurrency);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.t('app_title')),
        actions: [
          TextButton(
            onPressed: widget.onToggleLocale,
            child: Text(s.isRtl ? 'EN' : 'عربي', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          DropdownButton<String>(
            value: _displayCurrency,
            underline: const SizedBox.shrink(),
            items: const ['USD', 'SAR', 'AED', 'EUR', 'YER']
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) => setState(() => _displayCurrency = v ?? 'USD'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Multi-Organization Switcher (Layer 1 Person -> Layer 2 Independent Orgs)
          Card(
            child: ListTile(
              leading: const Icon(Icons.business_center),
              title: Text(_selectedOrg),
              subtitle: const Text('KYC Level 2 • Trial Balance Variance: 0.0000'),
              trailing: PopupMenuButton<String>(
                onSelected: (val) => setState(() => _selectedOrg = val),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'محطة مياه صحة (UID-8841)', child: Text('محطة مياه صحة (توزيع)')),
                  PopupMenuItem(value: 'ورشة الصيانة الهندسية (UID-8842)', child: Text('ورشة الصيانة (خدمات)')),
                  PopupMenuItem(value: 'حساب شخصي موحّد (UID-1001)', child: Text('الميزانية الشخصية الموحّدة')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Offline Sync Outbox Banner
          Card(
            color: _pendingOutboxCount == 0 ? Colors.teal.shade50 : Colors.amber.shade50,
            child: ListTile(
              leading: Icon(_pendingOutboxCount == 0 ? Icons.cloud_done : Icons.sync_problem),
              title: Text(_pendingOutboxCount == 0 ? s.t('synced_ok') : '${s.t('offline_pending')}: $_pendingOutboxCount'),
              trailing: FilledButton.tonal(
                onPressed: () => setState(() => _pendingOutboxCount = 0),
                child: Text(s.t('sync_now')),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _kpiCard('الذمم المدينة / AR', arBalance.formatDisplay())),
              const SizedBox(width: 12),
              Expanded(child: _kpiCard('المخزون / IAS 2', invBalance.formatDisplay())),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
