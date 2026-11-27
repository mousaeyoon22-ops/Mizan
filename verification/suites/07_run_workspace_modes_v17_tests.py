import os
import json
import sqlite3
import zipfile
from datetime import datetime, timezone

ROLE_CEILING = {
    "OWNER":      ["EASY", "STANDARD", "PROFESSIONAL", "EXECUTIVE", "EXPRESS_FIELD"],
    "ACCOUNTANT": ["EASY", "STANDARD", "PROFESSIONAL", "EXECUTIVE"],
    "AUDITOR":    ["STANDARD", "PROFESSIONAL", "EXECUTIVE"],
    "CASHIER":    ["EASY", "STANDARD", "EXPRESS_FIELD"],
    "DRIVER":     ["EASY", "EXPRESS_FIELD"],
}

SENSITIVE = {"gross_profit", "net_profit", "coa_code", "journal_debit_credit", "fifo_cost_layers", "audit_sha256_hash", "branch_consolidated_pnl"}

MODE_SPEC = {
    "EASY":         ("SIMPLE_TRADE",      "SPACIOUS",    3, ["today_cash_simple", "owed_to_me_simple", "owed_by_me_simple"], ["date", "party_name", "simple_direction_label", "amount_currency"]),
    "STANDARD":     ("BALANCED",          "COMFORTABLE", 5, ["cash_and_bank_boxes", "ar_ap_summary", "gross_profit", "clean_a4_daily_report"], ["date", "doc_no", "party_name", "amount_currency", "running_balance"]),
    "PROFESSIONAL": ("STRICT_ACCOUNTING", "COMPACT",     6, ["trial_balance_variance", "coa_tree_navigator", "journal_debit_credit", "fifo_cost_layers", "audit_sha256_hash"], ["entry_date", "coa_code", "tx_debit", "tx_credit", "base_debit", "base_credit", "audit_sha256_hash"]),
    "EXECUTIVE":    ("BALANCED",          "COMFORTABLE", 4, ["branch_consolidated_pnl", "all_cashiers_z_reports", "trust_score_trend"], ["branch_name", "revenue_base", "gross_profit", "net_profit"]),
    "EXPRESS_FIELD":("SIMPLE_TRADE",      "SPACIOUS",    3, ["offline_sync_outbox_strip", "assigned_vehicle_custody", "quick_delivery_scan"], ["customer_name", "qty_delivered", "cash_collected", "sync_status"]),
}

def resolve_mode(role, requested, org_policy=None, motor_large=False, cog_simple=False):
    role = role.upper()
    allowed = ROLE_CEILING[role]
    eff = requested
    clamped = False
    reason = None

    if org_policy and not org_policy["allow_override"] and requested != org_policy["default_mode"]:
        eff = org_policy["default_mode"]
        clamped = True
        reason = f"ORG_POLICY_LOCKED_{role}"
    if eff not in allowed:
        eff = "STANDARD" if "STANDARD" in allowed else allowed[0]
        clamped = True
        reason = f"RBAC_CEILING_BLOCKED_{requested}_FOR_{role}"

    term, density, max_nav, widgets, cols = MODE_SPEC[eff]
    widgets, cols = list(widgets), list(cols)
    hidden = []
    if role in ("CASHIER", "DRIVER"):
        for s in list(SENSITIVE):
            if s in widgets:
                widgets.remove(s); hidden.append(s)
            if s in cols:
                cols.remove(s); hidden.append(s)

    if cog_simple and density == "COMPACT":
        density = "SPACIOUS"
    min_dp = 64 if motor_large else (56 if density == "SPACIOUS" else 48)
    return {
        "effective_mode": eff, "clamped": clamped, "reason": reason,
        "terminology": term, "density": density, "min_dp": min_dp,
        "max_nav": max_nav, "widgets": widgets, "columns": cols, "hidden": hidden
    }

def run_v17_tests():
    results = []
    def record(tid, cat, title, passed, evidence):
        results.append({"test_id": tid, "category": cat, "title": title, "status": "PASS" if passed else "FAIL", "evidence": evidence})

    # WSM-01: Easy Mode hides accounting jargon & exposes spacious 3-tab simple trade workspace
    p_easy = resolve_mode("OWNER", "EASY")
    record("WSM-01", "Easy Mode", "Easy Mode uses SIMPLE_TRADE terminology, SPACIOUS density, 3 nav items & hides debit/credit/COA",
           p_easy["terminology"] == "SIMPLE_TRADE" and p_easy["density"] == "SPACIOUS" and p_easy["max_nav"] == 3 and "coa_code" not in p_easy["columns"],
           f"term={p_easy['terminology']}, density={p_easy['density']}, cols={p_easy['columns']}")

    # WSM-02: Standard Mode balanced SMB layout & clean A4 daily report
    p_std = resolve_mode("OWNER", "STANDARD")
    record("WSM-02", "Standard Mode", "Standard Mode provides BALANCED terminology, COMFORTABLE density & A4 clean report widget",
           p_std["terminology"] == "BALANCED" and p_std["density"] == "COMFORTABLE" and "clean_a4_daily_report" in p_std["widgets"],
           f"widgets={p_std['widgets']}")

    # WSM-03: Professional Mode exposes full COA, Dual-Currency Dr/Cr, FIFO & SHA-256 columns for Accountant/Owner
    p_pro = resolve_mode("ACCOUNTANT", "PROFESSIONAL")
    record("WSM-03", "Professional Mode", "Professional Mode exposes STRICT_ACCOUNTING, COMPACT grid, COA, Base Dr/Cr, FIFO & SHA-256",
           (not p_pro["clamped"]) and p_pro["density"] == "COMPACT" and all(c in p_pro["columns"] for c in ["coa_code", "base_debit", "base_credit", "audit_sha256_hash"]),
           f"cols={p_pro['columns']}")

    # WSM-04: Executive Mode exposes multi-branch KPIs & shift variances for Owner
    p_exec = resolve_mode("OWNER", "EXECUTIVE")
    record("WSM-04", "Executive Mode", "Executive Mode renders consolidated branch PnL, shift Z-reports & trust score KPIs",
           (not p_exec["clamped"]) and "branch_consolidated_pnl" in p_exec["widgets"] and "all_cashiers_z_reports" in p_exec["widgets"],
           f"widgets={p_exec['widgets']}")

    # WSM-05: Express Field Mode tailored for offline distributors/drivers
    p_fld = resolve_mode("DRIVER", "EXPRESS_FIELD")
    record("WSM-05", "Express Field Mode", "Express Field Mode shows offline outbox strip & vehicle custody with spacious single-hand UI",
           (not p_fld["clamped"]) and p_fld["density"] == "SPACIOUS" and "offline_sync_outbox_strip" in p_fld["widgets"] and "assigned_vehicle_custody" in p_fld["widgets"],
           f"widgets={p_fld['widgets']}")

    # WSM-06: Security Anti-Escalation — Cashier & Driver attempting Professional/Executive Mode are strictly clamped!
    p_cash_hack = resolve_mode("CASHIER", "PROFESSIONAL")
    p_drv_hack  = resolve_mode("DRIVER", "EXECUTIVE")
    sec_ok = (
        p_cash_hack["clamped"] and p_cash_hack["effective_mode"] == "STANDARD" and "gross_profit" not in p_cash_hack["widgets"]
        and p_drv_hack["clamped"] and p_drv_hack["effective_mode"] == "EASY" and "branch_consolidated_pnl" not in p_drv_hack["widgets"]
    )
    record("WSM-06", "RBAC Anti-Escalation", "Cashier/Driver requesting Professional/Executive mode clamped & profit/ledger fields stripped",
           sec_ok, f"cashier_eff={p_cash_hack['effective_mode']} (hidden={p_cash_hack['hidden']}), driver_eff={p_drv_hack['effective_mode']}")

    # WSM-07: Organization Role Mode Lock Policy (Owner locks Cashiers to EASY mode)
    policy = {"default_mode": "EASY", "allow_override": False}
    p_locked = resolve_mode("CASHIER", "STANDARD", org_policy=policy)
    record("WSM-07", "Org Role Policy Lock", "Org owner lock forces Cashier to EASY mode even when requesting allowed STANDARD mode",
           p_locked["clamped"] and p_locked["effective_mode"] == "EASY" and p_locked["reason"] == "ORG_POLICY_LOCKED_CASHIER",
           f"eff={p_locked['effective_mode']}, reason={p_locked['reason']}")

    # WSM-08: Accessibility Harmony (v1.6 Motor 64dp + Cognitive Simplified override compact Professional density)
    p_a11y = resolve_mode("OWNER", "PROFESSIONAL", motor_large=True, cog_simple=True)
    record("WSM-08", "Accessibility Harmony", "v1.6 Accessibility overrides preserve 64dp touch targets & spacious layout even in Professional mode",
           p_a11y["min_dp"] == 64 and p_a11y["density"] == "SPACIOUS",
           f"min_dp={p_a11y['min_dp']}, density={p_a11y['density']}")

    # WSM-09: PostgreSQL Migration 008 RLS & Feature Flag #25 Verification
    pg008 = open(os.path.join(os.path.dirname(__file__), "..", "..", "database/postgres/008_workspace_experience_modes.sql"), encoding="utf-8").read()
    pg_ok = all(s in pg008 for s in [
        "CREATE TABLE user_workspace_preferences",
        "CREATE TABLE org_role_mode_policies",
        "ALTER TABLE user_workspace_preferences ENABLE ROW LEVEL SECURITY",
        "ALTER TABLE org_role_mode_policies ENABLE ROW LEVEL SECURITY",
        "'WORKSPACE_EXPERIENCE_MODES'"
    ])
    record("WSM-09", "PostgreSQL 008 & RLS", "Migration 008 defines preference/policy tables, RLS & Feature Flag #25",
           pg_ok, f"verified={pg_ok}")

    # WSM-10: Full 7-Step Sequential SQLite Migration Chain (v1.4 001->004 + v1.5 005 + v1.6 006 + v1.7 007)
    sql_dir = os.path.join(os.path.dirname(__file__), "..", "..", "frontend", "mizan_flutter", "assets", "sql")
    mconn = sqlite3.connect(":memory:")
    applied = []
    for name in [
        "001_mizan_offline_client.sql",
        "002_flutter_feature_flags.sql",
        "003_flutter_fx_and_translation.sql",
        "004_flutter_peak_wal_indexes.sql",
        "005_flutter_pos_shifts_variants.sql",
        "006_flutter_voice_and_accessibility.sql",
        "007_flutter_workspace_modes.sql",
    ]:
        mconn.executescript(open(os.path.join(sql_dir, name), encoding="utf-8").read())
        applied.append(name)
    # Test CHECK constraint on invalid mode
    bad_mode_blocked = False
    try:
        mconn.execute("INSERT INTO local_workspace_preferences(user_id, org_id, experience_mode, updated_at) VALUES ('u1','o1','SUPER_ADMIN_HACK','2026-11-24')")
    except sqlite3.IntegrityError:
        bad_mode_blocked = True
    tables = sorted([r[0] for r in mconn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()])
    mconn.close()
    chain_ok = len(applied) == 7 and bad_mode_blocked and "local_workspace_preferences" in tables and "local_org_role_mode_policies" in tables
    record("WSM-10", "Migration Chain 001->007", "All 7 sequential SQLite migrations (v1.4+v1.5+v1.6+v1.7) succeed & CHECK blocks invalid modes",
           chain_ok, f"applied={len(applied)}, total_tables={len(tables)}, invalid_mode_blocked={bad_mode_blocked}")

    return {
        "upgrade_version": "Mizan_Workspace_Experience_Modes_v1.7",
        "executed_at_utc": datetime.now(timezone.utc).isoformat(),
        "total_tests": len(results),
        "passed": sum(1 for r in results if r["status"] == "PASS"),
        "failed": sum(1 for r in results if r["status"] == "FAIL"),
        "results": results
    }

if __name__ == "__main__":
    print(json.dumps(run_v17_tests(), indent=2, ensure_ascii=False))
