/// Deterministic 4-Factor Workspace Resolver:
/// 1) Active Context (Personal vs Organization)
/// 2) User Role inside Organization (OWNER, ACCOUNTANT, CASHIER, DRIVER, AUDITOR)
/// 3) Active Operational Feature Flags (POS_MULTI_CASHIER_TOUCH, POS_SHIFTS_AND_Z_REPORT, ITEM_VARIANTS_MATRIX)
/// 4) Screen Width Breakpoint (>= 900px = Split-Screen Touch POS / Tablet / Desktop; < 900px = Mobile)
enum ActiveContextType { personal, organization }
enum OrgRole { owner, accountant, cashier, driver, auditor }
enum WorkspaceMode {
  personalBudgetAndQr,
  smallShopMobile,
  touchSplitScreenPos,
  mallExecutiveDashboard,
  fieldDriverOffline,
}

class WorkspaceResolution {
  final WorkspaceMode primaryMode;
  final bool useSplitScreenLayout;
  final bool showFinancialReports;
  final bool showPosShifts;
  final bool showVariantsMatrix;
  final bool showAdminSettings;

  const WorkspaceResolution({
    required this.primaryMode,
    required this.useSplitScreenLayout,
    required this.showFinancialReports,
    required this.showPosShifts,
    required this.showVariantsMatrix,
    required this.showAdminSettings,
  });
}

class AdaptiveWorkspaceResolver {
  static const double splitScreenBreakpointPx = 900.0;

  static WorkspaceResolution resolve({
    required ActiveContextType contextType,
    OrgRole? role,
    required double screenWidthPx,
    required bool posTouchEnabled,
    required bool posShiftsEnabled,
    required bool variantsMatrixEnabled,
  }) {
    if (contextType == ActiveContextType.personal || role == null) {
      return const WorkspaceResolution(
        primaryMode: WorkspaceMode.personalBudgetAndQr,
        useSplitScreenLayout: false,
        showFinancialReports: false,
        showPosShifts: false,
        showVariantsMatrix: false,
        showAdminSettings: false,
      );
    }

    final isWideTouch = screenWidthPx >= splitScreenBreakpointPx;

    switch (role) {
      case OrgRole.cashier:
        return WorkspaceResolution(
          primaryMode: posTouchEnabled ? WorkspaceMode.touchSplitScreenPos : WorkspaceMode.smallShopMobile,
          useSplitScreenLayout: posTouchEnabled && isWideTouch,
          showFinancialReports: false, // Strictly hidden from cashiers
          showPosShifts: posTouchEnabled && posShiftsEnabled,
          showVariantsMatrix: variantsMatrixEnabled,
          showAdminSettings: false,
        );

      case OrgRole.driver:
        return const WorkspaceResolution(
          primaryMode: WorkspaceMode.fieldDriverOffline,
          useSplitScreenLayout: false,
          showFinancialReports: false,
          showPosShifts: false,
          showVariantsMatrix: false,
          showAdminSettings: false,
        );

      case OrgRole.owner:
      case OrgRole.accountant:
      case OrgRole.auditor:
        final isMallExecutive = posTouchEnabled && posShiftsEnabled;
        return WorkspaceResolution(
          primaryMode: isMallExecutive ? WorkspaceMode.mallExecutiveDashboard : WorkspaceMode.smallShopMobile,
          useSplitScreenLayout: isWideTouch && posTouchEnabled,
          showFinancialReports: true,
          showPosShifts: posTouchEnabled && posShiftsEnabled,
          showVariantsMatrix: variantsMatrixEnabled,
          showAdminSettings: role == OrgRole.owner,
        );
    }
  }
}
