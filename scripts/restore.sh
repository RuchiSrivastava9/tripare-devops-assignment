#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <backup-file>"
  exit 1
fi

BACKUP_FILE="$1"
DB_USER="${DB_USER:-postgres}"
RESTORE_DB="${RESTORE_DB:-hotel_db_restore}"

if [[ ! -s "${BACKUP_FILE}" ]]; then
  echo "Backup file not found or empty: ${BACKUP_FILE}"
  exit 1
fi

echo "Creating fresh restore database: ${RESTORE_DB}"
docker compose exec -T db dropdb --if-exists -U "${DB_USER}" "${RESTORE_DB}"
docker compose exec -T db createdb -U "${DB_USER}" "${RESTORE_DB}"

echo "Restoring ${BACKUP_FILE} into ${RESTORE_DB}"
docker compose exec -T db pg_restore \
  -U "${DB_USER}" \
  -d "${RESTORE_DB}" \
  --exit-on-error \
  < "${BACKUP_FILE}"

echo "Restore completed successfully. Verification:"
docker compose exec -T db psql -U "${DB_USER}" -d "${RESTORE_DB}" -c \
  "SELECT COUNT(*) AS hotel_bookings FROM hotel_bookings;"
docker compose exec -T db psql -U "${DB_USER}" -d "${RESTORE_DB}" -c \
  "SELECT COUNT(*) AS booking_events FROM booking_events;"
