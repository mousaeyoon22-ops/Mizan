import json
import sqlite3
import os
from datetime import datetime, timezone

def run_tests():
    results = []
    conn = sqlite3.connect(":memory:")
    conn.execute("PRAGMA foreign_keys = ON;")

    # Mirror PostgreSQL governance schema & strict guard triggers in SQLite
    conn.executescript("""
    CREATE TABLE platform_feature_registry (
        feature_key       TEXT PRIMARY KEY,
        category          TEXT NOT NULL,
        release_phase     INTEGER NOT NULL,
        is_immutable_core INTEGER NOT NULL DEFAULT 0,
        platform_enabled  INTEGER NOT NULL DEFAULT 0,
        org_configurable  INTEGER NOT NULL DEFAULT 1,
        default_org_state INTEGER NOT NULL DEFAULT 0,
        requires_feature  TEXT REFERENCES platform_feature_registry(feature_key)
    );

    CREATE TABLE org_feature_preferences (
        org_id      TEXT NOT NULL,
        feature_key TEXT NOT NULL REFERENCES platform_feature_registry(feature_key),
        is_enabled  INTEGER NOT NULL CHECK (is_enabled IN (0, 1)),
        PRIMARY KEY (org_id, feature_key)
    );

    CREATE TABLE feature_toggle_audit (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        org_id         TEXT,
        feature_key    TEXT NOT NULL,
        previous_state INTEGER,
        new_state      INTEGER NOT NULL,
        actor          TEXT NOT NULL,
        created_at     TEXT NOT NULL
    );

    -- Guard 1: Immutable Core cannot be turned OFF
    CREATE TRIGGER trg_block_disable_core
    BEFORE INSERT ON org_feature_preferences
    WHEN NEW.is_enabled = 0 AND (SELECT is_immutable_core FROM platform_feature_registry WHERE feature_key = NEW.feature_key) = 1
    BEGIN SELECT RAISE(ABORT, 'CORE_FEATURE_IMMUTABLE'); END;

    -- Guard 2: Platform-locked Phase 2/3 feature cannot be enabled by any org
    CREATE TRIGGER trg_block_platform_locked
    BEFORE INSERT ON org_feature_preferences
    WHEN NEW.is_enabled = 1 AND (
        (SELECT platform_enabled FROM platform_feature_registry WHERE feature_key = NEW.feature_key) = 0
        OR (SELECT org_configurable FROM platform_feature_registry WHERE feature_key = NEW.feature_key) = 0
    )
    BEGIN SELECT RAISE(ABORT, 'FEATURE_LOCKED_BY_PLATFORM'); END;

    -- Seed all 16 Mizan features
    INSERT INTO platform_feature_registry VALUES
    ('CORE_DOUBLE_ENTRY_LEDGER',    'CORE',        1, 1, 1, 0, 1, NULL),
    ('OFFLINE_SQLITE_OUTBOX',       'CORE',        1, 1, 1, 0, 1, NULL),
    ('TRADE_GATES_EXCHANGE',        'CORE',        1, 0, 1, 1, 1, 'CORE_DOUBLE_ENTRY_LEDGER'),
    ('QR_CATALOG_SELF_CHECKOUT',    'COMMERCE',    1, 0, 1, 1, 1, 'CORE_DOUBLE_ENTRY_LEDGER'),
    ('MULTI_LANGUAGE_UI',           'CORE',        1, 0, 1, 1, 1, NULL),
    ('MULTI_CURRENCY_LEDGER',       'CORE',        1, 0, 1, 1, 1, 'CORE_DOUBLE_ENTRY_LEDGER'),
    ('CONTEXTUAL_TRANSACTION_CHAT', 'COMMERCE',    1, 0, 1, 1, 0, 'TRADE_GATES_EXCHANGE'),
    ('PUBLIC_NEARBY_DIRECTORY',     'COMMERCE',    1, 0, 1, 1, 0, 'QR_CATALOG_SELF_CHECKOUT'),
    ('BLIND_MUTUAL_RATINGS',        'COMMERCE',    1, 0, 1, 1, 0, 'QR_CATALOG_SELF_CHECKOUT'),
    ('PERISHABLE_LIVE_CAM_DISPUTES','COMMERCE',    1, 0, 1, 1, 0, 'QR_CATALOG_SELF_CHECKOUT'),
    ('KYC_STRICT_TIERS_2_TO_4',     'COMPLIANCE',  2, 0, 0, 1, 0, NULL),
    ('PSP_PASS_THROUGH_PREAUTH',    'FINTECH',     2, 0, 0, 1, 0, 'KYC_STRICT_TIERS_2_TO_4'),
    ('TAX_EINVOICING_PEPPOL_ZATCA', 'COMPLIANCE',  2, 0, 0, 1, 0, 'CORE_DOUBLE_ENTRY_LEDGER'),
    ('ERP_CONNECTORS_OAUTH',        'INTEGRATION', 3, 0, 0, 1, 0, 'TRADE_GATES_EXCHANGE'),
    ('AI_FINANCIAL_COPILOT_OCR',    'AI',          3, 0, 0, 1, 0, 'CORE_DOUBLE_ENTRY_LEDGER'),
    ('INTERNAL_WALLET_CUSTODY',     'FINTECH',     3, 0, 0, 0, 0, 'KYC_STRICT_TIERS_2_TO_4');
    """)

    def is_effective_enabled(org_id, key):
        row = conn.execute("""
            SELECT p.is_immutable_core, p.platform_enabled, p.default_org_state, p.requires_feature, o.is_enabled
            FROM platform_feature_registry p
            LEFT JOIN org_feature_preferences o ON o.feature_key = p.feature_key AND o.org_id = ?
            WHERE p.feature_key = ?
        """, (org_id, key)).fetchone()
        if not row:
            return False
        imm, plat, default_s, req, org_s = row
        if imm == 1:
            return True
        if plat == 0:
            return False
        if req and not is_effective_enabled(org_id, req):
            return False
        return bool(org_s if org_s is not None else default_s)

    def set_org_pref(org_id, key, state, actor="owner-1"):
        prev = 1 if is_effective_enabled(org_id, key) else 0
        # Check dependency before enabling
        req = conn.execute("SELECT requires_feature FROM platform_feature_registry WHERE feature_key=?", (key,)).fetchone()[0]
        if state == 1 and req and not is_effective_enabled(org_id, req):
            raise RuntimeError(f"FEATURE_DEPENDENCY_MISSING:{req}")
        with conn:
            conn.execute("DELETE FROM org_feature_preferences WHERE org_id=? AND feature_key=?", (org_id, key))
            conn.execute("INSERT INTO org_feature_preferences VALUES (?, ?, ?)", (org_id, key, state))
            conn.execute("INSERT INTO feature_toggle_audit(org_id, feature_key, previous_state, new_state, actor, created_at) VALUES (?,?,?,?,?,?)",
                         (org_id, key, prev, state, actor, datetime.now(timezone.utc).isoformat()))

    def record(tid, cat, title, passed, evidence):
        results.append({"test_id": tid, "category": cat, "title": title, "status": "PASS" if passed else "FAIL", "evidence": evidence})

    # TEST 1: Phase 1 Default Matrix Check (6 Active Core, 4 Org-Optional OFF, 6 Platform-Locked Phase 2/3 OFF)
    org = "ORG_SEHA_WATER"
    keys = [r[0] for r in conn.execute("SELECT feature_key FROM platform_feature_registry").fetchall()]
    active_p1 = [k for k in keys if is_effective_enabled(org, k)]
    inactive_p1 = [k for k in keys if not is_effective_enabled(org, k)]
    record("GOV-01", "Phase 1 Defaults", "Exactly 6 core features ON and 10 optional/Phase 2-3 features OFF by default",
           len(active_p1) == 6 and len(inactive_p1) == 10 and "INTERNAL_WALLET_CUSTODY" in inactive_p1 and "PSP_PASS_THROUGH_PREAUTH" in inactive_p1,
           f"Active={len(active_p1)}, Inactive={len(inactive_p1)}")

    # TEST 2: Core Ledger Immutability (Cannot disable CORE_DOUBLE_ENTRY_LEDGER)
    blocked_core = False
    try:
        set_org_pref(org, "CORE_DOUBLE_ENTRY_LEDGER", 0)
    except sqlite3.IntegrityError as e:
        blocked_core = "CORE_FEATURE_IMMUTABLE" in str(e)
    record("GOV-02", "Core Protection", "Database trigger blocks disabling immutable CORE_DOUBLE_ENTRY_LEDGER",
           blocked_core and is_effective_enabled(org, "CORE_DOUBLE_ENTRY_LEDGER"),
           f"blocked_core={blocked_core}")

    # TEST 3: Platform Lock Protection (Org cannot enable Phase 2 PSP or Phase 3 Wallet/ERP)
    blocked_psp, blocked_wallet, blocked_erp = False, False, False
    for key in ["PSP_PASS_THROUGH_PREAUTH", "INTERNAL_WALLET_CUSTODY", "ERP_CONNECTORS_OAUTH"]:
        try:
            conn.execute("INSERT INTO org_feature_preferences VALUES (?, ?, 1)", (org, key))
        except sqlite3.IntegrityError as e:
            if "FEATURE_LOCKED_BY_PLATFORM" in str(e):
                if key == "PSP_PASS_THROUGH_PREAUTH": blocked_psp = True
                if key == "INTERNAL_WALLET_CUSTODY": blocked_wallet = True
                if key == "ERP_CONNECTORS_OAUTH": blocked_erp = True
    record("GOV-03", "Platform Gate", "Phase 2/3 extensions (PSP, Wallet, ERP) cannot be bypassed by tenants while platform-locked",
           blocked_psp and blocked_wallet and blocked_erp,
           f"blocked_psp={blocked_psp}, blocked_wallet={blocked_wallet}, blocked_erp={blocked_erp}")

    # TEST 4: Org Owner cleanly toggles Phase-1 Optional Module (Contextual Chat OFF -> ON -> OFF) + Audit Log
    before_chat = is_effective_enabled(org, "CONTEXTUAL_TRANSACTION_CHAT")
    set_org_pref(org, "CONTEXTUAL_TRANSACTION_CHAT", 1)
    after_on = is_effective_enabled(org, "CONTEXTUAL_TRANSACTION_CHAT")
    set_org_pref(org, "CONTEXTUAL_TRANSACTION_CHAT", 0)
    after_off = is_effective_enabled(org, "CONTEXTUAL_TRANSACTION_CHAT")
    audit_count = conn.execute("SELECT COUNT(*) FROM feature_toggle_audit WHERE feature_key='CONTEXTUAL_TRANSACTION_CHAT'").fetchone()[0]
    record("GOV-04", "Org Preferences", "Org owner toggles Phase-1 optional feature cleanly with full audit trail",
           (not before_chat) and after_on and (not after_off) and audit_count == 2,
           f"before={before_chat}, on={after_on}, off={after_off}, audit_entries={audit_count}")

    # TEST 5: Dependency Chain Enforcement (Unlocking PSP in Phase 2 still blocked until KYC Tier 2-4 is enabled)
    conn.execute("UPDATE platform_feature_registry SET platform_enabled = 1 WHERE feature_key IN ('KYC_STRICT_TIERS_2_TO_4', 'PSP_PASS_THROUGH_PREAUTH')")
    dep_blocked = False
    try:
        set_org_pref(org, "PSP_PASS_THROUGH_PREAUTH", 1)
    except RuntimeError as e:
        dep_blocked = "FEATURE_DEPENDENCY_MISSING:KYC_STRICT_TIERS_2_TO_4" in str(e)
    # Now enable prerequisite KYC first, then PSP succeeds!
    set_org_pref(org, "KYC_STRICT_TIERS_2_TO_4", 1)
    set_org_pref(org, "PSP_PASS_THROUGH_PREAUTH", 1)
    psp_now_on = is_effective_enabled(org, "PSP_PASS_THROUGH_PREAUTH")
    record("GOV-05", "Dependency Graph", "Enabling PSP in Phase 2 enforces KYC Tier 2-4 prerequisite before activation",
           dep_blocked and psp_now_on,
           f"blocked_without_kyc={dep_blocked}, enabled_after_kyc={psp_now_on}")

    # TEST 6: Global Kill-Switch Cascade (Disabling Platform KYC immediately shuts off dependent PSP too)
    conn.execute("UPDATE platform_feature_registry SET platform_enabled = 0 WHERE feature_key = 'KYC_STRICT_TIERS_2_TO_4'")
    psp_cascaded_off = not is_effective_enabled(org, "PSP_PASS_THROUGH_PREAUTH")
    record("GOV-06", "Kill-Switch", "Platform kill-switch on prerequisite cascades immediately to dependent modules",
           psp_cascaded_off, f"psp_cascaded_off={psp_cascaded_off}")

    # TEST 7: Multi-Tenant Isolation (Enabling Public Directory for Org A does NOT affect Org B)
    org_b = "ORG_SHOP_B"
    set_org_pref(org, "PUBLIC_NEARBY_DIRECTORY", 1)
    a_state = is_effective_enabled(org, "PUBLIC_NEARBY_DIRECTORY")
    b_state = is_effective_enabled(org_b, "PUBLIC_NEARBY_DIRECTORY")
    record("GOV-07", "Tenant Isolation", "Organization preference toggle is strictly isolated per tenant",
           a_state and (not b_state), f"OrgA={a_state}, OrgB={b_state}")

    return {
        "executed_at_utc": datetime.now(timezone.utc).isoformat(),
        "total_tests": len(results),
        "passed": sum(1 for r in results if r["status"] == "PASS"),
        "failed": sum(1 for r in results if r["status"] == "FAIL"),
        "results": results
    }

if __name__ == "__main__":
    print(json.dumps(run_tests(), indent=2, ensure_ascii=False))
