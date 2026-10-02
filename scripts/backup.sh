#!/command/with-contenv sh
# Backup: pg_dump + /data/.env, packaged into a single tarball.
[ -f /data/.env ] && . /data/.env

set -e

BACKUP_DIR="/data/backup"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/immich-backup-${TIMESTAMP}.tar.gz"
PGBIN="/usr/lib/postgresql/17/bin"

mkdir -p "$BACKUP_DIR"
echo "[backup] Starting backup..."

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

s6-setuidgid postgres ${PGBIN}/pg_dump \
    -h "${DB_HOSTNAME:-127.0.0.1}" \
    -p "${DB_PORT:-5432}" \
    -U "${DB_USERNAME:-immich}" \
    "${DB_DATABASE_NAME:-immich}" > "$STAGE/postgres.sql"

cp /data/.env "$STAGE/env" 2>/dev/null || true

tar -czf "$BACKUP_FILE" -C "$STAGE" .

ls -t "${BACKUP_DIR}"/immich-backup-*.tar.gz 2>/dev/null | tail -n +8 | xargs -r rm --

echo "[backup] Backup saved to $BACKUP_FILE"
