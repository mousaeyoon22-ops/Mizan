import 'package:flutter/foundation.dart';

class FeatureItem {
  final String key;
  final String category;
  final int releasePhase;
  final bool isImmutableCore;
  final bool platformEnabled;
  final bool orgConfigurable;
  final bool effectiveEnabled;
  final String? requiresFeature;
  final String titleAr;
  final String titleEn;

  const FeatureItem({
    required this.key,
    required this.category,
    required this.releasePhase,
    required this.isImmutableCore,
    required this.platformEnabled,
    required this.orgConfigurable,
    required this.effectiveEnabled,
    this.requiresFeature,
    required this.titleAr,
    required this.titleEn,
  });

  bool get canUserToggle => !isImmutableCore && platformEnabled && orgConfigurable;

  FeatureItem copyWith({bool? effectiveEnabled}) => FeatureItem(
        key: key,
        category: category,
        releasePhase: releasePhase,
        isImmutableCore: isImmutableCore,
        platformEnabled: platformEnabled,
        orgConfigurable: orgConfigurable,
        effectiveEnabled: effectiveEnabled ?? this.effectiveEnabled,
        requiresFeature: requiresFeature,
        titleAr: titleAr,
        titleEn: titleEn,
      );
}

/// Reactive Flutter controller mirroring server-side `FeatureGovernanceService`.
/// Store-Compliance Rule: Any feature with `effectiveEnabled == false` is cleanly hidden
/// from main navigation/checkout screens (zero dead "Coming Soon" buttons).
class FeatureFlagController extends ChangeNotifier {
  final Map<String, FeatureItem> _flags;

  FeatureFlagController(List<FeatureItem> initial)
      : _flags = {for (final f in initial) f.key: f};

  bool isEnabled(String key) => _flags[key]?.effectiveEnabled ?? false;

  List<FeatureItem> get allFeatures => _flags.values.toList();

  /// Returns only toggles valid for the organization in the current release phase
  /// (App Store & Google Play compliant: never shows broken locked toggles as active buttons).
  List<FeatureItem> get configurableInCurrentPhase =>
      _flags.values.where((f) => f.platformEnabled && f.orgConfigurable).toList();

  List<FeatureItem> get upcomingPlatformExtensions =>
      _flags.values.where((f) => !f.platformEnabled).toList();

  String? toggleLocalPreference(String key, bool desiredState) {
    final item = _flags[key];
    if (item == null) return 'UNKNOWN_FEATURE';
    if (item.isImmutableCore && !desiredState) return 'CORE_FEATURE_IMMUTABLE';
    if (desiredState && !item.canUserToggle) return 'FEATURE_LOCKED_BY_PLATFORM';

    if (desiredState && item.requiresFeature != null && !isEnabled(item.requiresFeature!)) {
      return 'FEATURE_DEPENDENCY_MISSING:${item.requiresFeature}';
    }

    _flags[key] = item.copyWith(effectiveEnabled: desiredState);

    // Cascade OFF if dependent features rely on this key
    if (!desiredState) {
      for (final other in _flags.values.toList()) {
        if (other.requiresFeature == key && other.effectiveEnabled) {
          _flags[other.key] = other.copyWith(effectiveEnabled: false);
        }
      }
    }
    notifyListeners();
    return null;
  }
}
