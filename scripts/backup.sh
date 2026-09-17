#!/usr/bin/env bash
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-backups}"
DB_NAME="${DB_NAME:-hotel_db}"
DB_USER="${DB_USER:-postgres}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump"

mkdir -p "${BACKUP_DIR}"

echo "Creating PostgreSQL backup: ${BACKUP_FILE}"
docker compose exec -T db pg_dump \
  -U "${DB_USER}" \
  -d "${DB_NAME}" \
  --format=custom \
  > "${BACKUP_FILE}"

test -s "${BACKUP_FILE}"
echo "Backup completed successfully."
