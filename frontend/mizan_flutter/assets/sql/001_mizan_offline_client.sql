-- Mizan Flutter Client — Offline-First Encrypted SQLite (SQLCipher)
-- Strictly aligned with backend contract `database/sqlite_offline/001_flutter_offline_schema.sql`
PRAGMA foreign_keys = ON;

CREATE TABLE IF NOT EXISTS local_items (
    id TEXT PRIMARY KEY,
    org_id TEXT NOT NULL,
    sku TEXT NOT NULL,
    global_barcode TEXT,
    name TEXT NOT NULL,
    sale_price_minor INTEGER NOT NULL CHECK (sale_price_minor >= 0),
    currency TEXT NOT NULL,
    is_perishable INTEGER NOT NULL DEFAULT 0 CHECK (is_perishable IN (0, 1)),
    qty_on_hand_minor INTEGER NOT NULL CHECK (qty_on_hand_minor >= 0),
    qty_reserved_minor INTEGER NOT NULL DEFAULT 0 CHECK (qty_reserved_minor >= 0),
    updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sync_outbox (
    id TEXT PRIMARY KEY,
    idempotency_key TEXT NOT NULL UNIQUE,
    org_id TEXT NOT NULL,
    endpoint TEXT NOT NULL,
    http_method TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    payload_sha256 TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'SYNCING', 'SYNCED', 'CONFLICT')),
    retry_count INTEGER NOT NULL DEFAULT 0 CHECK (retry_count >= 0),
    created_at TEXT NOT NULL,
    last_error TEXT
);

CREATE TABLE IF NOT EXISTS local_p2p_orders (
    id TEXT PRIMARY KEY,
    idempotency_key TEXT NOT NULL UNIQUE,
    seller_org_id TEXT NOT NULL,
    buyer_user_id TEXT NOT NULL,
    payment_mode TEXT NOT NULL CHECK (payment_mode IN ('GATEWAY_PREAUTH', 'CASH', 'CREDIT', 'PARTIAL_CREDIT')),
    payment_status TEXT NOT NULL DEFAULT 'UNPAID',
    order_state TEXT NOT NULL DEFAULT 'LIVE_CART',
    currency TEXT NOT NULL,
    total_amount_minor INTEGER NOT NULL CHECK (total_amount_minor >= 0),
    delivered_at TEXT,
    is_chat_locked INTEGER NOT NULL DEFAULT 0 CHECK (is_chat_locked IN (0, 1)),
    created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS local_transaction_chat (
    id TEXT PRIMARY KEY,
    order_id TEXT NOT NULL REFERENCES local_p2p_orders(id),
    sender_role TEXT NOT NULL CHECK (sender_role IN ('BUYER', 'SELLER', 'SYSTEM')),
    body TEXT NOT NULL,
    live_card_ref TEXT,
    created_at TEXT NOT NULL
);

-- Enforce Read-Only Legal Archive: block inserting chat messages once order chat is locked
CREATE TRIGGER IF NOT EXISTS trg_block_locked_chat_insert
BEFORE INSERT ON local_transaction_chat
WHEN (SELECT is_chat_locked FROM local_p2p_orders WHERE id = NEW.order_id) = 1
BEGIN
    SELECT RAISE(ABORT, 'TRANSACTION_CHAT_LOCKED_ARCHIVE');
END;

CREATE INDEX IF NOT EXISTS idx_outbox_status ON sync_outbox(status, created_at);
CREATE INDEX IF NOT EXISTS idx_items_org_barcode ON local_items(org_id, global_barcode);
