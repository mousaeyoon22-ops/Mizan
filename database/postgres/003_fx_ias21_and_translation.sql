-- ============================================================================
-- MIZAN (ميزان) — Migration 003: IAS 21 Multi-Currency FX Gain/Loss Engine,
-- Direct Currency Exchange Vouchers (المصارفة) & Instant Cross-Border Translation
-- ============================================================================

-- 1) Historical & Market Exchange Rates Registry
CREATE TABLE exchange_rates (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID REFERENCES organizations(id), -- NULL = global platform rate; non-NULL = org override
    from_currency   CHAR(3) NOT NULL,
    to_currency     CHAR(3) NOT NULL,
    rate            NUMERIC(18, 6) NOT NULL CHECK (rate > 0),
    rate_type       VARCHAR(16) NOT NULL DEFAULT 'MARKET' CHECK (rate_type IN ('OFFICIAL', 'MARKET', 'CUSTOM')),
    effective_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      UUID REFERENCES users(id),
    CHECK (from_currency <> to_currency)
);

CREATE INDEX idx_fx_rates_lookup ON exchange_rates(org_id, from_currency, to_currency, effective_at DESC);

-- 2) Direct Currency Exchange Vouchers (سندات المصارفة وتحويل الصناديق بين العملات)
CREATE TABLE fx_exchange_vouchers (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                  UUID NOT NULL REFERENCES organizations(id),
    idempotency_key         VARCHAR(128) NOT NULL,
    source_account_id       UUID NOT NULL REFERENCES accounts(id),
    source_currency         CHAR(3) NOT NULL,
    source_amount           NUMERIC(18, 4) NOT NULL CHECK (source_amount > 0),
    source_book_rate_to_base NUMERIC(18, 6) NOT NULL CHECK (source_book_rate_to_base > 0),
    target_account_id       UUID NOT NULL REFERENCES accounts(id),
    target_currency         CHAR(3) NOT NULL,
    target_amount           NUMERIC(18, 4) NOT NULL CHECK (target_amount > 0),
    target_book_rate_to_base NUMERIC(18, 6) NOT NULL CHECK (target_book_rate_to_base > 0),
    base_currency           CHAR(3) NOT NULL,
    fx_diff_base_amount     NUMERIC(18, 4) NOT NULL, -- Positive = FX Gain (ربح مصارفة), Negative = FX Loss (فرق/مصروف مصارفة)
    journal_entry_id        UUID NOT NULL REFERENCES journal_entries(id),
    notes                   TEXT,
    created_by              UUID NOT NULL REFERENCES users(id),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (org_id, idempotency_key),
    CHECK (source_currency <> target_currency)
);

-- 3) Enforce Base-Currency Double-Entry Balance (IAS 21 Functional Currency Invariant)
CREATE OR REPLACE FUNCTION fn_verify_base_currency_balance() RETURNS TRIGGER AS $$
DECLARE
    v_base_debit  NUMERIC(18, 4);
    v_base_credit NUMERIC(18, 4);
BEGIN
    SELECT COALESCE(SUM(base_debit), 0), COALESCE(SUM(base_credit), 0)
    INTO v_base_debit, v_base_credit
    FROM journal_lines
    WHERE journal_entry_id = NEW.journal_entry_id;

    IF v_base_debit <> v_base_credit THEN
        RAISE EXCEPTION 'IAS21_BASE_BALANCE_VIOLATION: Entry % unbalanced in base currency (BaseDr=%, BaseCr=%).',
            NEW.journal_entry_id, v_base_debit, v_base_credit;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER trg_verify_base_currency_balance
AFTER INSERT ON journal_lines
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION fn_verify_base_currency_balance();

-- 4) Deterministic Translation Cache (Cross-Border Documents, Catalog & Chat)
CREATE TABLE translation_cache (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_sha256   CHAR(64) NOT NULL,
    source_lang     VARCHAR(10) NOT NULL,
    target_lang     VARCHAR(10) NOT NULL,
    source_text     TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    provider        VARCHAR(32) NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (source_sha256, source_lang, target_lang)
);

-- 5) Row-Level Security (RLS)
ALTER TABLE fx_exchange_vouchers ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation_fx_vouchers ON fx_exchange_vouchers
    USING (org_id = current_setting('app.current_org_id', true)::UUID);

-- 6) Register New Operational Feature Flags (Extends Migration 002)
INSERT INTO platform_feature_registry
(feature_key, category, release_phase, is_immutable_core, platform_enabled, org_configurable, default_org_state, requires_feature, description_ar, description_en)
VALUES
('FX_IAS21_GAIN_LOSS_ENGINE',       'CORE', 1, FALSE, TRUE,  TRUE, TRUE,  'MULTI_CURRENCY_LEDGER',    'محرك احتساب فروقات العملة (IAS 21) عند التسوية وإعادة التقييم', 'IAS 21 FX Gain/Loss Engine (Settlement & Revaluation)'),
('DIRECT_CURRENCY_EXCHANGE_VOUCHER','CORE', 1, FALSE, TRUE,  TRUE, TRUE,  'FX_IAS21_GAIN_LOSS_ENGINE','سندات المصارفة المباشرة وتحويل الصناديق مع قيد فرق الصرف', 'Direct Currency Exchange Vouchers & Spread Accounting'),
('INSTANT_CROSS_BORDER_TRANSLATION','AI',   2, FALSE, FALSE, TRUE, FALSE, 'MULTI_LANGUAGE_UI',        'المترجم الفوري للمستندات والأصناف والدردشة عبر الحدود (موقوف بالمرحلة 1)', 'Instant Cross-Border Translation (Docs, Catalog & Chat)')
ON CONFLICT (feature_key) DO NOTHING;
