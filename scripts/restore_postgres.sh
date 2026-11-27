#!/usr/bin/env bash
# Fixes DEF-406: Default POSTGRES_USER aligned with docker-compose.yml (`mizan_admin`)
set -euo pipefail
ENC_DUMP="${1:?Usage: ./scripts/restore_postgres.sh <path_to_dump.enc>}"
: "${BACKUP_PASSPHRASE:?Set BACKUP_PASSPHRASE before running restore}"
sha256sum -c "${ENC_DUMP}.sha256"
TMP_DUMP="/tmp/mizan_restore_$(date +%s).dump"
trap 'rm -f "$TMP_DUMP"' EXIT
openssl enc -d -aes-256-cbc -pbkdf2 -in "$ENC_DUMP" -out "$TMP_DUMP" -pass env:BACKUP_PASSPHRASE
docker compose exec -T postgres pg_restore -U "${POSTGRES_USER:-mizan_admin}" -d "${POSTGRES_DB:-mizan_prod}" --clean --if-exists < "$TMP_DUMP"
echo "Restore completed successfully from $ENC_DUMP"
