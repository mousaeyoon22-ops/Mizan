-- ============================================================================
-- MIZAN (ميزان) — Migration 007: Voice Command Operations & Inclusive
-- Accessibility Profiles (WCAG 2.2 AA / EN 301 549)
-- ============================================================================

-- 1) Per-User Accessibility & Assistive Preferences (Follows the user across all devices & orgs)
CREATE TABLE user_accessibility_profiles (
    user_id                     UUID PRIMARY KEY REFERENCES users(id),
    preset_profile              VARCHAR(32) NOT NULL DEFAULT 'STANDARD' CHECK (preset_profile IN (
                                    'STANDARD', 'BLIND_SCREEN_READER', 'LOW_VISION_HIGH_CONTRAST',
                                    'DEAF_VISUAL_HAPTIC', 'MOTOR_HANDS_FREE_VOICE', 'COGNITIVE_SIMPLIFIED', 'CUSTOM'
                                )),
    high_contrast_enabled       BOOLEAN NOT NULL DEFAULT FALSE,
    font_scale                  NUMERIC(3, 2) NOT NULL DEFAULT 1.00 CHECK (font_scale BETWEEN 1.00 AND 2.00),
    color_blind_safe_labels     BOOLEAN NOT NULL DEFAULT TRUE,
    screen_reader_verbose       BOOLEAN NOT NULL DEFAULT FALSE,
    tts_financial_readback      BOOLEAN NOT NULL DEFAULT FALSE,
    tts_speech_rate             NUMERIC(3, 2) NOT NULL DEFAULT 1.00 CHECK (tts_speech_rate BETWEEN 0.50 AND 1.50),
    visual_flash_alerts         BOOLEAN NOT NULL DEFAULT FALSE,
    haptic_feedback_enabled     BOOLEAN NOT NULL DEFAULT TRUE,
    live_captions_enabled       BOOLEAN NOT NULL DEFAULT FALSE,
    motor_large_targets         BOOLEAN NOT NULL DEFAULT FALSE, -- Upgrades touch targets from 48dp to 64dp+
    single_tap_no_swipe         BOOLEAN NOT NULL DEFAULT FALSE,
    simplified_ui_mode          BOOLEAN NOT NULL DEFAULT FALSE,
    timeout_multiplier          NUMERIC(3, 2) NOT NULL DEFAULT 1.00 CHECK (timeout_multiplier BETWEEN 1.00 AND 3.00),
    voice_commands_enabled      BOOLEAN NOT NULL DEFAULT FALSE,
    voice_lang                  VARCHAR(10) NOT NULL DEFAULT 'ar',
    voice_high_value_threshold  NUMERIC(18, 4) NOT NULL DEFAULT 500.0000 CHECK (voice_high_value_threshold >= 0),
    updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2) Voice Command Drafts & Strict 2-Step Confirmation Audit Trail (Append-Only once Executed)
CREATE TABLE voice_command_audit (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                  UUID NOT NULL REFERENCES organizations(id),
    user_id                 UUID NOT NULL REFERENCES users(id),
    idempotency_key         VARCHAR(128) NOT NULL,
    command_lang            VARCHAR(10) NOT NULL,
    raw_transcript          TEXT NOT NULL,
    transcript_sha256       CHAR(64) NOT NULL,
    detected_intent         VARCHAR(48) NOT NULL CHECK (detected_intent IN (
                                'NAVIGATE', 'QUERY_BALANCE', 'QUERY_STOCK', 'READ_LAST_INVOICE',
                                'CREATE_SALE_INVOICE', 'RECORD_CASH_RECEIPT', 'RECORD_CASH_PAYMENT',
                                'POS_ADD_ITEM', 'OPEN_SHIFT', 'CLOSE_SHIFT', 'UNKNOWN'
                            )),
    is_financial_mutation   BOOLEAN NOT NULL DEFAULT FALSE,
    parsed_payload_json     JSONB NOT NULL DEFAULT '{}'::jsonb,
    amount_value            NUMERIC(18, 4),
    currency                CHAR(3),
    state                   VARCHAR(24) NOT NULL DEFAULT 'DRAFT_AWAITING_CONFIRM' CHECK (state IN (
                                'EXECUTED_READONLY', 'DRAFT_AWAITING_CONFIRM',
                                'CONFIRMED_AND_POSTED', 'CANCELLED_BY_USER', 'REJECTED_AMBIGUOUS'
                            )),
    confirmation_method     VARCHAR(24) CHECK (confirmation_method IN ('VOICE_EXPLICIT', 'TOUCH_BUTTON', 'PIN_OR_BIOMETRIC', 'NONE')),
    linked_journal_id       UUID REFERENCES journal_entries(id),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    confirmed_at            TIMESTAMPTZ,
    UNIQUE (org_id, idempotency_key)
);

-- Enforce Append-Only Immutability once a voice command reaches a terminal state
CREATE OR REPLACE FUNCTION fn_prevent_voice_audit_tampering() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.state IN ('EXECUTED_READONLY', 'CONFIRMED_AND_POSTED', 'CANCELLED_BY_USER') THEN
        RAISE EXCEPTION 'VOICE_AUDIT_IMMUTABILITY_VIOLATION: Terminal voice command record % cannot be altered or deleted.', OLD.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_immutable_voice_audit
BEFORE UPDATE OR DELETE ON voice_command_audit
FOR EACH ROW EXECUTE FUNCTION fn_prevent_voice_audit_tampering();

-- Performance Indexes
CREATE INDEX idx_voice_audit_org_user_time ON voice_command_audit (org_id, user_id, created_at DESC);

-- Strict Row-Level Security (RLS)
ALTER TABLE user_accessibility_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE voice_command_audit ENABLE ROW LEVEL SECURITY;

CREATE POLICY user_isolation_a11y_profile ON user_accessibility_profiles
    USING (user_id = current_setting('app.current_user_id', true)::UUID);

CREATE POLICY tenant_isolation_voice_audit ON voice_command_audit
    USING (org_id = current_setting('app.current_org_id', true)::UUID);

-- Register 2 New Operational Feature Flags (Total across Mizan = 24 Operational Flags)
INSERT INTO platform_feature_registry
(feature_key, category, release_phase, is_immutable_core, platform_enabled, org_configurable, default_org_state, requires_feature, description_ar, description_en)
VALUES
('ACCESSIBILITY_INCLUSIVE_MODE', 'CORE', 1, TRUE,  TRUE, FALSE, TRUE,  NULL, 'دعم ذوي الهمم والاحتياجات الخاصة (WCAG 2.2 AA، قارئ الشاشة، التباين العالي، التنبيهات البصرية/الاهتزازية، الأزرار الكبيرة)', 'Inclusive Accessibility Suite (WCAG 2.2 AA, Screen Reader, High Contrast, Visual+Haptic Alerts, Large Targets)'),
('VOICE_COMMAND_OPERATIONS',     'CORE', 1, FALSE, TRUE, TRUE,  FALSE, 'ACCESSIBILITY_INCLUSIVE_MODE', 'التشغيل والعمل بالأوامر الصوتية ثنائية اللغة مع تأكيد مزدوج للعمليات المالية (يعمل محلياً دون سحابة)', 'Bilingual Voice Command Operations with 2-Step Financial Confirmation (On-Device Ready)')
ON CONFLICT (feature_key) DO NOTHING;
