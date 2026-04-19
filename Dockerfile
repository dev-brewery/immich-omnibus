# Photoframe Immich — All-in-One Omnibus Image
# Runs Immich server, ML, Redis, and PostgreSQL under s6-overlay supervision
# Multi-platform: linux/amd64, linux/arm64

# === Stage 1: Download s6-overlay ===
FROM alpine:3.21 AS s6-downloader
ARG S6_VERSION=v3.2.2.0
ARG TARGETARCH
RUN apk add --no-cache curl
RUN if [ "$TARGETARCH" = "amd64" ]; then S6_ARCH=x86_64; \
    elif [ "$TARGETARCH" = "arm64" ]; then S6_ARCH=aarch64; \
    else S6_ARCH=$TARGETARCH; fi && \
    curl -sL "https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-noarch.tar.gz" \
      -o /tmp/s6-overlay-noarch.tar.gz && \
    curl -sL "https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-${S6_ARCH}.tar.gz" \
      -o /tmp/s6-overlay-arch.tar.gz

# === Stage 2: Omnibus image ===
FROM debian:bookworm-slim

ARG IMMICH_VERSION=v1.120.0

# Runtime dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates tini jq procps gosu \
    # PostgreSQL + pgvector
    postgresql-16 postgresql-16-pgvector \
    # Redis
    redis-server \
    && rm -rf /var/lib/apt/lists/*

# Install s6-overlay
COPY --from=s6-downloader /tmp/s6-overlay-noarch.tar.gz /tmp/
COPY --from=s6-downloader /tmp/s6-overlay-arch.tar.gz /tmp/
RUN tar -xzf /tmp/s6-overlay-noarch.tar.gz -C / && \
    tar -xzf /tmp/s6-overlay-arch.tar.gz -C / && \
    rm -f /tmp/s6-overlay-*.tar.gz

# Copy Immich server + ML from official pre-built images
COPY --from=ghcr.io/immich-app/immich-server:${IMMICH_VERSION} /usr/src/app /opt/immich-server
COPY --from=ghcr.io/immich-app/immich-server:${IMMICH_VERSION} /build/www /opt/immich-web
COPY --from=ghcr.io/immich-app/immich-machine-learning:${IMMICH_VERSION} /usr/src /opt/immich-ml

# Data directories
RUN mkdir -p /data/library /data/postgres /data/redis /data/model-cache /data/backup && \
    mkdir -p /var/run/postgresql /var/run/redis && \
    chown -R postgres:postgres /data/postgres /var/run/postgresql && \
    chown -R redis:redis /data/redis /var/run/redis

# s6-overlay service definitions
# Structure: /etc/s6-overlay/s6-rc.d/<service>/type + run
# Plus user bundle at /etc/s6-overlay/s6-rc.d/user/contents
COPY s6/services/ /etc/s6-overlay/s6-rc.d/
COPY s6/user/ /etc/s6-overlay/s6-rc.d/user/

# Utility scripts
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh

# s6-overlay init script — runs before all services
COPY s6/init/ /etc/s6-overlay/s6-rc.d/init/
# Make init a oneshot that runs before the bundle
RUN mkdir -p /etc/s6-overlay/s6-rc.d/user/contents.d && \
    for svc in postgres redis immich-ml immich-server; do \
        touch "/etc/s6-overlay/s6-rc.d/user/contents.d/$svc"; \
    done

# Environment defaults
ENV IMMICH_VERSION=${IMMICH_VERSION} \
    NODE_ENV=production \
    UPLOAD_LOCATION=/data/library \
    DB_DATA_LOCATION=/data/postgres \
    DB_HOST=/var/run/postgresql \
    DB_PORT=5432 \
    DB_USERNAME=immich \
    DB_PASSWORD=immich \
    DB_DATABASE_NAME=immich \
    REDIS_HOSTNAME=/var/run/redis/redis.sock \
    MACHINE_LEARNING_URL=http://localhost:3003 \
    MACHINE_LEARNING_WORKERS=1 \
    MACHINE_LEARNING_WORKER_CONCURRENCY=2 \
    DISABLE_MACHINE_LEARNING=false \
    ENABLE_MAP=false \
    IMMICH_PORT=2283 \
    ML_PORT=3003 \
    TZ=Etc/UTC

EXPOSE 2283

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -sf http://localhost:2283/api/server-info/ping || exit 1

VOLUME ["/data"]

ENTRYPOINT ["/init"]
