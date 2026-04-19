#!/usr/bin/with-contenv sh
# Backup script — dumps PostgreSQL and packages config
set -e

BACKUP_DIR="/data/backup"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/immich-backup-${TIMESTAMP}.tar.gz"

mkdir -p "$BACKUP_DIR"

echo "[backup] Starting backup..."

# Dump PostgreSQL
PGDUMP_TMP=$(mktemp)
su-exec postgres pg_dump \
    -h "${DB_HOST:-/var/run/postgresql}" \
    -p "${DB_PORT:-5432}" \
    -U "${DB_USERNAME:-immich}" \
    "${DB_DATABASE_NAME:-immich}" > "$PGDUMP_TMP"

# Package backup
tar -czf "$BACKUP_FILE" \
    -C / \
    "$PGDUMP_TMP" \
    "data/.env" 2>/dev/null || true

rm -f "$PGDUMP_TMP"

# Keep only last 7 backups
ls -t "${BACKUP_DIR}"/immich-backup-*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm --

echo "[backup] Backup saved to $BACKUP_FILE"
