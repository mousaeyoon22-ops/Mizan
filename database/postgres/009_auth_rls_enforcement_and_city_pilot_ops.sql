-- ============================================================================
-- MIZAN (ميزان) — Migration 009: Auth Refresh Tokens, City Pilot Operations
-- (Meter Reconciliation & Tank Custody) & Real Non-Superuser NOBYPASSRLS Enforcement
-- Fixes DEF-301 & DEF-304
-- ============================================================================

-- 1) JWT Refresh Token Store (Rotation, Device Binding & Immediate Revocation)
CREATE TABLE refresh_tokens (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID NOT NULL REFERENCES users(id),
    token_sha256        CHAR(64) NOT NULL UNIQUE,
    device_label        VARCHAR(120),
    issued_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at          TIMESTAMPTZ NOT NULL,
    revoked_at          TIMESTAMPTZ,
    replaced_by_id      UUID REFERENCES refresh_tokens(id)
);

CREATE INDEX idx_refresh_tokens_user_active ON refresh_tokens (user_id, expires_at DESC) WHERE revoked_at IS NULL;

-- 2) City Pilot Operational Tables: Meter Readings & Returnable Tank/Equipment Custody
CREATE TABLE meter_readings (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organizations(id),
    idempotency_key     VARCHAR(128) NOT NULL,
    meter_name          VARCHAR(120) NOT NULL,
    reading_date        DATE NOT NULL,
    opening_reading     NUMERIC(18, 4) NOT NULL CHECK (opening_reading >= 0),
    closing_reading     NUMERIC(18, 4) NOT NULL CHECK (closing_reading >= opening_reading),
    unit_label          VARCHAR(32) NOT NULL DEFAULT 'LITER',
    reconciled_sales_qty NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (reconciled_sales_qty >= 0),
    variance_qty        NUMERIC(18, 4) GENERATED ALWAYS AS ((closing_reading - opening_reading) - reconciled_sales_qty) STORED,
    recorded_by         UUID NOT NULL REFERENCES users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (org_id, idempotency_key)
);

CREATE TABLE equipment_custody_logs (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organizations(id),
    idempotency_key     VARCHAR(128) NOT NULL,
    holder_type         VARCHAR(16) NOT NULL CHECK (holder_type IN ('CUSTOMER', 'DRIVER')),
    holder_name         VARCHAR(160) NOT NULL,
    party_org_id        UUID REFERENCES organizations(id),
    equipment_sku       VARCHAR(64) NOT NULL, -- e.g., TANK-20L, CRATE-12
    qty_out             NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (qty_out >= 0),
    qty_returned        NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (qty_returned >= 0),
    notes               TEXT,
    recorded_by         UUID NOT NULL REFERENCES users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (org_id, idempotency_key),
    CHECK ((qty_out > 0 AND qty_returned = 0) OR (qty_returned > 0 AND qty_out = 0))
);

CREATE INDEX idx_meter_readings_org_date ON meter_readings (org_id, reading_date DESC);
CREATE INDEX idx_custody_org_holder ON equipment_custody_logs (org_id, holder_type, holder_name);

-- 3) RLS on New Tables + FORCE ROW LEVEL SECURITY across ALL Tenant-Isolated Tables
ALTER TABLE meter_readings ENABLE ROW LEVEL SECURITY;
ALTER TABLE equipment_custody_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_meter_readings ON meter_readings
    USING (org_id = current_setting('app.current_org_id', true)::UUID);

CREATE POLICY tenant_isolation_equipment_custody ON equipment_custody_logs
    USING (org_id = current_setting('app.current_org_id', true)::UUID);

-- Enforce FORCE RLS so even table owners cannot accidentally bypass policies when running under runtime role
ALTER TABLE accounts FORCE ROW LEVEL SECURITY;
ALTER TABLE journal_entries FORCE ROW LEVEL SECURITY;
ALTER TABLE journal_lines FORCE ROW LEVEL SECURITY;
ALTER TABLE items FORCE ROW LEVEL SECURITY;
ALTER TABLE inventory_fifo_layers FORCE ROW LEVEL SECURITY;
ALTER TABLE p2p_orders FORCE ROW LEVEL SECURITY;
ALTER TABLE audit_logs FORCE ROW LEVEL SECURITY;
ALTER TABLE trade_gates FORCE ROW LEVEL SECURITY;
ALTER TABLE gate_documents FORCE ROW LEVEL SECURITY;
ALTER TABLE org_feature_preferences FORCE ROW LEVEL SECURITY;
ALTER TABLE fx_exchange_vouchers FORCE ROW LEVEL SECURITY;
ALTER TABLE pos_terminals FORCE ROW LEVEL SECURITY;
ALTER TABLE pos_shifts FORCE ROW LEVEL SECURITY;
ALTER TABLE item_variants FORCE ROW LEVEL SECURITY;
ALTER TABLE pos_sales FORCE ROW LEVEL SECURITY;
ALTER TABLE pos_sale_lines FORCE ROW LEVEL SECURITY;
ALTER TABLE user_accessibility_profiles FORCE ROW LEVEL SECURITY;
ALTER TABLE voice_command_audit FORCE ROW LEVEL SECURITY;
ALTER TABLE user_workspace_preferences FORCE ROW LEVEL SECURITY;
ALTER TABLE org_role_mode_policies FORCE ROW LEVEL SECURITY;
ALTER TABLE meter_readings FORCE ROW LEVEL SECURITY;
ALTER TABLE equipment_custody_logs FORCE ROW LEVEL SECURITY;

-- 4) Create Dedicated Non-Superuser Application Role (NOSUPERUSER NOBYPASSRLS)
-- NOTE: Password MUST be rotated at deployment time via scripts/deploy_local_city_pilot.sh
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'mizan_runtime') THEN
        CREATE ROLE mizan_runtime LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOBYPASSRLS PASSWORD 'CHANGE_ME_RUNTIME_DB_PASS';
    END IF;
END
$$;

GRANT USAGE ON SCHEMA public TO mizan_runtime;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO mizan_runtime;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO mizan_runtime;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO mizan_runtime;
