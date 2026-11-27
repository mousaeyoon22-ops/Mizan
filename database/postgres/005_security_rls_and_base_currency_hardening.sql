-- ============================================================================
-- MIZAN (ميزان) — Migration 005: Security RLS Hardening & Base-Currency Integrity
-- Fixes DEF-006 identified during independent security & accounting audit
-- ============================================================================

ALTER TABLE journal_lines
    ADD CONSTRAINT chk_base_mirrors_tx_side
    CHECK (
        (debit > 0 AND base_debit > 0 AND credit = 0 AND base_credit = 0)
        OR
        (credit > 0 AND base_credit > 0 AND debit = 0 AND base_debit = 0)
    );

ALTER TABLE p2p_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE trade_gates ENABLE ROW LEVEL SECURITY;
ALTER TABLE gate_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY tenant_isolation_p2p_orders ON p2p_orders
    USING (
        seller_org_id = current_setting('app.current_org_id', true)::UUID
        OR buyer_org_id = current_setting('app.current_org_id', true)::UUID
        OR buyer_user_id = current_setting('app.current_user_id', true)::UUID
    );

CREATE POLICY tenant_isolation_audit_logs ON audit_logs
    USING (org_id = current_setting('app.current_org_id', true)::UUID);

CREATE POLICY tenant_isolation_trade_gates ON trade_gates
    USING (
        sender_org_id = current_setting('app.current_org_id', true)::UUID
        OR receiver_org_id = current_setting('app.current_org_id', true)::UUID
    );

CREATE POLICY tenant_isolation_gate_documents ON gate_documents
    USING (
        EXISTS (
            SELECT 1 FROM trade_gates tg
            WHERE tg.id = gate_documents.gate_id
              AND (
                  tg.sender_org_id = current_setting('app.current_org_id', true)::UUID
                  OR tg.receiver_org_id = current_setting('app.current_org_id', true)::UUID
              )
        )
    );

CREATE OR REPLACE FUNCTION fn_prevent_audit_log_mutation() RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'AUDIT_LOG_IMMUTABILITY_VIOLATION: Audit logs are strictly append-only.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_immutable_audit_logs
BEFORE UPDATE OR DELETE ON audit_logs
FOR EACH ROW EXECUTE FUNCTION fn_prevent_audit_log_mutation();
