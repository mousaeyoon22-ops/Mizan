-- ============================================================================
-- MIZAN (ميزان) — Migration 008: Adaptive Workspace Experience Modes
-- Modes: EASY | STANDARD | PROFESSIONAL | EXECUTIVE | EXPRESS_FIELD
-- Security Invariant: Experience Mode NEVER escalates Role Permissions (RBAC)
-- ============================================================================

-- 1) Per-User, Per-Org Workspace Display Mode & Widget/Column Preferences
CREATE TABLE user_workspace_preferences (
    user_id                 UUID NOT NULL REFERENCES users(id),
    org_id                  UUID NOT NULL REFERENCES organizations(id),
    experience_mode         VARCHAR(24) NOT NULL DEFAULT 'STANDARD' CHECK (experience_mode IN (
                                'EASY', 'STANDARD', 'PROFESSIONAL', 'EXECUTIVE', 'EXPRESS_FIELD'
                            )),
    terminology_style       VARCHAR(16) NOT NULL DEFAULT 'BALANCED' CHECK (terminology_style IN (
                                'SIMPLE_TRADE', 'BALANCED', 'STRICT_ACCOUNTING'
                            )),
    ui_density              VARCHAR(16) NOT NULL DEFAULT 'COMFORTABLE' CHECK (ui_density IN (
                                'SPACIOUS', 'COMFORTABLE', 'COMPACT'
                            )),
    hide_empty_print_rows   BOOLEAN NOT NULL DEFAULT TRUE, -- Clean A4 printable reports with zero empty rows
    custom_widgets_json     JSONB NOT NULL DEFAULT '{}'::jsonb,
    custom_columns_json     JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, org_id)
);

-- 2) Organization-Level Role Mode Policy (Allows Owner to lock Cashiers/Drivers to a specific mode)
CREATE TABLE org_role_mode_policies (
    org_id                  UUID NOT NULL REFERENCES organizations(id),
    role                    VARCHAR(32) NOT NULL CHECK (role IN ('OWNER', 'ACCOUNTANT', 'CASHIER', 'DRIVER', 'AUDITOR')),
    default_mode            VARCHAR(24) NOT NULL CHECK (default_mode IN (
                                'EASY', 'STANDARD', 'PROFESSIONAL', 'EXECUTIVE', 'EXPRESS_FIELD'
                            )),
    allow_user_override     BOOLEAN NOT NULL DEFAULT TRUE,
    allowed_modes_json      JSONB NOT NULL DEFAULT '["EASY","STANDARD"]'::jsonb,
    updated_by              UUID NOT NULL REFERENCES users(id),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (org_id, role)
);

-- 3) Row-Level Security (RLS)
ALTER TABLE user_workspace_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE org_role_mode_policies ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_user_workspace_prefs ON user_workspace_preferences
    USING (
        org_id = current_setting('app.current_org_id', true)::UUID
        AND user_id = current_setting('app.current_user_id', true)::UUID
    );

CREATE POLICY tenant_isolation_org_role_mode_policies ON org_role_mode_policies
    USING (org_id = current_setting('app.current_org_id', true)::UUID);

-- 4) Register Feature Flag #25 in Platform Governance Registry
INSERT INTO platform_feature_registry
(feature_key, category, release_phase, is_immutable_core, platform_enabled, org_configurable, default_org_state, requires_feature, description_ar, description_en)
VALUES
('WORKSPACE_EXPERIENCE_MODES', 'CORE', 1, FALSE, TRUE, TRUE, TRUE, 'CORE_DOUBLE_ENTRY_LEDGER',
 'أوضاع شاشة العرض والعمل المتعددة (سهل / عادي / احترافي / تنفيذي / ميداني سريع) مع تحكم ديناميكي بالبيانات الظاهرة',
 'Multi-Mode Workspace Experience (Easy / Standard / Professional / Executive / Express Field) with Dynamic Data Granularity')
ON CONFLICT (feature_key) DO NOTHING;
