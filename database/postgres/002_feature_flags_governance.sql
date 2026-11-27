-- ============================================================================
-- MIZAN (ميزان) — Migration 002: Operational Preferences & Feature Governance
-- Pattern: 3-Tier Feature Flags (Platform Gate -> Dependency Graph -> Org Preference)
-- Purpose: Ship complete architecture in v1.0 with Phase 2/3 modules safely OFF
-- ============================================================================

CREATE TABLE platform_feature_registry (
    feature_key         VARCHAR(64) PRIMARY KEY,
    category            VARCHAR(32) NOT NULL CHECK (category IN ('CORE', 'COMMERCE', 'COMPLIANCE', 'INTEGRATION', 'AI', 'FINTECH')),
    release_phase       SMALLINT NOT NULL CHECK (release_phase BETWEEN 1 AND 3),
    is_immutable_core   BOOLEAN NOT NULL DEFAULT FALSE,
    platform_enabled    BOOLEAN NOT NULL DEFAULT FALSE,
    org_configurable    BOOLEAN NOT NULL DEFAULT TRUE,
    default_org_state   BOOLEAN NOT NULL DEFAULT FALSE,
    requires_feature    VARCHAR(64) REFERENCES platform_feature_registry(feature_key),
    description_ar      TEXT NOT NULL,
    description_en      TEXT NOT NULL,
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE org_feature_preferences (
    org_id              UUID NOT NULL REFERENCES organizations(id),
    feature_key         VARCHAR(64) NOT NULL REFERENCES platform_feature_registry(feature_key),
    is_enabled          BOOLEAN NOT NULL,
    config_json         JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_by          UUID NOT NULL REFERENCES users(id),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (org_id, feature_key)
);

CREATE TABLE feature_toggle_audit (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    scope               VARCHAR(16) NOT NULL CHECK (scope IN ('PLATFORM', 'ORGANIZATION')),
    org_id              UUID REFERENCES organizations(id),
    feature_key         VARCHAR(64) NOT NULL REFERENCES platform_feature_registry(feature_key),
    previous_state      BOOLEAN,
    new_state           BOOLEAN NOT NULL,
    actor_user_id       UUID NOT NULL REFERENCES users(id),
    reason              TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enforce Invariants at DB Level:
-- 1) Immutable core features can NEVER be turned OFF.
-- 2) Organizations CANNOT turn ON a feature whose platform_enabled = FALSE or org_configurable = FALSE.
-- 3) Dependency prerequisite must be active before enabling a dependent feature.
CREATE OR REPLACE FUNCTION fn_guard_org_feature_toggle() RETURNS TRIGGER AS $$
DECLARE
    v_reg platform_feature_registry%ROWTYPE;
    v_dep_enabled BOOLEAN;
BEGIN
    SELECT * INTO v_reg FROM platform_feature_registry WHERE feature_key = NEW.feature_key;

    IF v_reg.is_immutable_core AND NEW.is_enabled = FALSE THEN
        RAISE EXCEPTION 'CORE_FEATURE_IMMUTABLE: Feature % cannot be disabled.', NEW.feature_key;
    END IF;

    IF NEW.is_enabled = TRUE AND (v_reg.platform_enabled = FALSE OR v_reg.org_configurable = FALSE) THEN
        RAISE EXCEPTION 'FEATURE_LOCKED_BY_PLATFORM: Feature % is disabled at platform level (Phase %).', NEW.feature_key, v_reg.release_phase;
    END IF;

    IF NEW.is_enabled = TRUE AND v_reg.requires_feature IS NOT NULL THEN
        SELECT COALESCE(ofp.is_enabled, pfr.default_org_state) AND pfr.platform_enabled
        INTO v_dep_enabled
        FROM platform_feature_registry pfr
        LEFT JOIN org_feature_preferences ofp
               ON ofp.feature_key = pfr.feature_key AND ofp.org_id = NEW.org_id
        WHERE pfr.feature_key = v_reg.requires_feature;

        IF COALESCE(v_dep_enabled, FALSE) = FALSE THEN
            RAISE EXCEPTION 'FEATURE_DEPENDENCY_MISSING: Feature % requires % to be enabled first.', NEW.feature_key, v_reg.requires_feature;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_guard_org_feature_toggle
BEFORE INSERT OR UPDATE ON org_feature_preferences
FOR EACH ROW EXECUTE FUNCTION fn_guard_org_feature_toggle();

-- Row-Level Security (RLS)
ALTER TABLE org_feature_preferences ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_feature_prefs ON org_feature_preferences
    USING (org_id = current_setting('app.current_org_id', true)::UUID);

-- ============================================================================
-- SEED: PHASE 1 DEFAULT OPERATIONAL MATRIX (16 FEATURES)
-- Core active; Optional Org toggles OFF by default; Phase 2/3 Platform-Locked OFF
-- ============================================================================
INSERT INTO platform_feature_registry
(feature_key, category, release_phase, is_immutable_core, platform_enabled, org_configurable, default_org_state, requires_feature, description_ar, description_en)
VALUES
-- PHASE 1: IMMUTABLE & ACTIVE CORE
('CORE_DOUBLE_ENTRY_LEDGER',    'CORE',        1, TRUE,  TRUE,  FALSE, TRUE,  NULL, 'المحرك المحاسبي للقيد المزدوج ومعايير IFRS 15 وIAS 2', 'Core Double-Entry Ledger (IFRS 15 & IAS 2)'),
('OFFLINE_SQLITE_OUTBOX',       'CORE',        1, TRUE,  TRUE,  FALSE, TRUE,  NULL, 'العمل دون إنترنت وطابور المزامنة المشفّر', 'Offline-First Encrypted SQLite & Sync Outbox'),
('TRADE_GATES_EXCHANGE',        'CORE',        1, FALSE, TRUE,  TRUE,  TRUE,  'CORE_DOUBLE_ENTRY_LEDGER', 'الأبواب التجارية وتبادل المستندات بالقرارات الثلاثة', 'Bilateral Trade Gates & 3-Decision Exchange'),
('QR_CATALOG_SELF_CHECKOUT',    'COMMERCE',    1, FALSE, TRUE,  TRUE,  TRUE,  'CORE_DOUBLE_ENTRY_LEDGER', 'الكتالوج التفاعلي عبر QR والسلة الحية (كاش وآجل)', 'Interactive QR Catalog & Live Cart (Cash/Credit)'),
('MULTI_LANGUAGE_UI',           'CORE',        1, FALSE, TRUE,  TRUE,  TRUE,  NULL, 'تعدد اللغات (RTL/LTR) والترجمة الواجهية', 'Multi-Language Interface (RTL/LTR)'),
('MULTI_CURRENCY_LEDGER',       'CORE',        1, FALSE, TRUE,  TRUE,  TRUE,  'CORE_DOUBLE_ENTRY_LEDGER', 'تعدد العملات وأسعار الصرف بدقة NUMERIC(18,4)', 'Multi-Currency Ledger & FX Engine'),

-- PHASE 1: EMBEDDED & READY, BUT OFF BY DEFAULT (ORG OWNER CAN ENABLE ANYTIME)
('CONTEXTUAL_TRANSACTION_CHAT', 'COMMERCE',    1, FALSE, TRUE,  TRUE,  FALSE, 'TRADE_GATES_EXCHANGE', 'الدردشة التوافقية المرتبطة بالمعاملات وأرشفتها القانونية', 'Transaction-Bound Contextual Chat & Legal Archive'),
('PUBLIC_NEARBY_DIRECTORY',     'COMMERCE',    1, FALSE, TRUE,  TRUE,  FALSE, 'QR_CATALOG_SELF_CHECKOUT', 'الظهور في دليل المتاجر والخدمات القريبة جغرافياً', 'Public Hyperlocal Nearby Directory Listing'),
('BLIND_MUTUAL_RATINGS',        'COMMERCE',    1, FALSE, TRUE,  TRUE,  FALSE, 'QR_CATALOG_SELF_CHECKOUT', 'التقييم الأعمى المتبادل بعد إتمام المعاملات', 'Double-Blind Mutual Rating System'),
('PERISHABLE_LIVE_CAM_DISPUTES','COMMERCE',    1, FALSE, TRUE,  TRUE,  FALSE, 'QR_CATALOG_SELF_CHECKOUT', 'توثيق اعتراضات السلع القابلة للتلف بالكاميرا الحية فقط', 'Perishable Dispute Guard (Live Camera & 30m Timer)'),

-- PHASE 2 & 3: ARCHITECTURALLY EMBEDDED, PLATFORM-LOCKED OFF UNTIL EXTERNAL CONTRACTS/LICENSES
('KYC_STRICT_TIERS_2_TO_4',     'COMPLIANCE',  2, FALSE, FALSE, TRUE,  FALSE, NULL, 'التحقق المتدرج KYC للمستويات 2-4 (موقوف في المرحلة الأولى)', 'Tiered KYC Levels 2-4 Verification'),
('PSP_PASS_THROUGH_PREAUTH',    'FINTECH',     2, FALSE, FALSE, TRUE,  FALSE, 'KYC_STRICT_TIERS_2_TO_4', 'بوابة الدفع التمريرية بالتفويض المسبق Authorize & Capture', 'Pass-Through PSP Authorize & Capture'),
('TAX_EINVOICING_PEPPOL_ZATCA', 'COMPLIANCE',  2, FALSE, FALSE, TRUE,  FALSE, 'CORE_DOUBLE_ENTRY_LEDGER', 'الربط الضريبي والفوترة الإلكترونية UBL 2.1 / Peppol', 'E-Invoicing & Tax Authority Sync (UBL 2.1/Peppol)'),
('ERP_CONNECTORS_OAUTH',        'INTEGRATION', 3, FALSE, FALSE, TRUE,  FALSE, 'TRADE_GATES_EXCHANGE', 'الموصلات الرسمية مع QuickBooks وXero وOdoo وSAP', 'External ERP Connectors (QuickBooks/Xero/Odoo/SAP)'),
('AI_FINANCIAL_COPILOT_OCR',    'AI',          3, FALSE, FALSE, TRUE,  FALSE, 'CORE_DOUBLE_ENTRY_LEDGER', 'المساعد الذكي وقراءة الفواتير OCR وكشف أنماط التزوير', 'AI Copilot, OCR Invoice Scan & Fraud Detection'),
('INTERNAL_WALLET_CUSTODY',     'FINTECH',     3, FALSE, FALSE, FALSE, FALSE, 'KYC_STRICT_TIERS_2_TO_4', 'المحفظة المالية الداخلية (مغلقة لحين استصدار ترخيص مالي)', 'Internal Custody Wallet (Requires EMI/PSP License)');
