-- Mizan Flutter Client — Migration 006: Offline Accessibility Profile & Voice Audit Log
CREATE TABLE IF NOT EXISTS local_accessibility_profile (
    user_id                     TEXT PRIMARY KEY,
    preset_profile              TEXT NOT NULL DEFAULT 'STANDARD',
    high_contrast_enabled       INTEGER NOT NULL DEFAULT 0 CHECK (high_contrast_enabled IN (0, 1)),
    font_scale_pct              INTEGER NOT NULL DEFAULT 100 CHECK (font_scale_pct BETWEEN 100 AND 200),
    color_blind_safe_labels     INTEGER NOT NULL DEFAULT 1 CHECK (color_blind_safe_labels IN (0, 1)),
    screen_reader_verbose       INTEGER NOT NULL DEFAULT 0 CHECK (screen_reader_verbose IN (0, 1)),
    tts_financial_readback      INTEGER NOT NULL DEFAULT 0 CHECK (tts_financial_readback IN (0, 1)),
    visual_flash_alerts         INTEGER NOT NULL DEFAULT 0 CHECK (visual_flash_alerts IN (0, 1)),
    haptic_feedback_enabled     INTEGER NOT NULL DEFAULT 1 CHECK (haptic_feedback_enabled IN (0, 1)),
    live_captions_enabled       INTEGER NOT NULL DEFAULT 0 CHECK (live_captions_enabled IN (0, 1)),
    motor_large_targets         INTEGER NOT NULL DEFAULT 0 CHECK (motor_large_targets IN (0, 1)),
    single_tap_no_swipe         INTEGER NOT NULL DEFAULT 0 CHECK (single_tap_no_swipe IN (0, 1)),
    simplified_ui_mode          INTEGER NOT NULL DEFAULT 0 CHECK (simplified_ui_mode IN (0, 1)),
    timeout_multiplier_pct      INTEGER NOT NULL DEFAULT 100 CHECK (timeout_multiplier_pct BETWEEN 100 AND 300),
    voice_commands_enabled      INTEGER NOT NULL DEFAULT 0 CHECK (voice_commands_enabled IN (0, 1)),
    voice_lang                  TEXT NOT NULL DEFAULT 'ar',
    updated_at                  TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS local_voice_command_audit (
    id                      TEXT PRIMARY KEY,
    org_id                  TEXT NOT NULL,
    user_id                 TEXT NOT NULL,
    idempotency_key         TEXT NOT NULL UNIQUE,
    raw_transcript          TEXT NOT NULL,
    transcript_sha256       TEXT NOT NULL,
    detected_intent         TEXT NOT NULL,
    is_financial_mutation   INTEGER NOT NULL CHECK (is_financial_mutation IN (0, 1)),
    amount_minor            INTEGER,
    currency                TEXT,
    state                   TEXT NOT NULL CHECK (state IN ('EXECUTED_READONLY', 'DRAFT_AWAITING_CONFIRM', 'CONFIRMED_AND_POSTED', 'CANCELLED_BY_USER', 'REJECTED_AMBIGUOUS')),
    confirmation_method     TEXT,
    created_at              TEXT NOT NULL,
    confirmed_at            TEXT
);

CREATE TRIGGER IF NOT EXISTS trg_sqlite_immutable_voice_upd
BEFORE UPDATE ON local_voice_command_audit
WHEN OLD.state IN ('EXECUTED_READONLY', 'CONFIRMED_AND_POSTED', 'CANCELLED_BY_USER')
BEGIN SELECT RAISE(ABORT, 'VOICE_AUDIT_IMMUTABILITY_VIOLATION'); END;

CREATE TRIGGER IF NOT EXISTS trg_sqlite_immutable_voice_del
BEFORE DELETE ON local_voice_command_audit
WHEN OLD.state IN ('EXECUTED_READONLY', 'CONFIRMED_AND_POSTED', 'CANCELLED_BY_USER')
BEGIN SELECT RAISE(ABORT, 'VOICE_AUDIT_IMMUTABILITY_VIOLATION'); END;
