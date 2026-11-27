-- ============================================================================
-- MIZAN (ميزان) — Accounting Operations Ledger & Inter-Org Trust Network
-- Database Engine: PostgreSQL 16+
-- Monetary Precision: NUMERIC(18, 4) strictly enforced
-- Invariants: Double-Entry Balance, Ledger Immutability, Idempotency, RLS
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ----------------------------------------------------------------------------
-- LAYER 0 & 1: UNIFIED IDENTITY, KYC & ORGANIZATIONS (LAYER 2)
-- ----------------------------------------------------------------------------
CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    uid_code        VARCHAR(24) NOT NULL UNIQUE, -- Binance-style accounting UID
    email           VARCHAR(255) NOT NULL UNIQUE,
    phone           VARCHAR(32) NOT NULL UNIQUE,
    password_hash   TEXT NOT NULL,
    kyc_level       SMALLINT NOT NULL DEFAULT 1 CHECK (kyc_level BETWEEN 1 AND 4),
    preferred_lang  VARCHAR(10) NOT NULL DEFAULT 'ar',
    base_currency   CHAR(3) NOT NULL DEFAULT 'USD',
    trust_score     NUMERIC(5, 2) NOT NULL DEFAULT 100.00 CHECK (trust_score BETWEEN 0 AND 100),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE organizations (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_user_id       UUID NOT NULL REFERENCES users(id),
    uid_code            VARCHAR(24) NOT NULL UNIQUE,
    trade_name          VARCHAR(200) NOT NULL,
    sector              VARCHAR(64) NOT NULL, -- e.g., water_distribution, retail, workshop, factory
    visibility_mode     VARCHAR(16) NOT NULL DEFAULT 'QR_ONLY' CHECK (visibility_mode IN ('PRIVATE', 'QR_ONLY', 'PUBLIC')),
    base_currency       CHAR(3) NOT NULL DEFAULT 'USD',
    inventory_method    VARCHAR(16) NOT NULL DEFAULT 'FIFO' CHECK (inventory_method IN ('FIFO', 'WEIGHTED_AVG')),
    tax_id              VARCHAR(64),
    geo_lat             NUMERIC(9, 6),
    geo_lng             NUMERIC(9, 6),
    is_chat_open        BOOLEAN NOT NULL DEFAULT FALSE,
    trust_score         NUMERIC(5, 2) NOT NULL DEFAULT 100.00 CHECK (trust_score BETWEEN 0 AND 100),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE organization_members (
    org_id      UUID NOT NULL REFERENCES organizations(id),
    user_id     UUID NOT NULL REFERENCES users(id),
    role        VARCHAR(32) NOT NULL CHECK (role IN ('OWNER', 'ACCOUNTANT', 'CASHIER', 'DRIVER', 'AUDITOR')),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (org_id, user_id)
);

-- ----------------------------------------------------------------------------
-- LAYER 4: DOUBLE-ENTRY ACCOUNTING ENGINE (IMMUTABLE LEDGER)
-- ----------------------------------------------------------------------------
CREATE TABLE accounts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID NOT NULL REFERENCES organizations(id),
    code            VARCHAR(32) NOT NULL,
    name            VARCHAR(200) NOT NULL,
    account_type    VARCHAR(24) NOT NULL CHECK (account_type IN ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE')),
    currency        CHAR(3) NOT NULL DEFAULT 'USD',
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (org_id, code)
);

CREATE TABLE journal_entries (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organizations(id),
    idempotency_key     VARCHAR(128) NOT NULL,
    reference_type      VARCHAR(48) NOT NULL, -- INVOICE, PAYMENT, DELIVERY, RETURN, REVERSAL, GATE_DOC
    reference_id        UUID NOT NULL,
    entry_date          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    description         TEXT NOT NULL,
    currency            CHAR(3) NOT NULL,
    exchange_rate       NUMERIC(18, 6) NOT NULL DEFAULT 1.000000 CHECK (exchange_rate > 0),
    status              VARCHAR(16) NOT NULL DEFAULT 'POSTED' CHECK (status IN ('POSTED', 'REVERSED')),
    reversed_by_id      UUID REFERENCES journal_entries(id),
    created_by          UUID NOT NULL REFERENCES users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (org_id, idempotency_key)
);

CREATE TABLE journal_lines (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    journal_entry_id    UUID NOT NULL REFERENCES journal_entries(id),
    org_id              UUID NOT NULL REFERENCES organizations(id),
    account_id          UUID NOT NULL REFERENCES accounts(id),
    party_org_id        UUID REFERENCES organizations(id),
    debit               NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (debit >= 0),
    credit              NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (credit >= 0),
    base_debit          NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (base_debit >= 0),
    base_credit         NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (base_credit >= 0),
    CHECK ((debit > 0 AND credit = 0) OR (credit > 0 AND debit = 0))
);

-- Enforce Double-Entry Balance at Transaction Commit (DEFERRABLE CONSTRAINT TRIGGER)
CREATE OR REPLACE FUNCTION fn_verify_journal_balance() RETURNS TRIGGER AS $$
DECLARE
    v_debit  NUMERIC(18, 4);
    v_credit NUMERIC(18, 4);
    v_count  INTEGER;
BEGIN
    SELECT COALESCE(SUM(debit), 0), COALESCE(SUM(credit), 0), COUNT(*)
    INTO v_debit, v_credit, v_count
    FROM journal_lines
    WHERE journal_entry_id = NEW.journal_entry_id;

    IF v_count < 2 THEN
        RAISE EXCEPTION 'DOUBLE_ENTRY_VIOLATION: Journal entry % must have at least 2 lines.', NEW.journal_entry_id;
    END IF;

    IF v_debit <> v_credit THEN
        RAISE EXCEPTION 'DOUBLE_ENTRY_VIOLATION: Entry % unbalanced (Debit=%, Credit=%).', NEW.journal_entry_id, v_debit, v_credit;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE CONSTRAINT TRIGGER trg_verify_journal_balance
AFTER INSERT ON journal_lines
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION fn_verify_journal_balance();

-- Enforce Strict Ledger Immutability (No UPDATE/DELETE on posted lines; corrections via Reversal Entries only)
CREATE OR REPLACE FUNCTION fn_prevent_ledger_mutation() RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'LEDGER_IMMUTABILITY_VIOLATION: Posted journal lines cannot be modified or deleted. Create a reversal entry instead.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_immutable_journal_lines
BEFORE UPDATE OR DELETE ON journal_lines
FOR EACH ROW EXECUTE FUNCTION fn_prevent_ledger_mutation();

-- ----------------------------------------------------------------------------
-- IAS 2 INVENTORY ENGINE (FIFO LAYERS & WEIGHTED AVERAGE)
-- ----------------------------------------------------------------------------
CREATE TABLE items (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organizations(id),
    sku                 VARCHAR(64) NOT NULL,
    global_barcode      VARCHAR(64),
    name                VARCHAR(200) NOT NULL,
    unit                VARCHAR(32) NOT NULL DEFAULT 'UNIT',
    sale_price          NUMERIC(18, 4) NOT NULL CHECK (sale_price >= 0),
    currency            CHAR(3) NOT NULL DEFAULT 'USD',
    is_perishable       BOOLEAN NOT NULL DEFAULT FALSE,
    dispute_window_min  INTEGER NOT NULL DEFAULT 1440, -- 30 min for perishables, 24h default
    qty_on_hand         NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (qty_on_hand >= 0),
    qty_reserved        NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (qty_reserved >= 0),
    weighted_avg_cost   NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (weighted_avg_cost >= 0),
    row_version         INTEGER NOT NULL DEFAULT 1, -- Optimistic concurrency control
    UNIQUE (org_id, sku)
);

CREATE TABLE inventory_fifo_layers (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organizations(id),
    item_id             UUID NOT NULL REFERENCES items(id),
    source_doc_id       UUID NOT NULL,
    received_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    unit_cost           NUMERIC(18, 4) NOT NULL CHECK (unit_cost >= 0),
    qty_original        NUMERIC(18, 4) NOT NULL CHECK (qty_original > 0),
    qty_remaining       NUMERIC(18, 4) NOT NULL CHECK (qty_remaining >= 0)
);

-- ----------------------------------------------------------------------------
-- TRADE GATES (THREE SEPARATE DECISIONS: PAIRING -> GATE APPROVAL -> POSTING)
-- ----------------------------------------------------------------------------
CREATE TABLE pairings (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_a_id        UUID NOT NULL REFERENCES organizations(id),
    org_b_id        UUID NOT NULL REFERENCES organizations(id),
    status          VARCHAR(16) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACTIVE', 'SUSPENDED', 'REVOKED')),
    requested_by    UUID NOT NULL REFERENCES users(id),
    approved_by     UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CHECK (org_a_id <> org_b_id)
);

CREATE TABLE trade_gates (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pairing_id          UUID NOT NULL REFERENCES pairings(id),
    gate_type           VARCHAR(32) NOT NULL CHECK (gate_type IN (
                            'LOADING_CUSTODY', 'SALES_RETURNS', 'EXPENSES_FUEL',
                            'CASH_REMITTANCE', 'SHARED_STATEMENT'
                        )),
    sender_org_id       UUID NOT NULL REFERENCES organizations(id),
    receiver_org_id     UUID NOT NULL REFERENCES organizations(id),
    approved_by_sender  BOOLEAN NOT NULL DEFAULT FALSE,
    approved_by_receiver BOOLEAN NOT NULL DEFAULT FALSE,
    status              VARCHAR(16) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING', 'ACTIVE', 'PAUSED', 'CLOSED')),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE gate_documents (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gate_id                 UUID NOT NULL REFERENCES trade_gates(id),
    idempotency_key         VARCHAR(128) NOT NULL UNIQUE,
    doc_type                VARCHAR(32) NOT NULL,
    ubl_payload_json        JSONB NOT NULL,
    payload_sha256          CHAR(64) NOT NULL, -- Triple-entry cryptographic receipt hash
    state                   VARCHAR(20) NOT NULL DEFAULT 'DRAFT' CHECK (state IN (
                                'DRAFT', 'SENT', 'UNDER_REVIEW', 'DISPUTED', 'APPROVED', 'POSTED'
                            )),
    sender_journal_id       UUID REFERENCES journal_entries(id),
    receiver_journal_id     UUID REFERENCES journal_entries(id),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- QR LIVE CART, P2P AUTHORIZE/CAPTURE ORDERS, DISPUTES & BLIND RATINGS
-- ----------------------------------------------------------------------------
CREATE TABLE p2p_orders (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    idempotency_key         VARCHAR(128) NOT NULL UNIQUE,
    seller_org_id           UUID NOT NULL REFERENCES organizations(id),
    buyer_user_id           UUID NOT NULL REFERENCES users(id),
    buyer_org_id            UUID REFERENCES organizations(id),
    payment_mode            VARCHAR(20) NOT NULL CHECK (payment_mode IN ('GATEWAY_PREAUTH', 'CASH', 'CREDIT', 'PARTIAL_CREDIT')),
    payment_status          VARCHAR(24) NOT NULL DEFAULT 'UNPAID' CHECK (payment_status IN ('UNPAID', 'PREAUTHORIZED', 'PARTIALLY_PAID', 'CAPTURED', 'VOIDED')),
    delivery_status         VARCHAR(24) NOT NULL DEFAULT 'PENDING' CHECK (delivery_status IN ('PENDING', 'PARTIALLY_DELIVERED', 'DELIVERED', 'RETURNED')),
    order_state             VARCHAR(24) NOT NULL DEFAULT 'LIVE_CART' CHECK (order_state IN (
                                'LIVE_CART', 'SUBMITTED', 'SELLER_ACCEPTED', 'READY_FOR_HANDOVER',
                                'INSPECTING', 'COMPLETED', 'CANCELLED', 'DISPUTED'
                            )),
    currency                CHAR(3) NOT NULL,
    total_amount            NUMERIC(18, 4) NOT NULL CHECK (total_amount >= 0),
    paid_amount             NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (paid_amount >= 0),
    gateway_auth_ref        VARCHAR(128), -- External licensed PSP reference (Pass-through only)
    hold_expires_at         TIMESTAMPTZ,
    delivered_at            TIMESTAMPTZ,
    cancel_reason_code      VARCHAR(48),
    cancel_fault_party      VARCHAR(16) CHECK (cancel_fault_party IN ('SELLER', 'BUYER', 'NEUTRAL')),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE p2p_order_lines (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id            UUID NOT NULL REFERENCES p2p_orders(id),
    item_id             UUID NOT NULL REFERENCES items(id),
    qty_ordered         NUMERIC(18, 4) NOT NULL CHECK (qty_ordered > 0),
    qty_delivered       NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (qty_delivered >= 0),
    qty_returned        NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (qty_returned >= 0),
    unit_price          NUMERIC(18, 4) NOT NULL CHECK (unit_price >= 0)
);

CREATE TABLE blind_ratings (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    order_id            UUID NOT NULL REFERENCES p2p_orders(id),
    rater_role          VARCHAR(16) NOT NULL CHECK (rater_role IN ('BUYER', 'SELLER')),
    rater_user_id       UUID NOT NULL REFERENCES users(id),
    score               SMALLINT NOT NULL CHECK (score BETWEEN 1 AND 5),
    comment             TEXT,
    is_published        BOOLEAN NOT NULL DEFAULT FALSE,
    reveal_after        TIMESTAMPTZ NOT NULL DEFAULT (NOW() + INTERVAL '7 days'),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (order_id, rater_role)
);

CREATE TABLE audit_logs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id          UUID REFERENCES organizations(id),
    actor_user_id   UUID NOT NULL REFERENCES users(id),
    action          VARCHAR(64) NOT NULL,
    entity_type     VARCHAR(64) NOT NULL,
    entity_id       UUID NOT NULL,
    before_hash     CHAR(64),
    after_hash      CHAR(64),
    ip_address      INET,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ----------------------------------------------------------------------------
-- ROW-LEVEL SECURITY (RLS) FOR STRICT MULTI-TENANT ISOLATION (ANTI-BOLA/IDOR)
-- ----------------------------------------------------------------------------
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE journal_lines ENABLE ROW LEVEL SECURITY;
ALTER TABLE items ENABLE ROW LEVEL SECURITY;
ALTER TABLE inventory_fifo_layers ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_accounts ON accounts
    USING (org_id = current_setting('app.current_org_id', true)::UUID);

CREATE POLICY tenant_isolation_journals ON journal_entries
    USING (org_id = current_setting('app.current_org_id', true)::UUID);

CREATE POLICY tenant_isolation_lines ON journal_lines
    USING (org_id = current_setting('app.current_org_id', true)::UUID);

CREATE POLICY tenant_isolation_items ON items
    USING (org_id = current_setting('app.current_org_id', true)::UUID);

CREATE POLICY tenant_isolation_fifo ON inventory_fifo_layers
    USING (org_id = current_setting('app.current_org_id', true)::UUID);
