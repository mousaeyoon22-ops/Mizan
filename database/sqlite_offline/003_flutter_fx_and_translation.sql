-- Mizan Flutter Client — Offline FX Rates (Integer Micro-Units) & Translation Cache
CREATE TABLE IF NOT EXISTS local_exchange_rates (
    org_id          TEXT NOT NULL,
    from_currency   TEXT NOT NULL,
    to_currency     TEXT NOT NULL,
    rate_micro      INTEGER NOT NULL CHECK (rate_micro > 0), -- Scaled x1,000,000 (1.083700 -> 1083700)
    rate_type       TEXT NOT NULL DEFAULT 'MARKET',
    effective_at    TEXT NOT NULL,
    PRIMARY KEY (org_id, from_currency, to_currency, rate_type)
);

CREATE TABLE IF NOT EXISTS local_translation_cache (
    source_sha256   TEXT NOT NULL,
    source_lang     TEXT NOT NULL,
    target_lang     TEXT NOT NULL,
    translated_text TEXT NOT NULL,
    cached_at       TEXT NOT NULL,
    PRIMARY KEY (source_sha256, source_lang, target_lang)
);
