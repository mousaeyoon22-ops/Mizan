# Mizan (ميزان) — Production Ready v2.2 (EF-PG Schema Verified & Local City-Pilot Ready)

Fully audited, schema-parity-verified release unifying:
- **PostgreSQL 16 (10 migrations `001`–`010`):** `NUMERIC(18,4)`, Double-Entry & Immutability triggers, `mizan_runtime` (`NOSUPERUSER NOBYPASSRLS`), `FORCE RLS` + `NULLIF`-safe UUID helpers with `WITH CHECK` on all 22 tables, plus `database/tests/test_pg_rls_and_invariants.sql`.
- **.NET 8 Backend (12 Controllers, 8 Engines, 15 Verified EF Core DbSets):** 100% snake_case & `ScreamingSnakeEnumConverter` parity, PBKDF2-SHA512 + JWT + Atomic Refresh Rotation, transactional IAS 2 FIFO + IFRS 15 + IAS 21 FX, 25 Operational Feature Flags, Touch POS/Z-Reports, Bilingual Voice Safety, 5 Workspace Modes, Clean A4 Reports, and Scheduled Hangfire Jobs.
- **Flutter Offline Client (8 SQLite Migrations `001`–`008`):** Wired `MizanApiClient` (Login/Refresh/Features/Meters) + Offline Fallback + WCAG 2.2 AA Accessibility + Day-1 Offline HTML Companion (`local_pilot_web/mizan_field_companion.html`).

## Immediate Verification & Deployment Commands
```bash
# 1. Re-run all 83 live tests (including EF Core <-> PostgreSQL Schema/Enum Parity) + 5 Peak Benchmarks
python3 verification/run_all_monorepo_tests.py
python3 load_testing/run_peak_stress_benchmark.py

# 2. Deploy local city server (TLS certs + PG 001->010 + mizan_runtime rotation + API + Nginx TLS 1.3)
cp .env.example .env
bash scripts/deploy_local_city_pilot.sh

# 3. Verify .NET 8 tests & build signed Android APK
dotnet test backend/Mizan.sln --configuration Release
cd frontend/mizan_flutter && flutter pub get && flutter analyze && flutter test
flutter build apk --release --dart-define=MIZAN_API_BASE_URL=https://YOUR_SERVER_IP_OR_DOMAIN
```
