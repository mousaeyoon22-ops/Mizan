-- ============================================================================
-- MIZAN (ميزان) — Migration 010: NULLIF-Safe UUID Session Helper & RLS Hardening
-- Fixes DEF-401 (P0): Prevents PostgreSQL ERROR 22P02 (`invalid input syntax for type uuid: ""`)
-- whenever `app.current_org_id` or `app.current_user_id` is unset or empty string.
-- ============================================================================

CREATE OR REPLACE FUNCTION mizan_current_org_id() RETURNS UUID AS $$
    SELECT NULLIF(current_setting('app.current_org_id', true), '')::UUID;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION mizan_current_user_id() RETURNS UUID AS $$
    SELECT NULLIF(current_setting('app.current_user_id', true), '')::UUID;
$$ LANGUAGE SQL STABLE;

-- Recreate all 22 tenant/user RLS policies using NULLIF-safe helpers + explicit WITH CHECK
DROP POLICY IF EXISTS tenant_isolation_accounts ON accounts;
CREATE POLICY tenant_isolation_accounts ON accounts
    USING (org_id = mizan_current_org_id()) WITH CHECK (org_id = mizan_current_org_id());

DROP POLICY IF EXISTS tenant_isolation_journals ON journal_entries;
CREATE POLICY tenant_isolation_journals ON journal_entries
    USING (org_id = mizan_current_org_id()) WITH CHECK (org_id = mizan_current_org_id());

DROP POLICY IF EXISTS tenant_isolation_lines ON journal_lines;
CREATE POLICY tenant_isolation_lines ON journal_lines
    USING (org_id = mizan_current_org_id()) WITH CHECK (org_id = mizan_current_org_id());

DROP POLICY IF EXISTS tenant_isolation_items ON items;
CREATE POLICY tenant_isolation_items ON items
    USING (org_id = mizan_current_org_id()) WITH CHECK (org_id = mizan_current_org_id());

DROP POLICY IF EXISTS tenant_isolation_fifo ON inventory_fifo_layers;
CREATE POLICY tenant_isolation_fifo ON inventory_fifo_layers
    USING (org_id = mizan_current_org_id()) WITH CHECK (org_id = mizan_current_org_id());

DROP POLICY IF EXISTS tenant_isolation_feature_prefs ON org_feature_preferences;
CREATE POLICY tenant_isolation_feature_prefs ON org_feature_preferences
    USING (org_id = mizan_current_org_id()) WITH CHECK (org_id = mizan_current_org_id());

DROP POLICY IF EXISTS tenant_isolation_fx_vouchers ON fx_exchange_vouchers;
CREATE POLICY tenant_isolation_fx_vouchers ON fx_exchange_vouchers
    USING (org_id = mizan_current_org_id()) WITH CHECK (org_id = mizan_current_org_id());

DROP POLICY IF EXISTS tenant_isolation_p2p_orders ON p2p_orders;
CREATE POLICY tenant_isolation_p2p_orders ON p2p_orders
    USING (
        seller_org_id = mizan_current_org_id()
        OR buyer_org_id = mizan_current_org_id()
        OR buyer_user_id = mizan_current_user_id()
    )
    WITH CHECK (
        seller_org_id = mizan_current_org_id()
        OR buyer_org_id = mizan_current_org_id()
        OR buyer_user_id = mizan_current_user_id()
    );

DROP POLICY IF EXISTS tenant_isolation_audit_logs ON audit_logs;
CREATE POLICY tenant_isolation_audit_logs ON audit_logs
    USING (org_id = mizan_current_org_id()) WITH CHECK (org_id = mizan_current_org_id());

DROP POLICY IF EXISTS tenant_isolation_trade_gates ON trade_gates;
CREATE POLICY tenant_isolation_trade_gates ON trade_gates
    USING (sender_org_id = mizan_current_org_id() OR receiver_org_id = mizan_current_org_id())
    WITH CHECK (sender_org_id = mizan_current_org_id() OR receiver_org_id = mizan_current_org_id());

DROP POLICY IF EXISTS tenant_isolation_gate_documents ON gate_documents;
CREATE POLICY tenant_isolation_gate_documents ON gate_documents
    USING (
        EXISTS (
            SELECT 1 FROM trade_gates tg
            WHERE tg.id = gate_documents.gate_id
              AND (tg.sender_org_id = mizan_current_org_id() OR tg.receiver_org_id = mizan_current_org_id())
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM trade_gates tg
            WHERE tg.id = gate_documents.gate_id
              AND (tg.sender_org_id = mizan_current_org_id() OR tg.receiver_org_id = mizan_current_org_id())
        )
    );

DROP POLICY IF EXISTS tenant_isolation_pos_terminals ON pos_terminals;
CREATE POLICY tenant_isolation_pos_terminals ON pos_terminals
    USING (org_id = mizan_current_org_id()) WITH CHECK (org_id = mizan_current_org_id());

DROP POLICY IF EXISTS tenant_isolation_pos_shifts ON pos_shifts;
CREATE POLICY tenant_isolation_pos_shifts ON pos_shifts
    USING (org_id = mizan_current_org_id()) WITH CHECK (org_id = mizan_current_org_id());

DROP POLICY IF EXISTS tenant_isolation_item_variants ON item_variants;
CREATE POLICY tenant_isolation_item_variants ON item_variants
    USING (org_id = mizan_current_org_id()) WITH CHECK (org_id = mizan_current_org_id());

DROP POLICY IF EXISTS tenant_isolation_pos_sales ON pos_sales;
CREATE POLICY tenant_isolation_pos_sales ON pos_sales
    USING (org_id = mizan_current_org_id()) WITH CHECK (org_id = mizan_current_org_id());

DROP POLICY IF EXISTS tenant_isolation_pos_sale_lines ON pos_sale_lines;
CREATE POLICY tenant_isolation_pos_sale_lines ON pos_sale_lines
    USING (org_id = mizan_current_org_id()) WITH CHECK (org_id = mizan_current_org_id());

DROP POLICY IF EXISTS user_isolation_a11y_profile ON user_accessibility_profiles;
CREATE POLICY user_isolation_a11y_profile ON user_accessibility_profiles
    USING (user_id = mizan_current_user_id()) WITH CHECK (user_id = mizan_current_user_id());

DROP POLICY IF EXISTS tenant_isolation_voice_audit ON voice_command_audit;
CREATE POLICY tenant_isolation_voice_audit ON voice_command_audit
    USING (org_id = mizan_current_org_id()) WITH CHECK (org_id = mizan_current_org_id());

DROP POLICY IF EXISTS tenant_isolation_user_workspace_prefs ON user_workspace_preferences;
CREATE POLICY tenant_isolation_user_workspace_prefs ON user_workspace_preferences
    USING (org_id = mizan_current_org_id() AND user_id = mizan_current_user_id())
    WITH CHECK (org_id = mizan_current_org_id() AND user_id = mizan_current_user_id());

DROP POLICY IF EXISTS tenant_isolation_org_role_mode_policies ON org_role_mode_policies;
CREATE POLICY tenant_isolation_org_role_mode_policies ON org_role_mode_policies
    USING (org_id = mizan_current_org_id()) WITH CHECK (org_id = mizan_current_org_id());

DROP POLICY IF EXISTS tenant_isolation_meter_readings ON meter_readings;
CREATE POLICY tenant_isolation_meter_readings ON meter_readings
    USING (org_id = mizan_current_org_id()) WITH CHECK (org_id = mizan_current_org_id());

DROP POLICY IF EXISTS tenant_isolation_equipment_custody ON equipment_custody_logs;
CREATE POLICY tenant_isolation_equipment_custody ON equipment_custody_logs
    USING (org_id = mizan_current_org_id()) WITH CHECK (org_id = mizan_current_org_id());

-- Ensure mizan_runtime can execute the helper functions
GRANT EXECUTE ON FUNCTION mizan_current_org_id() TO mizan_runtime;
GRANT EXECUTE ON FUNCTION mizan_current_user_id() TO mizan_runtime;
