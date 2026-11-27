import 'package:flutter/material.dart';
import '../../core/l10n/mizan_localizations.dart';

class NearbyStoresScreen extends StatefulWidget {
  final MizanStrings strings;
  const NearbyStoresScreen({super.key, required this.strings});

  @override
  State<NearbyStoresScreen> createState() => _NearbyStoresScreenState();
}

class _NearbyStoresScreenState extends State<NearbyStoresScreen> {
  bool _onlyHighTrust = true;
  bool _onlyAcceptsPreAuth = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return Scaffold(
      appBar: AppBar(title: Text(s.t('nearby'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('موثوقية +95%'),
                selected: _onlyHighTrust,
                onSelected: (v) => setState(() => _onlyHighTrust = v),
              ),
              FilterChip(
                label: const Text('يدعم التفويض المسبق P2P'),
                selected: _onlyAcceptsPreAuth,
                onSelected: (v) => setState(() => _onlyAcceptsPreAuth = v),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.water_drop, color: Colors.teal),
              title: Text('محطة مياه صحة — وادي اللحج'),
              subtitle: Text('Trust Score: 99.4% • يقبل كاش + بوابة تمرير • 0.8 كم'),
              trailing: Icon(Icons.qr_code_2),
            ),
          ),
        ],
      ),
    );
  }
}
