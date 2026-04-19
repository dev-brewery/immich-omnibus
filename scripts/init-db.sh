#!/usr/bin/with-contenv sh
# Initialize PostgreSQL database if it doesn't exist
set -e

PGDATA="${DB_DATA_LOCATION:-/data/postgres}"

if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "[postgres-init] Initializing database cluster at $PGDATA..."
    
    mkdir -p "$PGDATA"
    chown -R postgres:postgres "$PGDATA"
    
    su-exec postgres pg_ctl init \
        -D "$PGDATA" \
        -o "--data-checksums" \
        -o "--encoding=UTF8" \
        -o "--locale=C"
    
    echo "[postgres-init] Creating database and user..."
    su-exec postgres pg_ctl -D "$PGDATA" -o "-p ${DB_PORT:-5432}" -w start
    
    su-exec postgres psql -p "${DB_PORT:-5432}" -c "CREATE USER ${DB_USERNAME:-immich} WITH PASSWORD '${DB_PASSWORD:-immich}';" 2>/dev/null || true
    su-exec postgres psql -p "${DB_PORT:-5432}" -c "CREATE DATABASE ${DB_DATABASE_NAME:-immich} OWNER ${DB_USERNAME:-immich};" 2>/dev/null || true
    
    echo "[postgres-init] Enabling pgvector extension..."
    su-exec postgres psql -d "${DB_DATABASE_NAME:-immich}" -p "${DB_PORT:-5432}" -c "CREATE EXTENSION IF NOT EXISTS vector;" 2>/dev/null || true
    su-exec postgres psql -d "${DB_DATABASE_NAME:-immich}" -p "${DB_PORT:-5432}" -c "CREATE EXTENSION IF NOT EXISTS vectorscale;" 2>/dev/null || true
    
    su-exec postgres pg_ctl -D "$PGDATA" -m fast -w stop
    
    echo "[postgres-init] Database initialized."
else
    echo "[postgres-init] Database already exists at $PGDATA, skipping init."
fi
