import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/accessibility/accessibility_profile_controller.dart';
import 'core/features/feature_flag_controller.dart';
import 'core/l10n/mizan_localizations.dart';
import 'core/workspace/workspace_mode_controller.dart';
import 'presentation/screens/accessibility_and_voice_settings_screen.dart';
import 'presentation/screens/adaptive_workspace_screen.dart';
import 'presentation/screens/cashier_shift_z_report_screen.dart';
import 'presentation/screens/daily_a4_report_preview_screen.dart';
import 'presentation/screens/fx_exchange_voucher_screen.dart';
import 'presentation/screens/login_onboarding_screen.dart';
import 'presentation/screens/nearby_stores_screen.dart';
import 'presentation/screens/operational_preferences_screen.dart';
import 'presentation/screens/qr_live_cart_screen.dart';
import 'presentation/screens/split_screen_pos_screen.dart';
import 'presentation/screens/trade_gates_screen.dart';
import 'presentation/screens/workspace_mode_selector_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MizanRootApp());
}

List<FeatureItem> _buildAll25UnifiedFeatures() => const [
      FeatureItem(key: 'CORE_DOUBLE_ENTRY_LEDGER', category: 'CORE', releasePhase: 1, isImmutableCore: true, platformEnabled: true, orgConfigurable: false, effectiveEnabled: true, titleAr: 'المحرك المحاسبي للقيد المزدوج (IFRS 15 & IAS 2)', titleEn: 'Core Double-Entry Ledger'),
      FeatureItem(key: 'OFFLINE_SQLITE_OUTBOX', category: 'CORE', releasePhase: 1, isImmutableCore: true, platformEnabled: true, orgConfigurable: false, effectiveEnabled: true, titleAr: 'العمل دون إنترنت وطابور المزامنة المشفّر', titleEn: 'Offline SQLite Outbox'),
      FeatureItem(key: 'ACCESSIBILITY_INCLUSIVE_MODE', category: 'CORE', releasePhase: 1, isImmutableCore: true, platformEnabled: true, orgConfigurable: false, effectiveEnabled: true, titleAr: 'دعم ذوي الهمم والاحتياجات الخاصة (WCAG 2.2 AA)', titleEn: 'Inclusive Accessibility Suite'),
      FeatureItem(key: 'TRADE_GATES_EXCHANGE', category: 'CORE', releasePhase: 1, isImmutableCore: false, platformEnabled: true, orgConfigurable: true, effectiveEnabled: true, requiresFeature: 'CORE_DOUBLE_ENTRY_LEDGER', titleAr: 'الأبواب التجارية وتبادل المستندات', titleEn: 'Trade Gates Exchange'),
      FeatureItem(key: 'QR_CATALOG_SELF_CHECKOUT', category: 'COMMERCE', releasePhase: 1, isImmutableCore: false, platformEnabled: true, orgConfigurable: true, effectiveEnabled: true, requiresFeature: 'CORE_DOUBLE_ENTRY_LEDGER', titleAr: 'الكتالوج التفاعلي عبر QR والسلة الحية', titleEn: 'QR Live Cart'),
      FeatureItem(key: 'MULTI_LANGUAGE_UI', category: 'CORE', releasePhase: 1, isImmutableCore: false, platformEnabled: true, orgConfigurable: true, effectiveEnabled: true, titleAr: 'تعدد اللغات (RTL/LTR)', titleEn: 'Multi-Language UI'),
      FeatureItem(key: 'MULTI_CURRENCY_LEDGER', category: 'CORE', releasePhase: 1, isImmutableCore: false, platformEnabled: true, orgConfigurable: true, effectiveEnabled: true, requiresFeature: 'CORE_DOUBLE_ENTRY_LEDGER', titleAr: 'تعدد العملات وأسعار الصرف', titleEn: 'Multi-Currency Ledger'),
      FeatureItem(key: 'FX_IAS21_GAIN_LOSS_ENGINE', category: 'CORE', releasePhase: 1, isImmutableCore: false, platformEnabled: true, orgConfigurable: true, effectiveEnabled: true, requiresFeature: 'MULTI_CURRENCY_LEDGER', titleAr: 'محرك فروقات العملة (IAS 21)', titleEn: 'IAS 21 FX Engine'),
      FeatureItem(key: 'DIRECT_CURRENCY_EXCHANGE_VOUCHER', category: 'CORE', releasePhase: 1, isImmutableCore: false, platformEnabled: true, orgConfigurable: true, effectiveEnabled: true, requiresFeature: 'FX_IAS21_GAIN_LOSS_ENGINE', titleAr: 'سندات المصارفة المباشرة وتحويل الصناديق', titleEn: 'Direct Currency Exchange'),
      FeatureItem(key: 'WORKSPACE_EXPERIENCE_MODES', category: 'CORE', releasePhase: 1, isImmutableCore: false, platformEnabled: true, orgConfigurable: true, effectiveEnabled: true, requiresFeature: 'CORE_DOUBLE_ENTRY_LEDGER', titleAr: 'أوضاع شاشة العرض (سهل / عادي / احترافي / تنفيذي / ميداني)', titleEn: 'Workspace Experience Modes'),
      FeatureItem(key: 'CONTEXTUAL_TRANSACTION_CHAT', category: 'COMMERCE', releasePhase: 1, isImmutableCore: false, platformEnabled: true, orgConfigurable: true, effectiveEnabled: false, requiresFeature: 'TRADE_GATES_EXCHANGE', titleAr: 'الدردشة التوافقية وأرشفتها القانونية', titleEn: 'Contextual Transaction Chat'),
      FeatureItem(key: 'PUBLIC_NEARBY_DIRECTORY', category: 'COMMERCE', releasePhase: 1, isImmutableCore: false, platformEnabled: true, orgConfigurable: true, effectiveEnabled: false, requiresFeature: 'QR_CATALOG_SELF_CHECKOUT', titleAr: 'دليل المتاجر والخدمات القريبة', titleEn: 'Nearby Stores Directory'),
      FeatureItem(key: 'BLIND_MUTUAL_RATINGS', category: 'COMMERCE', releasePhase: 1, isImmutableCore: false, platformEnabled: true, orgConfigurable: true, effectiveEnabled: false, requiresFeature: 'QR_CATALOG_SELF_CHECKOUT', titleAr: 'التقييم الأعمى المتبادل', titleEn: 'Double-Blind Ratings'),
      FeatureItem(key: 'PERISHABLE_LIVE_CAM_DISPUTES', category: 'COMMERCE', releasePhase: 1, isImmutableCore: false, platformEnabled: true, orgConfigurable: true, effectiveEnabled: false, requiresFeature: 'QR_CATALOG_SELF_CHECKOUT', titleAr: 'توثيق تلف السلع بالكاميرا الحية فقط', titleEn: 'Live-Cam Perishable Disputes'),
      FeatureItem(key: 'POS_MULTI_CASHIER_TOUCH', category: 'COMMERCE', releasePhase: 1, isImmutableCore: false, platformEnabled: true, orgConfigurable: true, effectiveEnabled: false, requiresFeature: 'CORE_DOUBLE_ENTRY_LEDGER', titleAr: 'وحدة الكاشير المتعدد وشاشة اللمس المنقسمة (POS)', titleEn: 'Multi-Cashier Touch POS'),
      FeatureItem(key: 'POS_SHIFTS_AND_Z_REPORT', category: 'COMMERCE', releasePhase: 1, isImmutableCore: false, platformEnabled: true, orgConfigurable: true, effectiveEnabled: false, requiresFeature: 'POS_MULTI_CASHIER_TOUCH', titleAr: 'إدارة ورديات الكاشير وتقارير Z-Report', titleEn: 'POS Shifts & Blind Z-Reports'),
      FeatureItem(key: 'ITEM_VARIANTS_MATRIX', category: 'COMMERCE', releasePhase: 1, isImmutableCore: false, platformEnabled: true, orgConfigurable: true, effectiveEnabled: false, requiresFeature: 'CORE_DOUBLE_ENTRY_LEDGER', titleAr: 'مصفوفة المقاسات والألوان والباركود', titleEn: 'Item Variants Matrix'),
      FeatureItem(key: 'VOICE_COMMAND_OPERATIONS', category: 'CORE', releasePhase: 1, isImmutableCore: false, platformEnabled: true, orgConfigurable: true, effectiveEnabled: false, requiresFeature: 'ACCESSIBILITY_INCLUSIVE_MODE', titleAr: 'التشغيل والعمل بالأوامر الصوتية (مع تأكيد مزدوج)', titleEn: 'Voice Command Operations'),
      FeatureItem(key: 'KYC_STRICT_TIERS_2_TO_4', category: 'COMPLIANCE', releasePhase: 2, isImmutableCore: false, platformEnabled: false, orgConfigurable: true, effectiveEnabled: false, titleAr: 'التحقق المتدرج KYC (المستويات 2-4)', titleEn: 'Tiered KYC Levels 2-4'),
      FeatureItem(key: 'PSP_PASS_THROUGH_PREAUTH', category: 'FINTECH', releasePhase: 2, isImmutableCore: false, platformEnabled: false, orgConfigurable: true, effectiveEnabled: false, requiresFeature: 'KYC_STRICT_TIERS_2_TO_4', titleAr: 'بوابة الدفع التمريرية بالتفويض المسبق', titleEn: 'Pass-Through PSP Pre-Auth'),
      FeatureItem(key: 'TAX_EINVOICING_PEPPOL_ZATCA', category: 'COMPLIANCE', releasePhase: 2, isImmutableCore: false, platformEnabled: false, orgConfigurable: true, effectiveEnabled: false, requiresFeature: 'CORE_DOUBLE_ENTRY_LEDGER', titleAr: 'الفوترة الإلكترونية UBL 2.1 / Peppol', titleEn: 'Tax E-Invoicing'),
      FeatureItem(key: 'INSTANT_CROSS_BORDER_TRANSLATION', category: 'AI', releasePhase: 2, isImmutableCore: false, platformEnabled: false, orgConfigurable: true, effectiveEnabled: false, requiresFeature: 'MULTI_LANGUAGE_UI', titleAr: 'المترجم الفوري عبر الحدود', titleEn: 'Instant Cross-Border Translation'),
      FeatureItem(key: 'ERP_CONNECTORS_OAUTH', category: 'INTEGRATION', releasePhase: 3, isImmutableCore: false, platformEnabled: false, orgConfigurable: true, effectiveEnabled: false, requiresFeature: 'TRADE_GATES_EXCHANGE', titleAr: 'موصلات QuickBooks وXero وOdoo وSAP', titleEn: 'External ERP Connectors'),
      FeatureItem(key: 'AI_FINANCIAL_COPILOT_OCR', category: 'AI', releasePhase: 3, isImmutableCore: false, platformEnabled: false, orgConfigurable: true, effectiveEnabled: false, requiresFeature: 'CORE_DOUBLE_ENTRY_LEDGER', titleAr: 'المساعد الذكي وقراءة الفواتير OCR', titleEn: 'AI Copilot & OCR'),
      FeatureItem(key: 'INTERNAL_WALLET_CUSTODY', category: 'FINTECH', releasePhase: 3, isImmutableCore: false, platformEnabled: false, orgConfigurable: false, effectiveEnabled: false, requiresFeature: 'KYC_STRICT_TIERS_2_TO_4', titleAr: 'المحفظة المالية الداخلية (يتطلب ترخيصاً)', titleEn: 'Internal Custody Wallet'),
    ];

class MizanRootApp extends StatefulWidget {
  const MizanRootApp({super.key});

  @override
  State<MizanRootApp> createState() => _MizanRootAppState();
}

class _MizanRootAppState extends State<MizanRootApp> {
  Locale _locale = const Locale('ar');
  bool _authenticated = false;
  int _tabIndex = 0;
  late final FeatureFlagController _features;
  late final AccessibilityProfileController _a11y;
  late final WorkspaceModeController _workspace;

  @override
  void initState() {
    super.initState();
    _features = FeatureFlagController(_buildAll25UnifiedFeatures());
    _a11y = AccessibilityProfileController();
    _workspace = WorkspaceModeController();
  }

  @override
  Widget build(BuildContext context) {
    final s = MizanStrings(_locale);
    final baseTheme = ThemeData(colorSchemeSeed: const Color(0xFF0F766E), useMaterial3: true);

    return AnimatedBuilder(
      animation: Listenable.merge([_features, _a11y, _workspace]),
      builder: (context, _) {
        // FIX DEF-306: Strictly guarantee destinations.length == screens.length (max 5 bottom tabs; overflow moves to Hub)
        final tabs = <({NavigationDestination dest, Widget screen})>[
          (
            dest: NavigationDestination(icon: const Icon(Icons.dashboard_outlined), label: s.isRtl ? 'العمل' : 'Work'),
            screen: AdaptiveWorkspaceScreen(controller: _workspace, isArabic: s.isRtl),
          ),
        ];

        if (_features.isEnabled('POS_MULTI_CASHIER_TOUCH')) {
          tabs.add((
            dest: const NavigationDestination(icon: Icon(Icons.point_of_sale), label: 'POS'),
            screen: SplitScreenPosScreen(isArabic: s.isRtl, variantsMatrixEnabled: _features.isEnabled('ITEM_VARIANTS_MATRIX')),
          ));
        } else if (_features.isEnabled('QR_CATALOG_SELF_CHECKOUT')) {
          tabs.add((
            dest: const NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'QR'),
            screen: QrLiveCartScreen(strings: s),
          ));
        }

        if (_features.isEnabled('TRADE_GATES_EXCHANGE') && tabs.length < 4) {
          tabs.add((
            dest: NavigationDestination(icon: const Icon(Icons.swap_horiz_rounded), label: s.isRtl ? 'الأبواب' : 'Gates'),
            screen: TradeGatesScreen(strings: s),
          ));
        }

        if (_features.isEnabled('DIRECT_CURRENCY_EXCHANGE_VOUCHER') && tabs.length < 4) {
          tabs.add((
            dest: NavigationDestination(icon: const Icon(Icons.currency_exchange), label: s.isRtl ? 'المصارفة' : 'FX'),
            screen: FxExchangeVoucherScreen(isArabic: s.isRtl),
          ));
        }

        // Always pin the unified Modules & Preferences Hub as the final tab (never truncated!)
        tabs.add((
          dest: NavigationDestination(icon: const Icon(Icons.tune), label: s.isRtl ? 'المزيد' : 'More'),
          screen: _UnifiedHubScreen(
            strings: s,
            features: _features,
            a11y: _a11y,
            workspace: _workspace,
            onToggleLocale: () => setState(() => _locale = _locale.languageCode == 'ar' ? const Locale('en') : const Locale('ar')),
            onSignOut: () => setState(() => _authenticated = false),
          ),
        ));

        final safeIndex = _tabIndex >= tabs.length ? 0 : _tabIndex;

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: s.t('app_title'),
          locale: _locale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: _a11y.buildAccessibleTheme(baseTheme),
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(ctx).copyWith(textScaler: TextScaler.linear(_a11y.fontScale)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: Directionality(
            textDirection: s.isRtl ? TextDirection.rtl : TextDirection.ltr,
            child: !_authenticated
                ? LoginOnboardingScreen(
                    isArabic: s.isRtl,
                    onAuthenticated: (_, role) {
                      _workspace.setRole(role);
                      setState(() => _authenticated = true);
                    },
                  )
                : Scaffold(
                    body: IndexedStack(index: safeIndex, children: tabs.map((t) => t.screen).toList()),
                    bottomNavigationBar: NavigationBar(
                      selectedIndex: safeIndex,
                      onDestinationSelected: (i) => setState(() => _tabIndex = i),
                      destinations: tabs.map((t) => t.dest).toList(),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _UnifiedHubScreen extends StatelessWidget {
  final MizanStrings strings;
  final FeatureFlagController features;
  final AccessibilityProfileController a11y;
  final WorkspaceModeController workspace;
  final VoidCallback onToggleLocale;
  final VoidCallback onSignOut;

  const _UnifiedHubScreen({
    required this.strings,
    required this.features,
    required this.a11y,
    required this.workspace,
    required this.onToggleLocale,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    final ar = strings.isRtl;
    return Scaffold(
      appBar: AppBar(
        title: Text(ar ? 'الوحدات والتفضيلات — ميزان v2.1' : 'Modules & Preferences — Mizan v2.1'),
        actions: [
          TextButton(onPressed: onToggleLocale, child: Text(ar ? 'EN' : 'عربي')),
          IconButton(icon: const Icon(Icons.logout), onPressed: onSignOut),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.print_outlined),
            title: Text(ar ? 'معاينة وطباعة التقرير اليومي A4 (نظيف)' : 'Clean A4 Daily Financial Report'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DailyA4ReportPreviewScreen(isArabic: ar, hideEmptyRows: workspace.hideEmptyPrintRows))),
          ),
          if (features.isEnabled('POS_SHIFTS_AND_Z_REPORT'))
            ListTile(
              leading: const Icon(Icons.lock_clock),
              title: Text(ar ? 'وردية الكاشير وتقرير Z-Report الأعمى' : 'Cashier Shift & Blind Z-Report'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CashierShiftZReportScreen(isArabic: ar))),
            ),
          if (features.isEnabled('PUBLIC_NEARBY_DIRECTORY'))
            ListTile(
              leading: const Icon(Icons.location_on_outlined),
              title: Text(ar ? 'دليل المتاجر والخدمات القريبة' : 'Nearby Stores Directory'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => NearbyStoresScreen(strings: strings))),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.dashboard_customize_outlined),
            title: Text(ar ? 'أوضاع شاشة العرض والعمل (5 أوضاع)' : 'Workspace Experience Modes (5 Modes)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => WorkspaceModeSelectorScreen(controller: workspace, isArabic: ar))),
          ),
          ListTile(
            leading: const Icon(Icons.accessibility_new),
            title: Text(ar ? 'تمكين ذوي الهمم (WCAG 2.2) والأوامر الصوتية' : 'Inclusive Accessibility & Voice Commands'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccessibilityAndVoiceSettingsScreen(controller: a11y, isArabic: ar))),
          ),
          ListTile(
            leading: const Icon(Icons.toggle_on_outlined),
            title: Text(ar ? 'التفضيلات التشغيلية والوحدات (25 وحدة)' : 'Operational Feature Modules (25 Flags)'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => OperationalPreferencesScreen(controller: features, isArabic: ar))),
          ),
        ],
      ),
    );
  }
}
