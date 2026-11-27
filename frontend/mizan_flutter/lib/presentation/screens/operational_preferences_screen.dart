import 'package:flutter/material.dart';
import '../../core/features/feature_flag_controller.dart';

/// Clean Operational Preferences screen allowing org owners to activate/deactivate
/// embedded Phase 1 modules, while cleanly isolating Phase 2/3 extensions under
/// read-only "Scheduled Extensions" (fully compliant with Apple App Store 2.1).
class OperationalPreferencesScreen extends StatelessWidget {
  final FeatureFlagController controller;
  final bool isArabic;

  const OperationalPreferencesScreen({
    super.key,
    required this.controller,
    this.isArabic = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final configurable = controller.configurableInCurrentPhase;
        final upcoming = controller.upcomingPlatformExtensions;

        return Scaffold(
          appBar: AppBar(
            title: Text(isArabic ? 'التفضيلات التشغيلية والوحدات' : 'Operational Preferences & Modules'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                isArabic ? 'الوحدات القابلة للتشغيل والإيقاف (النسخة الحالية)' : 'Active Version Operational Toggles',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...configurable.map((f) => SwitchListTile(
                    title: Text(isArabic ? f.titleAr : f.titleEn),
                    subtitle: Text('${f.category} • ${f.key}'),
                    value: f.effectiveEnabled,
                    onChanged: (val) {
                      final err = controller.toggleLocalPreference(f.key, val);
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                      }
                    },
                  )),
              const Divider(height: 32),
              ExpansionTile(
                title: Text(
                  isArabic ? 'الارتباطات والإضافات المدمجة (موقوفة لحين التفعيل الرسمي)' : 'Embedded Extensions (Inactive in Current Rollout)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                children: upcoming
                    .map((f) => ListTile(
                          leading: const Icon(Icons.lock_outline, color: Colors.grey),
                          title: Text(isArabic ? f.titleAr : f.titleEn),
                          subtitle: Text(isArabic ? 'المرحلة ${f.releasePhase} — مهيأة برمجياً وموقوفة افتراضياً' : 'Phase ${f.releasePhase} — Architected & Inactive'),
                          trailing: Chip(label: Text(isArabic ? 'موقوفة' : 'OFF')),
                        ))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
