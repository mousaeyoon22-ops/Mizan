-- Run directly against live PostgreSQL 16 (after applying Migrations 001 -> 004):
-- pgbench -c 64 -j 8 -T 120 -f load_testing/pgbench_ledger_workload.sql mizan_prod
\set org_idx random(1, 50)
\set amt random(10, 500)
BEGIN;
SELECT count(*) FROM journal_lines WHERE debit >= :amt;
COMMIT;
