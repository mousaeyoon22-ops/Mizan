import 'package:flutter/material.dart';
import '../../core/workspace/workspace_mode_controller.dart';

/// Preferences screen enabling one-tap switching across Easy, Standard, Professional,
/// Executive, and Express Field modes with transparent preview of layout & data changes.
class WorkspaceModeSelectorScreen extends StatelessWidget {
  final WorkspaceModeController controller;
  final bool isArabic;

  const WorkspaceModeSelectorScreen({
    super.key,
    required this.controller,
    this.isArabic = true,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final allowed = controller.allowedModesForRole;
        return Scaffold(
          appBar: AppBar(title: Text(isArabic ? 'أوضاع شاشة العرض والعمل' : 'Workspace Experience Modes')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...WorkspaceExperienceMode.values.map((m) {
                final p = WorkspaceModeController.profiles[m]!;
                final isPermitted = allowed.contains(m);
                final isSelected = controller.currentMode == m;
                return Card(
                  color: isSelected ? Colors.teal.shade50 : null,
                  child: RadioListTile<WorkspaceExperienceMode>(
                    value: m,
                    groupValue: controller.currentMode,
                    title: Text(
                      '${isArabic ? p.titleAr : p.titleEn}${isPermitted ? '' : (isArabic ? ' (مقيد بصلاحية الدور)' : ' (Role Restricted)')}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(p.subtitleAr),
                    onChanged: isPermitted ? (v) => controller.switchMode(v!) : null,
                  ),
                );
              }),
              const Divider(height: 24),
              SwitchListTile(
                title: Text(isArabic ? 'إخفاء الصفوف الفارغة تلقائياً عند طباعة تقارير A4' : 'Hide empty rows dynamically on A4 reports'),
                value: controller.hideEmptyPrintRows,
                onChanged: controller.setHideEmptyPrintRows,
              ),
            ],
          ),
        );
      },
    );
  }
}
