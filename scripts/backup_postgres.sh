#!/usr/bin/env bash
# Fixes DEF-406: Default POSTGRES_USER aligned with docker-compose.yml (`mizan_admin`)
set -euo pipefail
STAMP=$(date -u +"%Y%m%dT%H%M%SZ")
OUT_DIR="${BACKUP_DIR:-./backups}"
mkdir -p "$OUT_DIR"
RAW_DUMP="$OUT_DIR/mizan_${STAMP}.dump"
ENC_DUMP="${RAW_DUMP}.enc"

: "${BACKUP_PASSPHRASE:?Set BACKUP_PASSPHRASE before running backup}"
docker compose exec -T postgres pg_dump -U "${POSTGRES_USER:-mizan_admin}" -Fc "${POSTGRES_DB:-mizan_prod}" > "$RAW_DUMP"
openssl enc -aes-256-cbc -pbkdf2 -salt -in "$RAW_DUMP" -out "$ENC_DUMP" -pass env:BACKUP_PASSPHRASE
rm -f "$RAW_DUMP"
sha256sum "$ENC_DUMP" > "${ENC_DUMP}.sha256"
echo "Encrypted backup created and checksummed: $ENC_DUMP"
