import os
import time
import json
import sqlite3
import hashlib
import threading
import statistics
from concurrent.futures import ThreadPoolExecutor, as_completed
from datetime import datetime, timezone

DB_FILE = "/tmp/mizan_peak_stress_verify.db"

def cleanup():
    for ext in ("", "-wal", "-shm"):
        if os.path.exists(DB_FILE + ext):
            os.remove(DB_FILE + ext)

def get_conn():
    c = sqlite3.connect(DB_FILE, timeout=30.0, isolation_level=None)
    c.execute("PRAGMA journal_mode = WAL;")
    c.execute("PRAGMA synchronous = NORMAL;")
    c.execute("PRAGMA busy_timeout = 30000;")
    c.execute("PRAGMA foreign_keys = ON;")
    return c

def pct(arr, p):
    if not arr:
        return 0.0
    s = sorted(arr)
    idx = min(len(s) - 1, int(round((p / 100.0) * (len(s) - 1))))
    return round(s[idx], 3)

def run_benchmark():
    cleanup()
    init_conn = get_conn()
    init_conn.executescript("""
    CREATE TABLE journal_entries (
        id TEXT PRIMARY KEY,
        org_id TEXT NOT NULL,
        idempotency_key TEXT NOT NULL,
        ref_type TEXT NOT NULL,
        base_currency TEXT NOT NULL,
        UNIQUE(org_id, idempotency_key)
    );
    CREATE TABLE journal_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_id TEXT NOT NULL REFERENCES journal_entries(id),
        org_id TEXT NOT NULL,
        account_code TEXT NOT NULL,
        base_debit_minor INTEGER NOT NULL DEFAULT 0 CHECK (base_debit_minor >= 0),
        base_credit_minor INTEGER NOT NULL DEFAULT 0 CHECK (base_credit_minor >= 0),
        CHECK ((base_debit_minor > 0 AND base_credit_minor = 0) OR (base_credit_minor > 0 AND base_debit_minor = 0))
    );
    CREATE TABLE items (
        id TEXT PRIMARY KEY,
        org_id TEXT NOT NULL,
        sku TEXT NOT NULL,
        qty_on_hand_minor INTEGER NOT NULL CHECK (qty_on_hand_minor >= 0),
        row_version INTEGER NOT NULL DEFAULT 1
    );
    CREATE TABLE sync_outbox (
        id TEXT PRIMARY KEY,
        idempotency_key TEXT NOT NULL UNIQUE,
        org_id TEXT NOT NULL,
        payload_sha256 TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'PENDING'
    );
    """)
    init_conn.close()

    metrics = {
        "executed_at_utc": datetime.now(timezone.utc).isoformat(),
        "environment": f"Python 3 + SQLite WAL Multi-Thread Stress Engine ({os.cpu_count()} vCPUs)",
        "note_on_scope": "Measures relational schema index impact, lock contention, idempotency storm, hot-SKU oversell race, and zero-variance invariants locally. Live PostgreSQL 16 MVCC, .NET 8 Kestrel, SignalR, and Nginx TLS 1.3 must be benchmarked via included k6_peak_storm.js and pgbench_ledger_workload.sql."
    }

    # 1. Scale + Unindexed vs Indexed Lookup Impact (10,000 entries / 20,000 lines across 50 orgs)
    conn = get_conn()
    t0 = time.perf_counter()
    conn.execute("BEGIN IMMEDIATE;")
    NUM_ORGS, ENTRIES_PER_ORG = 50, 200
    for o in range(NUM_ORGS):
        org_id = f"ORG_{o:03d}"
        for i in range(ENTRIES_PER_ORG):
            eid = f"E_{o:03d}_{i:05d}"
            amt = 100000 + (i % 50) * 2500
            conn.execute("INSERT INTO journal_entries VALUES (?,?,?,?,?)", (eid, org_id, f"IDEM_{o}_{i}", "DELIVERY", "USD"))
            conn.execute("INSERT INTO journal_lines(entry_id, org_id, account_code, base_debit_minor, base_credit_minor) VALUES (?,?,?,?,?)", (eid, org_id, "AR", amt, 0))
            conn.execute("INSERT INTO journal_lines(entry_id, org_id, account_code, base_debit_minor, base_credit_minor) VALUES (?,?,?,?,?)", (eid, org_id, "REV", 0, amt))
    conn.execute("COMMIT;")
    bulk_elapsed = time.perf_counter() - t0

    unindexed_lat = []
    for i in range(500):
        eid = f"E_{i % NUM_ORGS:03d}_{i % ENTRIES_PER_ORG:05d}"
        ts = time.perf_counter()
        conn.execute("SELECT SUM(base_debit_minor), SUM(base_credit_minor) FROM journal_lines WHERE entry_id = ?", (eid,)).fetchone()
        unindexed_lat.append((time.perf_counter() - ts) * 1000.0)

    t_idx = time.perf_counter()
    conn.executescript("""
    CREATE INDEX idx_jl_entry_id ON journal_lines(entry_id);
    CREATE INDEX idx_jl_org_acc ON journal_lines(org_id, account_code);
    CREATE INDEX idx_je_org_idem ON journal_entries(org_id, idempotency_key);
    """)
    idx_build_ms = (time.perf_counter() - t_idx) * 1000.0

    indexed_lat = []
    for i in range(500):
        eid = f"E_{i % NUM_ORGS:03d}_{i % ENTRIES_PER_ORG:05d}"
        ts = time.perf_counter()
        conn.execute("SELECT SUM(base_debit_minor), SUM(base_credit_minor) FROM journal_lines WHERE entry_id = ?", (eid,)).fetchone()
        indexed_lat.append((time.perf_counter() - ts) * 1000.0)
    conn.close()

    metrics["bench_1_ledger_scale_and_index_impact"] = {
        "entries_inserted": NUM_ORGS * ENTRIES_PER_ORG,
        "lines_inserted": NUM_ORGS * ENTRIES_PER_ORG * 2,
        "organizations": NUM_ORGS,
        "bulk_insert_tps": round((NUM_ORGS * ENTRIES_PER_ORG) / bulk_elapsed, 1),
        "unindexed_lookup_mean_ms": round(statistics.mean(unindexed_lat), 3),
        "unindexed_lookup_p99_ms": pct(unindexed_lat, 99),
        "indexed_lookup_mean_ms": round(statistics.mean(indexed_lat), 3),
        "indexed_lookup_p99_ms": pct(indexed_lat, 99),
        "index_speedup_factor": round(statistics.mean(unindexed_lat) / max(statistics.mean(indexed_lat), 0.0001), 1),
        "index_build_ms": round(idx_build_ms, 2)
    }

    # 2. Concurrent Peak-Hour FX & Ledger Storm (32 Threads x 100 Dual-Currency 3-line TXs = 3,200 TXs)
    WORKERS, TX_PER_WORKER = 32, 100
    write_lats, write_errors, lock_retries = [], 0, 0
    lat_lock = threading.Lock()

    def worker_fx(wid):
        nonlocal write_errors, lock_retries
        c = get_conn()
        ll, le, lr = [], 0, 0
        org_id = f"ORG_{wid % NUM_ORGS:03d}"
        for j in range(TX_PER_WORKER):
            eid, idem = f"PEAK_W{wid:02d}_{j:04d}", f"PEAK_IDEM_{wid}_{j}"
            ts = time.perf_counter()
            for att in range(8):
                try:
                    c.execute("BEGIN IMMEDIATE;")
                    c.execute("INSERT INTO journal_entries VALUES (?,?,?,?,?)", (eid, org_id, idem, "FX_EXCHANGE", "SAR"))
                    c.execute("INSERT INTO journal_lines(entry_id, org_id, account_code, base_debit_minor, base_credit_minor) VALUES (?,?,?,?,?)", (eid, org_id, "CASH_SAR", 37200000, 0))
                    c.execute("INSERT INTO journal_lines(entry_id, org_id, account_code, base_debit_minor, base_credit_minor) VALUES (?,?,?,?,?)", (eid, org_id, "FX_EXCH_EXPENSE", 300000, 0))
                    c.execute("INSERT INTO journal_lines(entry_id, org_id, account_code, base_debit_minor, base_credit_minor) VALUES (?,?,?,?,?)", (eid, org_id, "CASH_USD", 0, 37500000))
                    c.execute("COMMIT;")
                    break
                except sqlite3.OperationalError as e:
                    try: c.execute("ROLLBACK;")
                    except Exception: pass
                    if "locked" in str(e).lower() and att < 7:
                        lr += 1
                        time.sleep(0.002 * (att + 1))
                    else:
                        le += 1
                        break
            ll.append((time.perf_counter() - ts) * 1000.0)
        c.close()
        with lat_lock:
            write_lats.extend(ll)
            write_errors += le
            lock_retries += lr

    t0 = time.perf_counter()
    with ThreadPoolExecutor(max_workers=WORKERS) as ex:
        for f in [ex.submit(worker_fx, w) for w in range(WORKERS)]:
            f.result()
    storm_elapsed = time.perf_counter() - t0

    v_conn = get_conn()
    variances = v_conn.execute("SELECT org_id, SUM(base_debit_minor) - SUM(base_credit_minor) AS v FROM journal_lines GROUP BY org_id HAVING v <> 0").fetchall()
    total_e = v_conn.execute("SELECT COUNT(*) FROM journal_entries").fetchone()[0]
    total_l = v_conn.execute("SELECT COUNT(*) FROM journal_lines").fetchone()[0]
    v_conn.close()

    metrics["bench_2_concurrent_peak_fx_storm"] = {
        "concurrent_threads": WORKERS,
        "transactions_attempted": WORKERS * TX_PER_WORKER,
        "errors": write_errors,
        "lock_retries": lock_retries,
        "elapsed_sec": round(storm_elapsed, 3),
        "sustained_tps": round((WORKERS * TX_PER_WORKER) / storm_elapsed, 1),
        "latency_p50_ms": pct(write_lats, 50),
        "latency_p95_ms": pct(write_lats, 95),
        "latency_p99_ms": pct(write_lats, 99),
        "total_entries_in_db": total_e,
        "total_lines_in_db": total_l,
        "unbalanced_organizations": len(variances),
        "zero_variance_verified": len(variances) == 0
    }

    # 3. Idempotency Storm (400 Concurrent Duplicate Requests on Same Key)
    DUP_T, DUP_E = 40, 10
    ipost, irep, ierr, ilats = 0, 0, 0, []
    ilock = threading.Lock()

    def worker_idem(wid):
        nonlocal ipost, irep, ierr
        c = get_conn()
        for _ in range(DUP_E):
            ts = time.perf_counter()
            try:
                c.execute("BEGIN IMMEDIATE;")
                row = c.execute("SELECT id FROM journal_entries WHERE org_id='ORG_000' AND idempotency_key='STORM_KEY_999'").fetchone()
                if row:
                    c.execute("COMMIT;")
                    with ilock: irep += 1
                else:
                    c.execute("INSERT INTO journal_entries VALUES ('E_STORM_999', 'ORG_000', 'STORM_KEY_999', 'ADVANCE', 'USD')")
                    c.execute("INSERT INTO journal_lines(entry_id, org_id, account_code, base_debit_minor, base_credit_minor) VALUES ('E_STORM_999', 'ORG_000', 'CASH', 5000000, 0)")
                    c.execute("INSERT INTO journal_lines(entry_id, org_id, account_code, base_debit_minor, base_credit_minor) VALUES ('E_STORM_999', 'ORG_000', 'ADV', 0, 5000000)")
                    c.execute("COMMIT;")
                    with ilock: ipost += 1
            except sqlite3.IntegrityError:
                try: c.execute("ROLLBACK;")
                except Exception: pass
                with ilock: irep += 1
            except Exception:
                try: c.execute("ROLLBACK;")
                except Exception: pass
                with ilock: ierr += 1
            with ilock:
                ilats.append((time.perf_counter() - ts) * 1000.0)
        c.close()

    with ThreadPoolExecutor(max_workers=DUP_T) as ex:
        for f in [ex.submit(worker_idem, w) for w in range(DUP_T)]:
            f.result()

    v_conn = get_conn()
    s_rows = v_conn.execute("SELECT COUNT(*) FROM journal_entries WHERE idempotency_key='STORM_KEY_999'").fetchone()[0]
    v_conn.close()

    metrics["bench_3_idempotency_replay_storm"] = {
        "simultaneous_duplicate_requests": DUP_T * DUP_E,
        "posted_count": ipost,
        "replayed_safely_count": irep,
        "errors": ierr,
        "db_rows_created": s_rows,
        "latency_p99_ms": pct(ilats, 99),
        "duplicate_prevention_verified": (s_rows == 1 and ipost == 1 and ierr == 0)
    }

    # 4. Hot-SKU Peak Inventory Oversell Race (500 Concurrent Buyers vs 100 Units)
    ci = get_conn()
    ci.execute("INSERT INTO items VALUES ('HOT_WTR', 'ORG_000', 'WTR-20L', 1000000, 1)")
    ci.close()

    BT, BE = 50, 10
    bok, boos, bconf, blats = 0, 0, 0, []
    block = threading.Lock()

    def worker_sku(wid):
        nonlocal bok, boos, bconf
        c = get_conn()
        for _ in range(BE):
            ts = time.perf_counter()
            for _ in range(12):
                try:
                    c.execute("BEGIN IMMEDIATE;")
                    qty, ver = c.execute("SELECT qty_on_hand_minor, row_version FROM items WHERE id='HOT_WTR'").fetchone()
                    if qty < 10000:
                        c.execute("COMMIT;")
                        with block: boos += 1
                        break
                    cur = c.execute("UPDATE items SET qty_on_hand_minor = qty_on_hand_minor - 10000, row_version = row_version + 1 WHERE id='HOT_WTR' AND row_version = ? AND qty_on_hand_minor >= 10000", (ver,))
                    c.execute("COMMIT;")
                    if cur.rowcount == 1:
                        with block: bok += 1
                        break
                    else:
                        with block: bconf += 1
                except sqlite3.OperationalError:
                    try: c.execute("ROLLBACK;")
                    except Exception: pass
                    time.sleep(0.002)
            with block:
                blats.append((time.perf_counter() - ts) * 1000.0)
        c.close()

    t0 = time.perf_counter()
    with ThreadPoolExecutor(max_workers=BT) as ex:
        for f in [ex.submit(worker_sku, w) for w in range(BT)]:
            f.result()
    sku_el = time.perf_counter() - t0

    v_conn = get_conn()
    fqty, fver = v_conn.execute("SELECT qty_on_hand_minor, row_version FROM items WHERE id='HOT_WTR'").fetchone()
    v_conn.close()

    metrics["bench_4_hot_sku_oversell_race"] = {
        "concurrent_buyers": BT * BE,
        "initial_stock_units": 100,
        "orders_fulfilled": bok,
        "cleanly_rejected_out_of_stock": boos,
        "final_stock_units": fqty / 10000.0,
        "final_row_version": fver,
        "elapsed_sec": round(sku_el, 3),
        "latency_p99_ms": pct(blats, 99),
        "zero_oversell_verified": (bok == 100 and boos == 400 and fqty == 0)
    }

    # 5. Offline Outbox Burst (2,000 Writes + Concurrent Catalog Reads)
    OUTBOX_N = 2000
    rlats, wlats = [], []
    stop_r = threading.Event()

    def reader():
        c = get_conn()
        while not stop_r.is_set():
            ts = time.perf_counter()
            c.execute("SELECT qty_on_hand_minor FROM items WHERE id='HOT_WTR'").fetchone()
            rlats.append((time.perf_counter() - ts) * 1000.0)
        c.close()

    rt = threading.Thread(target=reader)
    rt.start()
    cob = get_conn()
    t0 = time.perf_counter()
    for i in range(OUTBOX_N):
        ts = time.perf_counter()
        cob.execute("BEGIN IMMEDIATE;")
        cob.execute("INSERT INTO sync_outbox VALUES (?,?,?,?,?)", (f"OB_{i:05d}", f"OB_KEY_{i:05d}", "ORG_000", hashlib.sha256(f"p{i}".encode()).hexdigest(), "PENDING"))
        cob.execute("COMMIT;")
        wlats.append((time.perf_counter() - ts) * 1000.0)
    ob_el = time.perf_counter() - t0
    stop_r.set()
    rt.join()
    ob_cnt = cob.execute("SELECT COUNT(*) FROM sync_outbox").fetchone()[0]
    cob.close()

    metrics["bench_5_offline_outbox_burst_with_concurrent_reads"] = {
        "outbox_writes_queued": ob_cnt,
        "write_tps": round(OUTBOX_N / ob_el, 1),
        "write_p99_ms": pct(wlats, 99),
        "concurrent_reads_served": len(rlats),
        "read_p95_ms": pct(rlats, 95),
        "read_p99_ms": pct(rlats, 99),
        "zero_data_loss_verified": (ob_cnt == OUTBOX_N)
    }

    cleanup()
    return metrics

if __name__ == "__main__":
    print(json.dumps(run_benchmark(), indent=2, ensure_ascii=False))
