#!/bin/sh
# First-run initialization.
set -e

ENV_FILE="/data/.env"
UPLOAD="${UPLOAD_LOCATION:-/data/library}"
DBDATA="${DB_DATA_LOCATION:-/data/postgres}"

mkdir -p "$UPLOAD" "$DBDATA" /data/redis /data/model-cache /data/backup /var/run/postgresql /var/run/redis
chown -R postgres:postgres "$DBDATA" /var/run/postgresql
chown -R redis:redis /data/redis /var/run/redis

if [ ! -f "$ENV_FILE" ]; then
    DB_PASSWORD_GENERATED=$(head -c 24 /dev/urandom | base64 | tr -d '+/=\n' | cut -c1-32)
    cat > "$ENV_FILE" <<EOF
# Photoframe Immich - generated on first run; safe to edit.
# Services source this file; do not remove DB_PASSWORD after first run
# (postgres was initialized with that password).
UPLOAD_LOCATION=$UPLOAD
DB_DATA_LOCATION=$DBDATA
DB_HOSTNAME=127.0.0.1
DB_PORT=5432
DB_USERNAME=immich
DB_PASSWORD=$DB_PASSWORD_GENERATED
DB_DATABASE_NAME=immich
DB_VECTOR_EXTENSION=vectorchord
REDIS_HOSTNAME=127.0.0.1
REDIS_PORT=6379
MACHINE_LEARNING_URL=http://localhost:3003
MACHINE_LEARNING_WORKERS=${MACHINE_LEARNING_WORKERS:-1}
MACHINE_LEARNING_WORKER_CONCURRENCY=${MACHINE_LEARNING_WORKER_CONCURRENCY:-2}
TZ=${TZ:-Etc/UTC}
EOF
    chmod 600 "$ENV_FILE"
    echo "[init] Generated $ENV_FILE with random DB_PASSWORD"
fi

echo "[init] Data directories ready."
