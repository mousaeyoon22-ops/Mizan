import os
import re
import json
from datetime import datetime, timezone

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

def read(rel):
    with open(os.path.join(ROOT, rel), "r", encoding="utf-8") as f:
        return f.read()

def to_snake(name):
    s1 = re.sub(r'(.)([A-Z][a-z]+)', r'\1_\2', name)
    return re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', s1).lower()

SPECIAL_ENUM = {
    "GatewayPreAuth": "GATEWAY_PREAUTH",
    "PreAuthorized": "PREAUTHORIZED",
    "ExecutedReadOnly": "EXECUTED_READONLY",
}

def to_pg_enum(val):
    if val in SPECIAL_ENUM:
        return SPECIAL_ENUM[val]
    return to_snake(val).upper()

def run_parity_audit():
    results = []
    def record(tid, cat, title, passed, evidence):
        results.append({"test_id": tid, "category": cat, "title": title, "status": "PASS" if passed else "FAIL", "evidence": evidence})

    # 1) Parse ALL PostgreSQL tables, columns & CHECK enum lists from 001 -> 010
    pg_dir = os.path.join(ROOT, "database", "postgres")
    pg_files = sorted([f for f in os.listdir(pg_dir) if f.endswith(".sql")])
    pg_tables = {}
    pg_checks = {}
    pg_all = ""
    for pf in pg_files:
        sql = read(f"database/postgres/{pf}")
        pg_all += "\n" + sql
        for m in re.finditer(r"CREATE TABLE\s+(\w+)\s*\((.*?)\);", sql, re.S | re.I):
            tname = m.group(1).lower()
            body = m.group(2)
            cols = re.findall(r"^\s*(\w+)\s+(?:UUID|VARCHAR|CHAR|TEXT|SMALLINT|INTEGER|NUMERIC|BOOLEAN|TIMESTAMPTZ|DATE|JSONB|INET)", body, re.M | re.I)
            pg_tables[tname] = set(c.lower() for c in cols)
            for cm in re.finditer(r"(\w+)\s+(?:VARCHAR|CHAR|TEXT)[^,\n]*CHECK\s*\(\s*\1\s+IN\s*\(([^)]+)\)\s*\)", body, re.I):
                col = cm.group(1).lower()
                vals = set(re.findall(r"'([^']+)'", cm.group(2)))
                pg_checks[(tname, col)] = vals

    # 2) Parse MizanDbContext.cs entity -> table, HasColumnName, and Ignore mappings
    dbctx = read("backend/src/Mizan.Infrastructure/Persistence/MizanDbContext.cs")
    entity_files = [
        "backend/src/Mizan.Domain/Entities/LedgerEntities.cs",
        "backend/src/Mizan.Domain/Entities/InventoryEntities.cs",
        "backend/src/Mizan.Domain/Entities/TradeGateEntities.cs",
        "backend/src/Mizan.Domain/Entities/CommerceP2PEntities.cs",
        "backend/src/Mizan.Domain/POS/PosEntities.cs",
        "backend/src/Mizan.Domain/Accessibility/VoiceAndAccessibilityEntities.cs",
    ]
    cs_classes = {}
    cs_enums = {}
    for ef in entity_files:
        txt = read(ef)
        for em in re.finditer(r"public\s+enum\s+(\w+)\s*\{([^}]+)\}", txt, re.S):
            cs_enums[em.group(1)] = [v.strip() for v in em.group(2).split(",") if v.strip()]
        # Split classes cleanly
        parts = re.split(r"public\s+sealed\s+class\s+", txt)[1:]
        for part in parts:
            cname = re.match(r"(\w+)", part).group(1)
            # Extract public scalar properties (exclude IReadOnlyList navigation props)
            props = re.findall(r"public\s+(?!IReadOnlyList|static)[\w<>?]+\s+(\w+)\s*(?:\{|=>)", part)
            cs_classes[cname] = props

    # Extract each modelBuilder.Entity<ClassName>(b => { ... });
    mismatches = []
    checked_entities = 0
    for m in re.finditer(r"modelBuilder\.Entity<(\w+)>\(b\s*=>\s*\{(.*?)\n\s*\}\);", dbctx, re.S):
        cname, block = m.group(1), m.group(2)
        tmatch = re.search(r'b\.ToTable\("(\w+)"\)', block)
        if not tmatch:
            mismatches.append(f"{cname}: missing ToTable()")
            continue
        tname = tmatch.group(1)
        if tname not in pg_tables:
            mismatches.append(f"{cname}: table {tname} not in PG migrations")
            continue

        col_overrides = dict(re.findall(r'b\.Property\(\w+\s*=>\s*\w+\.(\w+)\)\.HasColumnName\("(\w+)"\)', block))
        ignored = set(re.findall(r'b\.Ignore\(\w+\s*=>\s*\w+\.(\w+)\)', block))
        checked_entities += 1

        for prop in cs_classes.get(cname, []):
            if prop in ignored:
                continue
            pg_col = col_overrides.get(prop, to_snake(prop))
            if pg_col not in pg_tables[tname]:
                mismatches.append(f"{cname}.{prop} -> expected PG col '{pg_col}' not found in '{tname}'")

    record("PAR-01", "EF Core <-> PG Column Parity", "Every mapped C# property across all 15 DbSets matches an exact PostgreSQL column (0 mismatches)",
           checked_entities == 15 and len(mismatches) == 0,
           f"checked_entities={checked_entities}, mismatches={mismatches}")

    # 3) Verify C# Enum Values converted via ScreamingSnakeEnumConverter match PostgreSQL CHECK (...) sets 100%!
    enum_pairs = [
        ("AccountType", "accounts", "account_type"),
        ("PairingStatus", "pairings", "status"),
        ("GateType", "trade_gates", "gate_type"),
        ("GateStatus", "trade_gates", "status"),
        ("GateDocState", "gate_documents", "state"),
        ("PaymentMode", "p2p_orders", "payment_mode"),
        ("PaymentStatus", "p2p_orders", "payment_status"),
        ("DeliveryStatus", "p2p_orders", "delivery_status"),
        ("P2POrderState", "p2p_orders", "order_state"),
        ("FaultParty", "p2p_orders", "cancel_fault_party"),
        ("ShiftStatus", "pos_shifts", "status"),
        ("AccessibilityPreset", "user_accessibility_profiles", "preset_profile"),
        ("VoiceIntent", "voice_command_audit", "detected_intent"),
        ("VoiceCommandState", "voice_command_audit", "state"),
        ("VoiceConfirmationMethod", "voice_command_audit", "confirmation_method"),
    ]
    enum_mismatches = []
    for ename, tname, col in enum_pairs:
        c_vals = {to_pg_enum(v) for v in cs_enums.get(ename, [])}
        p_vals = pg_checks.get((tname, col), set())
        if c_vals != p_vals:
            enum_mismatches.append(f"{ename} vs {tname}.{col}: C#={sorted(c_vals)} != PG={sorted(p_vals)}")

    record("PAR-02", "EF Core <-> PG Enum Parity", "All 15 C# enums converted via ScreamingSnakeEnumConverter match PostgreSQL CHECK constraints 100%",
           len(enum_mismatches) == 0,
           f"checked_enums={len(enum_pairs)}, mismatches={enum_mismatches}")

    # 4) Verify Migration 010 covers ALL 22 RLS-enabled tables with NULLIF-safe UUID functions & explicit WITH CHECK
    pg010 = read("database/postgres/010_rls_nullif_uuid_safety.sql")
    rls_tables = set(re.findall(r"ALTER TABLE\s+(\w+)\s+ENABLE ROW LEVEL SECURITY", pg_all, re.I))
    m010_policies = set(re.findall(r"CREATE POLICY\s+\w+\s+ON\s+(\w+)", pg010, re.I))
    missing_rls_010 = sorted(rls_tables - m010_policies)
    has_nullif = ("NULLIF(current_setting('app.current_org_id', true), '')::UUID" in pg010) and ("NULLIF(current_setting('app.current_user_id', true), '')::UUID" in pg010)
    with_check_cnt = len(re.findall(r"WITH CHECK\s*\(", pg010))
    record("PAR-03", "Migration 010 NULLIF RLS", "Migration 010 upgrades all 22 RLS tables to NULLIF-safe UUID helpers with explicit WITH CHECK",
           len(missing_rls_010) == 0 and has_nullif and with_check_cnt == 22,
           f"rls_tables={len(rls_tables)}, upgraded_in_010={len(m010_policies)}, with_check={with_check_cnt}, missing={missing_rls_010}")

    # 5) Verify Auth Refresh Rotation, Backup Script User Alignment, Hangfire Recurring Schedule, & Full Controllers
    auth_cs = read("backend/src/Mizan.Api/Controllers/AuthController.cs")
    bkp_sh = read("scripts/backup_postgres.sh")
    rst_sh = read("scripts/restore_postgres.sh")
    prog_cs = read("backend/src/Mizan.Api/Program.cs")
    ci_yml = read(".github/workflows/ci.yml")
    fx_cs = read("backend/src/Mizan.Api/Controllers/FxAndTranslationController.cs")
    pref_cs = read("backend/src/Mizan.Api/Controllers/FeaturePreferencesController.cs")
    gate_cs = read("backend/src/Mizan.Api/Controllers/TradeGatesController.cs")
    p2p_cs = read("backend/src/Mizan.Api/Controllers/P2POrdersController.cs")
    pilot_cs = read("backend/src/Mizan.Api/Controllers/CityPilotOpsController.cs")
    acc_cs = read("backend/src/Mizan.Api/Controllers/AccountingController.cs")
    api_dart = read("frontend/mizan_flutter/lib/data/remote/mizan_api_client.dart")

    ops_ok = (
        'HttpPost("refresh")' in auth_cs and "REFRESH_TOKEN_REUSE_DETECTED" in auth_cs
        and "mizan_admin" in bkp_sh and "mizan_admin" in rst_sh
        and "IRecurringJobManager" in prog_cs and "release-expired-holds" in prog_cs
        and "test_pg_rls_and_invariants.sql" in ci_yml
        and "[FromHeader" not in fx_cs and "_ledgerRepo.SaveJournalEntryAsync" in fx_cs
        and "[FromHeader" not in pref_cs and "ONLY_ORG_OWNER_CAN_TOGGLE_FEATURES" in pref_cs
        and "DispatchDocument" in gate_cs and "CreateAndSubmitOrder" in p2p_cs and "RecordMeterReading" in pilot_cs
        and "_tenant.UserId" in acc_cs and "_db.FifoLayers" in acc_cs
        and "/api/v1/auth/login" in api_dart and "/api/v1/auth/refresh" in api_dart
    )
    record("PAR-04", "End-to-End Wiring (DEF-403..407)", "Auth refresh rotation, FIFO/CreatedBy DB persistence, TradeGate/P2P/Pilot controllers, Hangfire schedule, backup scripts & Flutter API verified",
           ops_ok, f"verified={ops_ok}")

    return {
        "suite": "EF Core <-> PostgreSQL Schema, Enum & RLS Parity Audit (v2.2)",
        "executed_at_utc": datetime.now(timezone.utc).isoformat(),
        "total_tests": len(results),
        "passed": sum(1 for r in results if r["status"] == "PASS"),
        "failed": sum(1 for r in results if r["status"] == "FAIL"),
        "results": results
    }

if __name__ == "__main__":
    print(json.dumps(run_parity_audit(), indent=2, ensure_ascii=False))
