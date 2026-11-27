-- Mizan Flutter Client — Migration 008: Offline Meter Readings & Tank/Equipment Custody
CREATE TABLE IF NOT EXISTS local_meter_readings (
    id                      TEXT PRIMARY KEY,
    org_id                  TEXT NOT NULL,
    idempotency_key         TEXT NOT NULL UNIQUE,
    meter_name              TEXT NOT NULL,
    reading_date            TEXT NOT NULL,
    opening_minor           INTEGER NOT NULL CHECK (opening_minor >= 0),
    closing_minor           INTEGER NOT NULL CHECK (closing_minor >= opening_minor),
    reconciled_sales_minor  INTEGER NOT NULL DEFAULT 0 CHECK (reconciled_sales_minor >= 0),
    created_at              TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS local_equipment_custody (
    id                      TEXT PRIMARY KEY,
    org_id                  TEXT NOT NULL,
    idempotency_key         TEXT NOT NULL UNIQUE,
    holder_type             TEXT NOT NULL CHECK (holder_type IN ('CUSTOMER', 'DRIVER')),
    holder_name             TEXT NOT NULL,
    equipment_sku           TEXT NOT NULL,
    qty_out_minor           INTEGER NOT NULL DEFAULT 0 CHECK (qty_out_minor >= 0),
    qty_returned_minor      INTEGER NOT NULL DEFAULT 0 CHECK (qty_returned_minor >= 0),
    created_at              TEXT NOT NULL,
    CHECK ((qty_out_minor > 0 AND qty_returned_minor = 0) OR (qty_returned_minor > 0 AND qty_out_minor = 0))
);
