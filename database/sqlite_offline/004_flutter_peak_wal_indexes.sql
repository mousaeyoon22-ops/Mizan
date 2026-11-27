-- Mizan Flutter Client — Migration 004: Peak Offline Burst & Concurrent Read Tuning
PRAGMA journal_mode = WAL;
PRAGMA synchronous = NORMAL;
PRAGMA busy_timeout = 10000;
PRAGMA temp_store = MEMORY;

CREATE INDEX IF NOT EXISTS idx_local_items_org_sku
    ON local_items (org_id, sku);

CREATE INDEX IF NOT EXISTS idx_local_orders_seller_state
    ON local_p2p_orders (seller_org_id, order_state, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_local_chat_order_time
    ON local_transaction_chat (order_id, created_at ASC);
