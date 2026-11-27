-- ============================================================================
-- MIZAN (ميزان) — Migration 004: Peak-Hour Performance Indexes & Tuning
-- Fixes P0/P1 peak bottlenecks discovered during stress auditing of Migrations 001-003
-- ============================================================================

-- P0 FIX: Accelerate DEFERRABLE triggers (fn_verify_journal_balance & fn_verify_base_currency_balance)
-- Without this index, every journal_lines INSERT triggers a full table scan on journal_lines.
CREATE INDEX IF NOT EXISTS idx_jl_journal_entry_id
    ON journal_lines (journal_entry_id);

-- P0 FIX: Fast Trial Balance, Account Balance & Party Statement reconciliation under RLS
CREATE INDEX IF NOT EXISTS idx_jl_org_account_party
    ON journal_lines (org_id, account_id, party_org_id)
    INCLUDE (debit, credit, base_debit, base_credit);

CREATE INDEX IF NOT EXISTS idx_je_org_entry_date
    ON journal_entries (org_id, entry_date DESC);

-- P1 FIX: Partial Composite Index for IAS 2 FIFO Layer Depletion (scans ONLY active layers with stock > 0)
CREATE INDEX IF NOT EXISTS idx_fifo_active_layers
    ON inventory_fifo_layers (org_id, item_id, received_at ASC)
    WHERE qty_remaining > 0;

-- P1 FIX: Fast Hot-SKU lookup & QR catalog loading
CREATE INDEX IF NOT EXISTS idx_items_org_barcode
    ON items (org_id, global_barcode)
    WHERE global_barcode IS NOT NULL;

-- P1 FIX: Trade Gates & Document State Machine lookups
CREATE INDEX IF NOT EXISTS idx_gate_docs_gate_state
    ON gate_documents (gate_id, state, updated_at DESC);

CREATE INDEX IF NOT EXISTS idx_trade_gates_parties
    ON trade_gates (sender_org_id, receiver_org_id, status);

-- P1 FIX: Partial Index for Hangfire 30-Minute Hold Expiration Job & Live Order Dashboard
CREATE INDEX IF NOT EXISTS idx_p2p_orders_active_holds
    ON p2p_orders (hold_expires_at)
    WHERE order_state IN ('LIVE_CART', 'SUBMITTED') AND hold_expires_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_p2p_orders_seller_state
    ON p2p_orders (seller_org_id, order_state, created_at DESC);

-- P1 FIX: Partial Index for Hangfire 7-Day Double-Blind Rating Reveal Job
CREATE INDEX IF NOT EXISTS idx_blind_ratings_pending_reveal
    ON blind_ratings (reveal_after)
    WHERE is_published = FALSE;

-- P2 FIX: Fast Audit Log & FX Voucher history pagination
CREATE INDEX IF NOT EXISTS idx_audit_logs_org_time
    ON audit_logs (org_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_fx_vouchers_org_time
    ON fx_exchange_vouchers (org_id, created_at DESC);
