#!/usr/bin/with-contenv sh
# One-time first-run setup: generate .env, create admin, set permissions
set -e

ENV_FILE="/data/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "[first-run] Generating initial configuration..."
    
    cat > "$ENV_FILE" <<EOF
# Photoframe Immich configuration — generated on first run
# Edit this file to customize your installation

UPLOAD_LOCATION=${UPLOAD_LOCATION:-/data/library}
DB_DATA_LOCATION=${DB_DATA_LOCATION:-/data/postgres}
DB_HOST=${DB_HOST:-/var/run/postgresql}
DB_PORT=${DB_PORT:-5432}
DB_USERNAME=${DB_USERNAME:-immich}
DB_PASSWORD=${DB_PASSWORD:-immich}
DB_DATABASE_NAME=${DB_DATABASE_NAME:-immich}
REDIS_HOSTNAME=${REDIS_HOSTNAME:-/var/run/redis/redis.sock}
MACHINE_LEARNING_URL=${MACHINE_LEARNING_URL:-http://localhost:3003}
MACHINE_LEARNING_WORKERS=${MACHINE_LEARNING_WORKERS:-1}
MACHINE_LEARNING_WORKER_CONCURRENCY=${MACHINE_LEARNING_WORKER_CONCURRENCY:-2}
DISABLE_MACHINE_LEARNING=${DISABLE_MACHINE_LEARNING:-false}
ENABLE_MAP=${ENABLE_MAP:-false}
TZ=${TZ:-Etc/UTC}
EOF

    echo "[first-run] Configuration written to $ENV_FILE"
fi

# Ensure data directories exist with correct permissions
mkdir -p "${UPLOAD_LOCATION:-/data/library}" "${DB_DATA_LOCATION:-/data/postgres}" /data/redis /data/model-cache /data/backup
chown -R postgres:postgres "${DB_DATA_LOCATION:-/data/postgres}"
chown -R redis:redis /data/redis

echo "[first-run] Setup complete."
