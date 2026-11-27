#!/usr/bin/env bash
# One-Command Local City-Pilot Deployment & Runtime Role Rotation Script
set -euo pipefail

if [ ! -f .env ]; then
  echo "ERROR: .env not found. Run: cp .env.example .env and fill real secrets first."
  exit 1
fi
set -a; source .env; set +a

if [ "${#JWT_SIGNING_KEY}" -lt 32 ]; then
  echo "ERROR: JWT_SIGNING_KEY must be at least 32 bytes."
  exit 1
fi

if [ ! -f ./certs/fullchain.pem ] || [ ! -f ./certs/privkey.pem ]; then
  echo "No TLS certs found in ./certs — generating local LAN certificate..."
  bash ./scripts/generate_local_tls_certs.sh "${MIZAN_DOMAIN:-mizan.local}" "${MIZAN_LAN_IP:-127.0.0.1}"
fi

echo "1/4 Starting PostgreSQL 16 and applying migrations 001 -> 009..."
docker compose up -d postgres
until docker compose exec -T postgres pg_isready -U "${POSTGRES_USER:-mizan_admin}" -d "${POSTGRES_DB:-mizan_prod}" >/dev/null 2>&1; do
  sleep 2
done

echo "2/4 Rotating mizan_runtime (NOBYPASSRLS) password to match .env..."
docker compose exec -T postgres psql -U "${POSTGRES_USER:-mizan_admin}" -d "${POSTGRES_DB:-mizan_prod}"   -v rpass="${POSTGRES_RUNTIME_PASSWORD}"   -c "ALTER ROLE mizan_runtime WITH PASSWORD :'rpass';"

echo "3/4 Building & starting Mizan .NET 8 API + Peak Nginx TLS 1.3..."
docker compose up -d --build mizan-api nginx

echo "4/4 Verifying /health endpoint..."
sleep 4
curl -kfsS https://localhost/health && echo " -> MIZAN LOCAL PILOT ONLINE & HEALTHY!"
