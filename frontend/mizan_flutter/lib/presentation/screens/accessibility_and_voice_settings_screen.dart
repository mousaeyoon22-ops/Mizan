import 'package:flutter/material.dart';
import '../../core/accessibility/accessibility_profile_controller.dart';
import '../../core/accessibility/accessible_widgets.dart';
import '../../core/voice/bilingual_voice_command_parser.dart';

/// Unified Inclusive Accessibility (ذوي الهمم) & Voice Command Operations Screen.
class AccessibilityAndVoiceSettingsScreen extends StatefulWidget {
  final AccessibilityProfileController controller;
  final bool isArabic;

  const AccessibilityAndVoiceSettingsScreen({
    super.key,
    required this.controller,
    this.isArabic = true,
  });

  @override
  State<AccessibilityAndVoiceSettingsScreen> createState() => _AccessibilityAndVoiceSettingsScreenState();
}

class _AccessibilityAndVoiceSettingsScreenState extends State<AccessibilityAndVoiceSettingsScreen> {
  final TextEditingController _voiceInputCtrl = TextEditingController();
  ParsedVoiceCommand? _pendingDraft;

  void _handleVoiceSubmit(String text) {
    final parsed = BilingualVoiceCommandParser.parse(text);
    if (parsed.intent == LocalVoiceIntent.confirmDraft && _pendingDraft != null) {
      setState(() => _pendingDraft = null);
      MizanSensoryFeedbackBridge.notify(
        context: context,
        a11y: widget.controller,
        message: widget.isArabic ? 'تم تأكيد الأمر الصوتي وترحيله بنجاح' : 'Voice financial draft confirmed and posted',
      );
      return;
    }
    if (parsed.intent == LocalVoiceIntent.cancelDraft) {
      setState(() => _pendingDraft = null);
      MizanSensoryFeedbackBridge.notify(
        context: context,
        a11y: widget.controller,
        message: widget.isArabic ? 'تم إلغاء المسودة الصوتية' : 'Voice draft cancelled',
      );
      return;
    }

    if (parsed.requiresTwoStepConfirmation) {
      setState(() => _pendingDraft = parsed);
      MizanSensoryFeedbackBridge.notify(
        context: context,
        a11y: widget.controller,
        message: widget.isArabic
            ? 'مسودة بانتظار التأكيد: ${parsed.intent.name} — قل (تأكيد الترحيل) أو اضغط تأكيد'
            : 'Draft awaiting confirmation: ${parsed.intent.name}',
      );
    } else {
      MizanSensoryFeedbackBridge.notify(
        context: context,
        a11y: widget.controller,
        message: widget.isArabic ? 'تم تنفيذ الاستعلام الصوتي: ${parsed.intent.name}' : 'Executed: ${parsed.intent.name}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final a11y = widget.controller;
    return AnimatedBuilder(
      animation: a11y,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.isArabic ? 'سهولة الوصول (ذوي الهمم) والأوامر الصوتية' : 'Accessibility & Voice Operations'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                widget.isArabic ? 'أوضاع التهيئة السريعة لذوي الهمم (WCAG 2.2 AA)' : 'One-Tap Inclusive Accessibility Presets',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(widget.isArabic ? 'قياسي' : 'Standard'),
                    selected: a11y.preset == AccessibilityPreset.standard,
                    onSelected: (_) => a11y.applyPreset(AccessibilityPreset.standard),
                  ),
                  ChoiceChip(
                    label: Text(widget.isArabic ? 'مكفوفون (قارئ شاشة + صوت)' : 'Blind (Screen Reader + Voice)'),
                    selected: a11y.preset == AccessibilityPreset.blindScreenReader,
                    onSelected: (_) => a11y.applyPreset(AccessibilityPreset.blindScreenReader),
                  ),
                  ChoiceChip(
                    label: Text(widget.isArabic ? 'ضعف بصر (تباين عالٍ 175%)' : 'Low Vision (High Contrast)'),
                    selected: a11y.preset == AccessibilityPreset.lowVisionHighContrast,
                    onSelected: (_) => a11y.applyPreset(AccessibilityPreset.lowVisionHighContrast),
                  ),
                  ChoiceChip(
                    label: Text(widget.isArabic ? 'صم وضعاف سمع (بصري + اهتزاز)' : 'Deaf (Visual + Haptic)'),
                    selected: a11y.preset == AccessibilityPreset.deafVisualHaptic,
                    onSelected: (_) => a11y.applyPreset(AccessibilityPreset.deafVisualHaptic),
                  ),
                  ChoiceChip(
                    label: Text(widget.isArabic ? 'إعاقة حركية (أوامر صوتية + أزرار 64dp)' : 'Motor (Hands-Free + 64dp)'),
                    selected: a11y.preset == AccessibilityPreset.motorHandsFreeVoice,
                    onSelected: (_) => a11y.applyPreset(AccessibilityPreset.motorHandsFreeVoice),
                  ),
                  ChoiceChip(
                    label: Text(widget.isArabic ? 'وضع مبسّط (خطوة بخطوة)' : 'Simplified Mode'),
                    selected: a11y.preset == AccessibilityPreset.cognitiveSimplified,
                    onSelected: (_) => a11y.applyPreset(AccessibilityPreset.cognitiveSimplified),
                  ),
                ],
              ),
              const Divider(height: 28),
              Text(
                widget.isArabic ? 'وحدة التحكم بالأوامر الصوتية (مع التأكيد المزدوج المالي)' : 'Voice Command Console (2-Step Financial Guard)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _voiceInputCtrl,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.mic),
                  hintText: widget.isArabic ? 'مثال: سند قبض 250 دولار، أو: كم رصيد الصندوق؟' : 'e.g., Receipt 250 USD, or: Check balance',
                ),
                onSubmitted: _handleVoiceSubmit,
              ),
              const SizedBox(height: 10),
              MizanAccessibleButton(
                a11y: a11y,
                icon: Icons.record_voice_over,
                label: widget.isArabic ? 'تنفيذ الأمر الصوتي' : 'Run Voice Command',
                semanticHint: widget.isArabic ? 'يحلل الأمر الصوتي ويطلب تأكيدك قبل أي ترحيل مالي' : 'Parses voice command safely',
                onPressed: () => _handleVoiceSubmit(_voiceInputCtrl.text),
              ),
              if (_pendingDraft != null) ...[
                const SizedBox(height: 16),
                Card(
                  color: Colors.amber.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        MizanColorBlindSafeBadge(
                          statusText: widget.isArabic ? 'مسودة مالية صوتية بانتظار تأكيدك الصريح' : 'Pending Voice Financial Draft',
                          isPositive: false,
                          isNeutral: true,
                        ),
                        const SizedBox(height: 8),
                        Text('النص: ${_pendingDraft!.normalizedTranscript}'),
                        Text('المبلغ: ${((_pendingDraft!.amountMinor ?? 0) / 10000).toStringAsFixed(2)} ${_pendingDraft!.currency}'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: MizanAccessibleButton(
                                a11y: a11y,
                                icon: Icons.check_circle,
                                label: widget.isArabic ? 'تأكيد الترحيل' : 'Confirm Post',
                                semanticHint: 'تأكيد نهائي لترحيل العملية المالية',
                                onPressed: () => _handleVoiceSubmit('تأكيد الترحيل'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.cancel_outlined),
                                label: Text(widget.isArabic ? 'إلغاء' : 'Cancel'),
                                onPressed: () => _handleVoiceSubmit('إلغاء'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
