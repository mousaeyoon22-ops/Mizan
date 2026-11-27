import 'package:flutter/material.dart';

enum WorkspaceExperienceMode {
  easy,          // الوضع السهل
  standard,      // الوضع العادي
  professional,  // الوضع الاحترافي المحاسبي
  executive,     // الوضع التنفيذي (لوحة الإدارة)
  expressField,  // وضع الميدان والتوزيع السريع
}

class WorkspaceModeProfile {
  final WorkspaceExperienceMode mode;
  final String titleAr;
  final String titleEn;
  final String subtitleAr;
  final double cardPadding;
  final bool showAccountingCodes;
  final bool showDebitCreditColumns;
  final bool showBaseCurrencyColumns;
  final bool showFifoAndCost;
  final bool showSha256AuditHash;
  final bool showKpiBranchGrid;
  final bool useSimpleTradeTerms;
  final bool hideEmptyPrintRows;

  const WorkspaceModeProfile({
    required this.mode,
    required this.titleAr,
    required this.titleEn,
    required this.subtitleAr,
    required this.cardPadding,
    required this.showAccountingCodes,
    required this.showDebitCreditColumns,
    required this.showBaseCurrencyColumns,
    required this.showFifoAndCost,
    required this.showSha256AuditHash,
    required this.showKpiBranchGrid,
    required this.useSimpleTradeTerms,
    this.hideEmptyPrintRows = true,
  });
}

/// Reactive controller switching BOTH the visual shape of the workspace AND data granularity,
/// while strictly clamping against the user's RBAC role ceiling.
class WorkspaceModeController extends ChangeNotifier {
  WorkspaceExperienceMode _mode = WorkspaceExperienceMode.standard;
  String _activeRole = 'OWNER';
  bool _hideEmptyPrintRows = true;

  static const Map<String, List<WorkspaceExperienceMode>> _roleCeiling = {
    'OWNER': WorkspaceExperienceMode.values,
    'ACCOUNTANT': [
      WorkspaceExperienceMode.easy,
      WorkspaceExperienceMode.standard,
      WorkspaceExperienceMode.professional,
      WorkspaceExperienceMode.executive,
    ],
    'AUDITOR': [
      WorkspaceExperienceMode.standard,
      WorkspaceExperienceMode.professional,
      WorkspaceExperienceMode.executive,
    ],
    'CASHIER': [
      WorkspaceExperienceMode.easy,
      WorkspaceExperienceMode.standard,
      WorkspaceExperienceMode.expressField,
    ],
    'DRIVER': [
      WorkspaceExperienceMode.easy,
      WorkspaceExperienceMode.expressField,
    ],
  };

  static const Map<WorkspaceExperienceMode, WorkspaceModeProfile> profiles = {
    WorkspaceExperienceMode.easy: WorkspaceModeProfile(
      mode: WorkspaceExperienceMode.easy,
      titleAr: 'الوضع السهل',
      titleEn: 'Easy Mode',
      subtitleAr: 'بطاقات كبيرة، 3 أزرار رئيسية فقط، ومصطلحات بسيطة (لك / عليك) دون تعقيد محاسبي.',
      cardPadding: 20,
      showAccountingCodes: false,
      showDebitCreditColumns: false,
      showBaseCurrencyColumns: false,
      showFifoAndCost: false,
      showSha256AuditHash: false,
      showKpiBranchGrid: false,
      useSimpleTradeTerms: true,
    ),
    WorkspaceExperienceMode.standard: WorkspaceModeProfile(
      mode: WorkspaceExperienceMode.standard,
      titleAr: 'الوضع العادي',
      titleEn: 'Standard Mode',
      subtitleAr: 'عرض متوازن للفواتير، الأرصدة، المخزون، الأبواب التجارية، وتقارير A4 نظيفة.',
      cardPadding: 14,
      showAccountingCodes: false,
      showDebitCreditColumns: false,
      showBaseCurrencyColumns: false,
      showFifoAndCost: false,
      showSha256AuditHash: false,
      showKpiBranchGrid: false,
      useSimpleTradeTerms: false,
    ),
    WorkspaceExperienceMode.professional: WorkspaceModeProfile(
      mode: WorkspaceExperienceMode.professional,
      titleAr: 'الوضع الاحترافي',
      titleEn: 'Professional Mode',
      subtitleAr: 'جداول مالية كثيفة، شجرة الحسابات، أعمدة مدين/دائن، العملة الأساسية، FIFO، وبصمة SHA-256.',
      cardPadding: 8,
      showAccountingCodes: true,
      showDebitCreditColumns: true,
      showBaseCurrencyColumns: true,
      showFifoAndCost: true,
      showSha256AuditHash: true,
      showKpiBranchGrid: false,
      useSimpleTradeTerms: false,
    ),
    WorkspaceExperienceMode.executive: WorkspaceModeProfile(
      mode: WorkspaceExperienceMode.executive,
      titleAr: 'الوضع التنفيذي',
      titleEn: 'Executive Mode',
      subtitleAr: 'مؤشرات الأداء KPI، مقارنة الفروع والورديات، وتنبيهات الفروقات والذمم المتأخرة فقط.',
      cardPadding: 14,
      showAccountingCodes: false,
      showDebitCreditColumns: false,
      showBaseCurrencyColumns: true,
      showFifoAndCost: false,
      showSha256AuditHash: false,
      showKpiBranchGrid: true,
      useSimpleTradeTerms: false,
    ),
    WorkspaceExperienceMode.expressField: WorkspaceModeProfile(
      mode: WorkspaceExperienceMode.expressField,
      titleAr: 'وضع الميدان السريع',
      titleEn: 'Express Field Mode',
      subtitleAr: 'شاشة عمل سريعة بيد واحدة للموزعين: عهدة المركبة، التسليم الفوري، وطابور الأوفلاين.',
      cardPadding: 18,
      showAccountingCodes: false,
      showDebitCreditColumns: false,
      showBaseCurrencyColumns: false,
      showFifoAndCost: false,
      showSha256AuditHash: false,
      showKpiBranchGrid: false,
      useSimpleTradeTerms: true,
    ),
  };

  WorkspaceExperienceMode get currentMode => _mode;
  WorkspaceModeProfile get currentProfile => profiles[_mode]!;
  bool get hideEmptyPrintRows => _hideEmptyPrintRows;
  List<WorkspaceExperienceMode> get allowedModesForRole =>
      _roleCeiling[_activeRole] ?? const [WorkspaceExperienceMode.easy];

  void setRole(String role) {
    _activeRole = role.toUpperCase();
    if (!allowedModesForRole.contains(_mode)) {
      _mode = allowedModesForRole.first;
    }
    notifyListeners();
  }

  /// Returns null on success, or error code if role ceiling blocks the requested mode.
  String? switchMode(WorkspaceExperienceMode target) {
    if (!allowedModesForRole.contains(target)) {
      return 'RBAC_CEILING_BLOCKED_${target.name}_FOR_$_activeRole';
    }
    _mode = target;
    notifyListeners();
    return null;
  }

  void setHideEmptyPrintRows(bool value) {
    _hideEmptyPrintRows = value;
    notifyListeners();
  }

  /// Dynamic Terminology Mapper: same underlying Double-Entry ledger, human-adapted labels.
  String term(String key, {bool isArabic = true}) {
    final simple = currentProfile.useSimpleTradeTerms;
    final strict = _mode == WorkspaceExperienceMode.professional;
    if (!isArabic) {
      if (key == 'ar') return simple ? 'Owed to Me' : (strict ? 'Accounts Receivable (1120)' : 'Receivables');
      if (key == 'ap') return simple ? 'Owed by Me' : (strict ? 'Accounts Payable (2110)' : 'Payables');
      if (key == 'cash') return simple ? 'Cash in Hand' : (strict ? 'Cash & Equivalents (1110)' : 'Cash Box');
      return key;
    }
    switch (key) {
      case 'ar':
        return simple ? 'لك عند العملاء' : (strict ? 'الذمم المدينة — ح/1120 (مدين)' : 'الذمم المدينة');
      case 'ap':
        return simple ? 'عليك للموردين' : (strict ? 'الذمم الدائنة — ح/2110 (دائن)' : 'الذمم الدائنة');
      case 'cash':
        return simple ? 'النقد في الصندوق' : (strict ? 'النقدية والصناديق — ح/1110' : 'رصيد الصندوق');
      case 'advance':
        return simple ? 'عربون / دفعة مقدمة' : (strict ? 'التزام عقدي (IFRS 15) — ح/2130' : 'دفعات العملاء المقدمة');
      default:
        return key;
    }
  }
}
