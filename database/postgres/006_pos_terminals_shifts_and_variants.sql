-- ============================================================================
-- MIZAN (ميزان) — Migration 006: Multi-Cashier Touch POS, Shift/Z-Report
-- Custody & Item Variants Matrix (Sizes/Colors)
-- Operational Governance: ALL 3 modules embedded & OFF by default in Phase 1
-- ============================================================================

-- 1) POS Terminals / Registers (Multiple Cashiers per Store/Mall)
CREATE TABLE pos_terminals (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organizations(id),
    terminal_code       VARCHAR(32) NOT NULL,
    display_name        VARCHAR(120) NOT NULL,
    branch_name         VARCHAR(120),
    cash_account_id     UUID NOT NULL REFERENCES accounts(id), -- Dedicated cash drawer sub-ledger
    printer_width_mm    SMALLINT NOT NULL DEFAULT 80 CHECK (printer_width_mm IN (58, 80)),
    has_cash_drawer     BOOLEAN NOT NULL DEFAULT TRUE,
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (org_id, terminal_code)
);

-- 2) Cashier Shifts & Immutable Z-Reports (Blind Close Cash Custody)
CREATE TABLE pos_shifts (
    id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id                  UUID NOT NULL REFERENCES organizations(id),
    terminal_id             UUID NOT NULL REFERENCES pos_terminals(id),
    cashier_user_id         UUID NOT NULL REFERENCES users(id),
    currency                CHAR(3) NOT NULL,
    status                  VARCHAR(16) NOT NULL DEFAULT 'OPEN' CHECK (status IN ('OPEN', 'CLOSED')),
    opened_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    closed_at               TIMESTAMPTZ,
    opening_float           NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (opening_float >= 0),
    total_cash_sales        NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (total_cash_sales >= 0),
    total_card_sales        NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (total_card_sales >= 0),
    total_credit_sales      NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (total_credit_sales >= 0),
    total_cash_refunds      NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (total_cash_refunds >= 0),
    expected_cash           NUMERIC(18, 4),
    counted_cash            NUMERIC(18, 4),
    cash_variance           NUMERIC(18, 4), -- counted_cash - expected_cash (>0 overage, <0 shortage)
    z_report_number         VARCHAR(64) UNIQUE,
    z_report_sha256         CHAR(64),
    variance_journal_id     UUID REFERENCES journal_entries(id),
    closing_notes           TEXT
);

-- Strict Invariants: Max ONE active OPEN shift per terminal AND per cashier simultaneously
CREATE UNIQUE INDEX uq_pos_one_open_shift_per_terminal
    ON pos_shifts (org_id, terminal_id) WHERE status = 'OPEN';

CREATE UNIQUE INDEX uq_pos_one_open_shift_per_cashier
    ON pos_shifts (org_id, cashier_user_id) WHERE status = 'OPEN';

-- Enforce Z-Report Immutability once shift is CLOSED
CREATE OR REPLACE FUNCTION fn_prevent_closed_shift_mutation() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = 'CLOSED' THEN
        RAISE EXCEPTION 'Z_REPORT_IMMUTABILITY_VIOLATION: Closed shift % and its Z-Report cannot be modified or deleted.', OLD.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_immutable_closed_shifts
BEFORE UPDATE OR DELETE ON pos_shifts
FOR EACH ROW EXECUTE FUNCTION fn_prevent_closed_shift_mutation();

-- 3) Item Variants Matrix (Sizes, Colors, Style Attributes for Apparel Malls & Retail)
CREATE TABLE item_variants (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organizations(id),
    parent_item_id      UUID NOT NULL REFERENCES items(id),
    variant_sku         VARCHAR(80) NOT NULL,
    variant_barcode     VARCHAR(64) NOT NULL,
    size_label          VARCHAR(32),     -- e.g., XS, S, M, L, XL, 42
    color_label         VARCHAR(48),     -- e.g., Navy, Black, White
    color_hex           CHAR(7),         -- e.g., #1E3A8A
    attributes_json     JSONB NOT NULL DEFAULT '{}'::jsonb,
    sale_price_override NUMERIC(18, 4) CHECK (sale_price_override IS NULL OR sale_price_override >= 0),
    qty_on_hand         NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (qty_on_hand >= 0),
    qty_reserved        NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (qty_reserved >= 0),
    row_version         INTEGER NOT NULL DEFAULT 1, -- Optimistic concurrency across simultaneous cashiers
    is_active           BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (org_id, variant_sku),
    UNIQUE (org_id, variant_barcode)
);

-- 4) POS Sales & Parked (Held) Invoices
CREATE TABLE pos_sales (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    org_id              UUID NOT NULL REFERENCES organizations(id),
    idempotency_key     VARCHAR(128) NOT NULL,
    shift_id            UUID NOT NULL REFERENCES pos_shifts(id),
    terminal_id         UUID NOT NULL REFERENCES pos_terminals(id),
    cashier_user_id     UUID NOT NULL REFERENCES users(id),
    receipt_no          VARCHAR(64) NOT NULL,
    sale_state          VARCHAR(16) NOT NULL DEFAULT 'COMPLETED' CHECK (sale_state IN ('PARKED', 'COMPLETED', 'VOIDED', 'REFUNDED')),
    currency            CHAR(3) NOT NULL,
    subtotal_amount     NUMERIC(18, 4) NOT NULL CHECK (subtotal_amount >= 0),
    discount_amount     NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (discount_amount >= 0),
    tax_amount          NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (tax_amount >= 0),
    total_amount        NUMERIC(18, 4) NOT NULL CHECK (total_amount >= 0),
    cash_paid           NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (cash_paid >= 0),
    card_paid           NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (card_paid >= 0),
    credit_amount       NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (credit_amount >= 0),
    journal_entry_id    UUID REFERENCES journal_entries(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (org_id, idempotency_key),
    UNIQUE (org_id, receipt_no),
    CHECK (sale_state <> 'COMPLETED' OR (cash_paid + card_paid + credit_amount = total_amount))
);

CREATE TABLE pos_sale_lines (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sale_id             UUID NOT NULL REFERENCES pos_sales(id),
    org_id              UUID NOT NULL REFERENCES organizations(id),
    item_id             UUID NOT NULL REFERENCES items(id),
    variant_id          UUID REFERENCES item_variants(id),
    qty                 NUMERIC(18, 4) NOT NULL CHECK (qty > 0),
    unit_price          NUMERIC(18, 4) NOT NULL CHECK (unit_price >= 0),
    line_discount       NUMERIC(18, 4) NOT NULL DEFAULT 0.0000 CHECK (line_discount >= 0),
    line_total          NUMERIC(18, 4) NOT NULL CHECK (line_total >= 0)
);

-- 5) Peak Performance Indexes for Multi-Cashier Scanning & Shift Reporting
CREATE INDEX idx_variants_org_parent ON item_variants (org_id, parent_item_id) WHERE is_active = TRUE;
CREATE INDEX idx_pos_sales_shift_time ON pos_sales (org_id, shift_id, created_at DESC);
CREATE INDEX idx_pos_sale_lines_sale ON pos_sale_lines (sale_id);

-- 6) Strict Multi-Tenant Row-Level Security (RLS)
ALTER TABLE pos_terminals ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_shifts ENABLE ROW LEVEL SECURITY;
ALTER TABLE item_variants ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_sales ENABLE ROW LEVEL SECURITY;
ALTER TABLE pos_sale_lines ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_pos_terminals ON pos_terminals USING (org_id = current_setting('app.current_org_id', true)::UUID);
CREATE POLICY tenant_isolation_pos_shifts ON pos_shifts USING (org_id = current_setting('app.current_org_id', true)::UUID);
CREATE POLICY tenant_isolation_item_variants ON item_variants USING (org_id = current_setting('app.current_org_id', true)::UUID);
CREATE POLICY tenant_isolation_pos_sales ON pos_sales USING (org_id = current_setting('app.current_org_id', true)::UUID);
CREATE POLICY tenant_isolation_pos_sale_lines ON pos_sale_lines USING (org_id = current_setting('app.current_org_id', true)::UUID);

-- 7) Register 3 New Operational Feature Flags (OFF by default in Phase 1 — Org Owner can enable anytime)
INSERT INTO platform_feature_registry
(feature_key, category, release_phase, is_immutable_core, platform_enabled, org_configurable, default_org_state, requires_feature, description_ar, description_en)
VALUES
('POS_MULTI_CASHIER_TOUCH', 'COMMERCE', 1, FALSE, TRUE, TRUE, FALSE, 'CORE_DOUBLE_ENTRY_LEDGER', 'وحدة الكاشير المتعدد وشاشة اللمس المنقسمة (Split-Screen POS) والطباعة الحرارية', 'Multi-Cashier Touch Split-Screen POS & Thermal Printing'),
('POS_SHIFTS_AND_Z_REPORT', 'COMMERCE', 1, FALSE, TRUE, TRUE, FALSE, 'POS_MULTI_CASHIER_TOUCH',  'إدارة ورديات الكاشير، عهدة الصندوق، الإغلاق الأعمى وتقارير Z-Report', 'Cashier Shifts, Cash Drawer Custody & Blind Z-Reports'),
('ITEM_VARIANTS_MATRIX',    'COMMERCE', 1, FALSE, TRUE, TRUE, FALSE, 'CORE_DOUBLE_ENTRY_LEDGER', 'مصفوفة المقاسات والألوان والباركود المستقل لكل متغير (مولات الملابس والتجزئة)', 'Item Variants Matrix (Sizes, Colors & Variant Barcodes)')
ON CONFLICT (feature_key) DO NOTHING;
