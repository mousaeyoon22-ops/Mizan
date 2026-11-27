-- Mizan Flutter Client — Migration 005: Offline POS Variants, Shifts & Parked Invoices
CREATE TABLE IF NOT EXISTS local_item_variants (
    id                      TEXT PRIMARY KEY,
    org_id                  TEXT NOT NULL,
    parent_item_id          TEXT NOT NULL,
    variant_sku             TEXT NOT NULL,
    variant_barcode         TEXT NOT NULL,
    size_label              TEXT,
    color_label             TEXT,
    color_hex               TEXT,
    sale_price_minor        INTEGER NOT NULL CHECK (sale_price_minor >= 0),
    currency                TEXT NOT NULL,
    qty_on_hand_minor       INTEGER NOT NULL CHECK (qty_on_hand_minor >= 0),
    row_version             INTEGER NOT NULL DEFAULT 1,
    UNIQUE (org_id, variant_barcode)
);

CREATE TABLE IF NOT EXISTS local_pos_shifts (
    id                      TEXT PRIMARY KEY,
    org_id                  TEXT NOT NULL,
    terminal_id             TEXT NOT NULL,
    cashier_user_id         TEXT NOT NULL,
    currency                TEXT NOT NULL,
    status                  TEXT NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLOSED')),
    opening_float_minor     INTEGER NOT NULL DEFAULT 0 CHECK (opening_float_minor >= 0),
    cash_sales_minor        INTEGER NOT NULL DEFAULT 0 CHECK (cash_sales_minor >= 0),
    card_sales_minor        INTEGER NOT NULL DEFAULT 0 CHECK (card_sales_minor >= 0),
    credit_sales_minor      INTEGER NOT NULL DEFAULT 0 CHECK (credit_sales_minor >= 0),
    cash_refunds_minor      INTEGER NOT NULL DEFAULT 0 CHECK (cash_refunds_minor >= 0),
    counted_cash_minor      INTEGER,
    cash_variance_minor     INTEGER,
    z_report_sha256         TEXT,
    opened_at               TEXT NOT NULL,
    closed_at               TEXT
);

CREATE TABLE IF NOT EXISTS local_parked_carts (
    id                      TEXT PRIMARY KEY,
    org_id                  TEXT NOT NULL,
    terminal_id             TEXT NOT NULL,
    hold_label              TEXT NOT NULL,
    cart_json               TEXT NOT NULL,
    total_minor             INTEGER NOT NULL CHECK (total_minor >= 0),
    created_at              TEXT NOT NULL
);

CREATE TRIGGER IF NOT EXISTS trg_sqlite_immutable_closed_shift_upd
BEFORE UPDATE ON local_pos_shifts
WHEN OLD.status = 'CLOSED'
BEGIN SELECT RAISE(ABORT, 'Z_REPORT_IMMUTABILITY_VIOLATION'); END;

CREATE TRIGGER IF NOT EXISTS trg_sqlite_immutable_closed_shift_del
BEFORE DELETE ON local_pos_shifts
WHEN OLD.status = 'CLOSED'
BEGIN SELECT RAISE(ABORT, 'Z_REPORT_IMMUTABILITY_VIOLATION'); END;

CREATE INDEX IF NOT EXISTS idx_local_variants_barcode ON local_item_variants(org_id, variant_barcode);
CREATE INDEX IF NOT EXISTS idx_local_shifts_open ON local_pos_shifts(org_id, terminal_id, status);
