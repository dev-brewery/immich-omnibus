#!/bin/sh
# First-run initialization
# Ensures data directories and config exist before services start
set -e

ENV_FILE="/data/.env"
UPLOAD="${UPLOAD_LOCATION:-/data/library}"
DBDATA="${DB_DATA_LOCATION:-/data/postgres}"

# Create directories
mkdir -p "$UPLOAD" "$DBDATA" /data/redis /data/model-cache /data/backup /var/run/postgresql /var/run/redis
chown -R postgres:postgres "$DBDATA" /var/run/postgresql
chown -R redis:redis /data/redis /var/run/redis

# Generate .env on first run
if [ ! -f "$ENV_FILE" ]; then
    cat > "$ENV_FILE" <<EOF
# Photoframe Immich — auto-generated configuration
UPLOAD_LOCATION=$UPLOAD
DB_DATA_LOCATION=$DBDATA
DB_HOST=${DB_HOST:-/var/run/postgresql}
DB_PORT=${DB_PORT:-5432}
DB_USERNAME=${DB_USERNAME:-immich}
DB_PASSWORD=${DB_PASSWORD:-immich}
DB_DATABASE_NAME=${DB_DATABASE_NAME:-immich}
REDIS_HOSTNAME=${REDIS_HOSTNAME:-/var/run/redis/redis.sock}
MACHINE_LEARNING_URL=http://localhost:3003
MACHINE_LEARNING_WORKERS=${MACHINE_LEARNING_WORKERS:-1}
MACHINE_LEARNING_WORKER_CONCURRENCY=${MACHINE_LEARNING_WORKER_CONCURRENCY:-2}
TZ=${TZ:-Etc/UTC}
EOF
    echo "[init] Configuration written to $ENV_FILE"
fi

echo "[init] Data directories ready."
