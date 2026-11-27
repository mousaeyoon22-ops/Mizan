-- Mizan Flutter Client — Offline-First SQLite Schema (Encrypted via SQLCipher)
PRAGMA foreign_keys = ON;

CREATE TABLE local_items (
    id TEXT PRIMARY KEY,
    org_id TEXT NOT NULL,
    sku TEXT NOT NULL,
    global_barcode TEXT,
    name TEXT NOT NULL,
    sale_price_minor INTEGER NOT NULL, -- Stored in minor units (x10000) to avoid IEEE 754 float drift
    currency TEXT NOT NULL,
    qty_on_hand_minor INTEGER NOT NULL,
    updated_at TEXT NOT NULL
);

CREATE TABLE sync_outbox (
    id TEXT PRIMARY KEY,
    idempotency_key TEXT NOT NULL UNIQUE,
    org_id TEXT NOT NULL,
    endpoint TEXT NOT NULL,
    http_method TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    payload_sha256 TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SYNCING', 'SYNCED', 'CONFLICT')),
    retry_count INTEGER NOT NULL DEFAULT 0,
    created_at TEXT NOT NULL,
    last_error TEXT
);

CREATE INDEX idx_outbox_status ON sync_outbox(status, created_at);
