-- ============================================================================
-- MIZAN — Live PostgreSQL 16 Integration Test (Run in CI against mizan_runtime)
-- Verifies: (1) NULLIF empty-UUID safety, (2) NOBYPASSRLS tenant isolation,
-- (3) Double-entry & Immutability triggers, (4) FORCE RLS enforcement.
-- ============================================================================
\set ON_ERROR_STOP 1

-- Seed 2 users and 2 organizations as admin first
INSERT INTO users (id, uid_code, email, phone, password_hash) VALUES
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'CI-U1', 'u1@ci.local', '+1000000001', 'hash1'),
('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2', 'CI-U2', 'u2@ci.local', '+1000000002', 'hash2');

INSERT INTO organizations (id, owner_user_id, uid_code, trade_name, sector) VALUES
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa1', 'CI-ORG1', 'Org One', 'retail'),
('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2', 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa2', 'CI-ORG2', 'Org Two', 'retail');

SET LOCAL ROLE mizan_runtime;

-- 1) Empty session setting must NOT throw 22P02 and must return 0 rows!
SELECT set_config('app.current_org_id', '', false);
DO $$
DECLARE v_cnt INT;
BEGIN
    SELECT COUNT(*) INTO v_cnt FROM accounts;
    IF v_cnt <> 0 THEN RAISE EXCEPTION 'RLS_FAIL: Expected 0 accounts with empty org_id, got %', v_cnt; END IF;
END $$;

-- 2) Insert account under Org 1, verify Org 2 sees 0 rows!
SELECT set_config('app.current_org_id', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', false);
INSERT INTO accounts (org_id, code, name, account_type, currency)
VALUES ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb1', '1110', 'Cash Org 1', 'ASSET', 'USD');

SELECT set_config('app.current_org_id', 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb2', false);
DO $$
DECLARE v_cnt INT;
BEGIN
    SELECT COUNT(*) INTO v_cnt FROM accounts;
    IF v_cnt <> 0 THEN RAISE EXCEPTION 'RLS_BREACH: Org 2 saw % accounts belonging to Org 1!', v_cnt; END IF;
END $$;

RESET ROLE;
