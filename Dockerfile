# Photoframe Immich - All-in-One Omnibus Image
#
# Cross-image content (python/ML code/jellyfin-ffmpeg/app code) is extracted
# from ghcr.io/immich-app/immich-server and immich-machine-learning by
# build.sh (docker create + docker cp) into ./ctx/<arch>/ before buildx is
# invoked. This avoids BuildKit cross-image COPY, which produced 0-byte files
# under the docker-container driver.
#
# Upstream v2.7.5's /usr/local/lib/libvips*.so files are shipped as 0 bytes
# (broken in upstream image). We fetch libvips from @img/sharp-libvips-*
# npm package — the exact statically-linked build that sharp 0.34.5 was
# compiled against.

ARG IMMICH_VERSION=v2.7.5

# === Stage 1: Download s6-overlay ===
FROM alpine:3.21 AS s6-downloader
ARG S6_VERSION=v3.2.2.0
ARG TARGETARCH
RUN apk add --no-cache curl xz
RUN if [ "$TARGETARCH" = "amd64" ]; then S6_ARCH=x86_64; \
    elif [ "$TARGETARCH" = "arm64" ]; then S6_ARCH=aarch64; \
    else S6_ARCH=$TARGETARCH; fi && \
    curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-noarch.tar.xz" \
      -o /tmp/s6-overlay-noarch.tar.xz && \
    curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/${S6_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" \
      -o /tmp/s6-overlay-arch.tar.xz

# === Stage 2: Download VectorChord .deb (proven method from Proxmox script) ===
FROM alpine:3.21 AS vchord-downloader
ARG TARGETARCH
ARG VCHORD_VERSION=0.5.3
RUN apk add --no-cache curl
RUN mkdir -p /tmp/vchord && \
    if [ "$TARGETARCH" = "amd64" ]; then VCHORD_ARCH=amd64; \
    elif [ "$TARGETARCH" = "arm64" ]; then VCHORD_ARCH=arm64; \
    else VCHORD_ARCH=$TARGETARCH; fi && \
    curl -fsSL "https://github.com/tensorchord/VectorChord/releases/download/${VCHORD_VERSION}/postgresql-17-vchord_${VCHORD_VERSION}-1_${VCHORD_ARCH}.deb" \
      -o /tmp/vchord/vchord.deb

# === Stage 3: Download sharp + sharp-libvips npm packages ===
# Immich v2.7.5's /usr/local/lib is broken (0-byte libvips files) AND their
# custom-built sharp-linux-*.node expects a split libvips/libvips-cpp layout
# that causes segfaults when loaded against the combined npm libvips. Fix:
# use sharp 0.34.5's stock prebuilt binary (@img/sharp-linux-*) which is
# compiled against the combined @img/sharp-libvips-linux-*'s
# libvips-cpp.so.8.17.3 (only glibc runtime deps — libheif/libjxl/etc. are
# all statically embedded).
FROM alpine:3.21 AS sharp-downloader
ARG TARGETARCH
ARG SHARP_VERSION=0.34.5
ARG SHARP_LIBVIPS_VERSION=1.2.4
RUN apk add --no-cache curl tar
RUN mkdir -p /tmp/libvips /tmp/sharp && \
    if [ "$TARGETARCH" = "amd64" ]; then PKG_ARCH=linux-x64; \
    elif [ "$TARGETARCH" = "arm64" ]; then PKG_ARCH=linux-arm64; \
    else PKG_ARCH=linux-${TARGETARCH}; fi && \
    cd /tmp/libvips && \
    curl -fsSL "https://registry.npmjs.org/@img/sharp-libvips-${PKG_ARCH}/-/sharp-libvips-${PKG_ARCH}-${SHARP_LIBVIPS_VERSION}.tgz" \
      -o pkg.tgz && \
    tar -xzf pkg.tgz && \
    ls -la package/lib/libvips-cpp.so.8.17.3 && \
    cd /tmp/sharp && \
    curl -fsSL "https://registry.npmjs.org/@img/sharp-${PKG_ARCH}/-/sharp-${PKG_ARCH}-${SHARP_VERSION}.tgz" \
      -o pkg.tgz && \
    tar -xzf pkg.tgz && \
    ls -la package/lib/sharp-${PKG_ARCH}.node

# === Stage 4: Final omnibus image ===
# Matches Immich v2.7.5 base (node:24-trixie-slim) so extracted server
# native modules (sharp/libvips) stay ABI-compatible with the runtime Node.
FROM node:24-trixie-slim

ARG IMMICH_VERSION
ARG TARGETARCH

# Install PostgreSQL 17, Redis, and runtime libs from trixie repos.
# Image decoders (heif/jxl/webp/png/etc.) are statically embedded in the
# sharp-libvips-linux-* tarball, so apt libvips-stack deps are not required.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl ca-certificates xz-utils procps tini gosu netcat-openbsd \
    postgresql-17 postgresql-client-17 postgresql-common postgresql-17-pgvector \
    redis-server redis-tools \
    libglib2.0-0 libgomp1 \
    libbluray2 libvpx9 libzvbi0 libmp3lame0 libopus0 libtheora0 \
    libvorbis0a libvorbisenc2 libx264-164 libopenmpt0 libdav1d7 \
    mesa-va-drivers mesa-vulkan-drivers ocl-icd-libopencl1 \
    && rm -rf /var/lib/apt/lists/*

# Install VectorChord extension (same method as Proxmox script)
COPY --from=vchord-downloader /tmp/vchord/vchord.deb /tmp/vchord.deb
RUN dpkg -i /tmp/vchord.deb && rm /tmp/vchord.deb

# Install s6-overlay
COPY --from=s6-downloader /tmp/s6-overlay-noarch.tar.xz /tmp/
COPY --from=s6-downloader /tmp/s6-overlay-arch.tar.xz /tmp/
RUN tar -xJf /tmp/s6-overlay-noarch.tar.xz -C / && \
    tar -xJf /tmp/s6-overlay-arch.tar.xz -C / && \
    rm -f /tmp/s6-overlay-*.tar.xz

# Install libvips from @img/sharp-libvips-* npm package (replaces broken
# upstream 0-byte libs). The stock prebuilt sharp-linux-*.node dlopens
# libvips-cpp.so.8.17.3 by exact SONAME (not libvips-cpp.so.42) so no
# symlink is needed for sharp itself; we keep libvips-cpp.so.42 for any
# tooling that expects that SONAME.
COPY --from=sharp-downloader /tmp/libvips/package/lib/libvips-cpp.so.8.17.3 /usr/local/lib/
RUN set -e && \
    cd /usr/local/lib && \
    ln -sf libvips-cpp.so.8.17.3 libvips-cpp.so.42 && \
    ln -sf libvips-cpp.so.42 libvips-cpp.so && \
    ldconfig

# === Extracted upstream content (pre-staged by build.sh into ./ctx/<arch>/) ===

# Immich server application code
COPY ctx/${TARGETARCH}/immich-server/app-server /opt/immich-server
COPY ctx/${TARGETARCH}/immich-server/build /build

# Replace Immich's custom-built sharp-linux-*.node with the stock prebuilt
# from @img/sharp-linux-*. Immich compiles sharp from source expecting a
# split libvips/libvips-cpp (two .so files), which our combined npm libvips
# doesn't provide — stock sharp expects the combined layout and works.
COPY --from=sharp-downloader /tmp/sharp/package/lib/ /tmp/sharp-stock/
RUN set -e && \
    if [ "$TARGETARCH" = "amd64" ]; then SHARP_NODE=sharp-linux-x64.node; \
    elif [ "$TARGETARCH" = "arm64" ]; then SHARP_NODE=sharp-linux-arm64.node; \
    else SHARP_NODE=sharp-linux-${TARGETARCH}.node; fi && \
    TARGET=$(find /opt/immich-server/node_modules -name "${SHARP_NODE}" -path "*/sharp/src/build/Release/*" -not -path "*/obj.target/*" | head -1) && \
    [ -n "$TARGET" ] || (echo "ERROR: could not locate ${SHARP_NODE} in /opt/immich-server" >&2 && exit 1) && \
    echo "replacing $TARGET with stock prebuilt" && \
    cp "/tmp/sharp-stock/${SHARP_NODE}" "$TARGET" && \
    rm -rf /tmp/sharp-stock

# jellyfin-ffmpeg (from immich-server upstream image)
COPY ctx/${TARGETARCH}/immich-server/jellyfin-ffmpeg /usr/lib/jellyfin-ffmpeg
RUN ln -sf /usr/lib/jellyfin-ffmpeg/ffmpeg /usr/local/bin/ffmpeg && \
    ln -sf /usr/lib/jellyfin-ffmpeg/ffprobe /usr/local/bin/ffprobe

# Immich ML (application code + python runtime from immich-machine-learning)
COPY ctx/${TARGETARCH}/immich-ml/immich_ml /opt/immich-ml/immich_ml
COPY ctx/${TARGETARCH}/immich-ml/healthcheck.py /opt/immich-ml/healthcheck.py
COPY ctx/${TARGETARCH}/immich-ml/opt-venv /opt/venv
COPY ctx/${TARGETARCH}/immich-ml/python3.11-bin /usr/local/bin/python3.11
COPY ctx/${TARGETARCH}/immich-ml/python3.11-lib /usr/local/lib/python3.11
COPY ctx/${TARGETARCH}/immich-ml/libpython3.11.so.1.0 /usr/local/lib/libpython3.11.so.1.0
RUN ln -sf /usr/local/lib/libpython3.11.so.1.0 /usr/local/lib/libpython3.11.so && \
    ln -sf /usr/local/bin/python3.11 /usr/local/bin/python3 && \
    ln -sf /usr/local/bin/python3 /usr/local/bin/python && \
    ldconfig

# Data directories (postgres user created by postgresql-17 package)
RUN mkdir -p /data/library /data/postgres /data/redis /data/model-cache /data/backup && \
    mkdir -p /var/run/postgresql /var/run/redis && \
    chown -R postgres:postgres /data/postgres /var/run/postgresql && \
    chown -R redis:redis /data/redis /var/run/redis

# s6 services (dependencies.d/init now lives in source tree)
COPY s6/services/ /etc/s6-overlay/s6-rc.d/

# s6 init oneshot (runs before all services)
COPY s6/init/ /etc/s6-overlay/s6-rc.d/init/

# Utility scripts
COPY scripts/ /app/scripts/
RUN chmod +x /app/scripts/*.sh

# s6 user bundle contents — which services to bring up
RUN mkdir -p /etc/s6-overlay/s6-rc.d/user/contents.d && \
    for svc in postgres redis immich-ml immich-server init; do \
        touch "/etc/s6-overlay/s6-rc.d/user/contents.d/$svc"; \
    done

# Environment defaults (DB_PASSWORD is generated at first run by init.sh into /data/.env)
#
# Memory guardrails — the whole point of the omnibus is to live on a 2GB host
# (Pi 5, small VPS), so caps are baked into each service rather than relying on
# `docker run --memory=...`. Rough idle budget with ML OFF: ~700MB-1GB.
# With ML ON: ~2.5-3GB (one CLIP model loaded lazily, unloaded after idle TTL).
ENV IMMICH_VERSION=${IMMICH_VERSION} \
    NODE_ENV=production \
    UPLOAD_LOCATION=/data/library \
    DB_DATA_LOCATION=/data/postgres \
    DB_HOSTNAME=127.0.0.1 \
    DB_PORT=5432 \
    DB_USERNAME=immich \
    DB_DATABASE_NAME=immich \
    DB_VECTOR_EXTENSION=vectorchord \
    REDIS_HOSTNAME=127.0.0.1 \
    REDIS_PORT=6379 \
    IMMICH_HOST=0.0.0.0 \
    IMMICH_MACHINE_LEARNING_URL=http://localhost:3003 \
    DISABLE_MACHINE_LEARNING=true \
    MACHINE_LEARNING_WORKERS=1 \
    MACHINE_LEARNING_WORKER_CONCURRENCY=1 \
    MACHINE_LEARNING_MODEL_TTL=300 \
    MACHINE_LEARNING_PRELOAD__CLIP__TEXTUAL= \
    MACHINE_LEARNING_PRELOAD__CLIP__VISUAL= \
    MACHINE_LEARNING_PRELOAD__FACIAL_RECOGNITION__DETECTION= \
    MACHINE_LEARNING_PRELOAD__FACIAL_RECOGNITION__RECOGNITION= \
    OMP_NUM_THREADS=2 \
    MKL_NUM_THREADS=2 \
    NODE_OPTIONS=--max-old-space-size=512 \
    ENABLE_MAP=false \
    IMMICH_PORT=2283 \
    ML_PORT=3003 \
    TZ=Etc/UTC

EXPOSE 2283

HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
    CMD curl -sf http://localhost:2283/api/server-info/ping || exit 1

VOLUME ["/data"]

ENTRYPOINT ["/init"]
