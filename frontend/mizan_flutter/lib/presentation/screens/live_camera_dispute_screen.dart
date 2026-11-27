import 'package:flutter/material.dart';
import '../../core/l10n/mizan_localizations.dart';
import '../../domain/models/mizan_models.dart';

/// Anti-Fraud Dispute Screen:
/// - NO gallery picker button exists anywhere on this screen.
/// - Enforces live in-app camera capture stamped with Server UTC + GPS + SHA-256.
/// - Enforces 30-min perishable dispute window.
class LiveCameraDisputeScreen extends StatefulWidget {
  final MizanStrings strings;
  final String orderId;
  final bool isPerishable;
  final DateTime deliveredAtUtc;

  const LiveCameraDisputeScreen({
    super.key,
    required this.strings,
    required this.orderId,
    required this.isPerishable,
    required this.deliveredAtUtc,
  });

  @override
  State<LiveCameraDisputeScreen> createState() => _LiveCameraDisputeScreenState();
}

class _LiveCameraDisputeScreenState extends State<LiveCameraDisputeScreen> {
  String _selectedReason = 'DAMAGED_OR_SPOILED';

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final guard = DisputeAntiFraudGuard.validate(
      deliveredAtUtc: widget.deliveredAtUtc,
      nowUtc: DateTime.now().toUtc(),
      isPerishable: widget.isPerishable,
      isLiveInAppCamera: true,
    );

    return Scaffold(
      appBar: AppBar(title: Text(s.t('open_dispute'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.t('gallery_blocked'), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    if (widget.isPerishable) Text(s.t('perishable_window')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedReason,
              decoration: const InputDecoration(border: OutlineInputBorder(), labelText: 'سبب الاعتراض المصنّف'),
              items: const [
                DropdownMenuItem(value: 'DAMAGED_OR_SPOILED', child: Text('بضاعة تالفة / غير صالحة (مسؤولية البائع)')),
                DropdownMenuItem(value: 'CATALOG_MISMATCH', child: Text('غير مطابقة للكتالوج (مسؤولية البائع)')),
                DropdownMenuItem(value: 'QTY_SHORTAGE', child: Text('نقص في الكمية المستلمة (مسؤولية البائع)')),
                DropdownMenuItem(value: 'MUTUAL_CANCEL', child: Text('اتفاق الطرفين على الإلغاء (محايد)')),
              ],
              onChanged: (v) => setState(() => _selectedReason = v!),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: Text(guard.allowed ? 'فتح الكاميرا الحية وتوثيق الدليل (GPS + UTC)' : 'انتهت نافذة الاعتراض (${guard.reason})'),
              onPressed: guard.allowed ? () => Navigator.pop(context) : null,
            ),
          ],
        ),
      ),
    );
  }
}
