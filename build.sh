#!/bin/bash
# Build devbrewery/photoframe-immich with middleman extraction of upstream images.
#
# Upstream images (immich-server, immich-machine-learning) are pre-extracted
# via docker create + docker cp into ./ctx/<arch>/ BEFORE buildx is invoked.
# The Dockerfile then COPYs from that local context - BuildKit never performs
# cross-image COPY, which is the operation that produced 0-byte files under
# the docker-container driver and corrupted the content store (SIGBUS) on
# cumulative multi-GB copies.
#
# Usage:
#   ./build.sh [version]           # local --load, host arch only
#   ./build.sh --push [version]    # multi-arch amd64+arm64 --push to Docker Hub
#   ./build.sh --skip-extract ...  # reuse existing ./ctx (fast iteration)

set -euo pipefail

IMAGE_NAME="devbrewery/photoframe-immich"
IMMICH_VERSION="${IMMICH_VERSION:-v2.7.5}"
BUILDER_NAME="photoframe-builder"
CTX_DIR="ctx"

# --- Parse flags --------------------------------------------------------------
PUSH=0
SKIP_EXTRACT=0
POSARGS=()
for a in "$@"; do
    case "$a" in
        --push)         PUSH=1 ;;
        --skip-extract) SKIP_EXTRACT=1 ;;
        --*)            echo "Unknown flag: $a" >&2; exit 2 ;;
        *)              POSARGS+=("$a") ;;
    esac
done
VERSION="${POSARGS[0]:-latest}"

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; NC=$'\033[0m'
log()  { printf '%s%s%s\n' "$GREEN" "$*" "$NC"; }
warn() { printf '%s%s%s\n' "$YELLOW" "$*" "$NC"; }
err()  { printf '%s%s%s\n' "$RED" "$*" "$NC" >&2; }

# --- Determine target arches --------------------------------------------------
if [ "$PUSH" = "1" ]; then
    ARCHES=("amd64" "arm64")
    PLATFORMS="linux/amd64,linux/arm64"
else
    case "$(uname -m)" in
        x86_64)  HOST_ARCH=amd64 ;;
        aarch64) HOST_ARCH=arm64 ;;
        *) err "Unsupported host arch $(uname -m)"; exit 1 ;;
    esac
    ARCHES=("$HOST_ARCH")
    PLATFORMS="linux/$HOST_ARCH"
fi

log "=== Photoframe Immich Build ==="
echo "Image:   $IMAGE_NAME:$VERSION"
echo "Immich:  $IMMICH_VERSION"
echo "Arches:  ${ARCHES[*]}"
if [ "$PUSH" = "1" ]; then echo "Mode:    multi-arch push"; else echo "Mode:    local --load"; fi
echo

# --- Verify buildx ------------------------------------------------------------
if ! docker buildx version &>/dev/null; then
    err "docker buildx is not available"
    exit 1
fi

# --- Extract upstream content into ./ctx/<arch>/ ------------------------------
#
# Mapping (source inside upstream image -> path under ctx/<arch>/):
#   ghcr.io/immich-app/immich-server:$IMMICH_VERSION
#     /usr/src/app/server       -> immich-server/app-server        (dir)
#     /build                    -> immich-server/build              (dir: www, corePlugin, geodata, build-lock.json)
#     /usr/lib/jellyfin-ffmpeg  -> immich-server/jellyfin-ffmpeg    (dir)
#   (libvips is fetched fresh from @img/sharp-libvips npm — upstream /usr/local/lib is broken)
#   ghcr.io/immich-app/immich-machine-learning:$IMMICH_VERSION
#     /usr/src/immich_ml                     -> immich-ml/immich_ml                 (dir)
#     /usr/src/healthcheck.py                -> immich-ml/healthcheck.py            (file)
#     /opt/venv                              -> immich-ml/opt-venv                  (dir)
#     /usr/local/bin/python3.11              -> immich-ml/python3.11-bin            (file)
#     /usr/local/lib/python3.11              -> immich-ml/python3.11-lib            (dir)
#     /usr/local/lib/libpython3.11.so.1.0    -> immich-ml/libpython3.11.so.1.0      (file)

extract_image() {
    local arch="$1" image="$2" subdir="$3"
    shift 3
    local pairs=("$@")
    local cid

    log "  Pulling $image (linux/$arch)..."
    docker pull --platform "linux/$arch" "$image" >/dev/null

    log "  Creating extraction container..."
    cid=$(docker create --platform "linux/$arch" "$image")

    mkdir -p "$CTX_DIR/$arch/$subdir"
    for pair in "${pairs[@]}"; do
        local src="${pair%|*}" dst="${pair#*|}"
        local target="$CTX_DIR/$arch/$subdir/$dst"
        mkdir -p "$(dirname "$target")"
        rm -rf "$target"
        log "    cp $src -> $target"
        docker cp "$cid:$src" "$target"
    done

    docker rm -f "$cid" >/dev/null
}

if [ "$SKIP_EXTRACT" = "1" ]; then
    warn "--skip-extract: reusing existing ./$CTX_DIR"
else
    log "=== Extracting upstream content ==="
    rm -rf "$CTX_DIR"
    for arch in "${ARCHES[@]}"; do
        echo
        log "-- arch: $arch --"
        extract_image "$arch" \
            "ghcr.io/immich-app/immich-server:$IMMICH_VERSION" \
            "immich-server" \
            "/usr/src/app/server|app-server" \
            "/build|build" \
            "/usr/lib/jellyfin-ffmpeg|jellyfin-ffmpeg"
        extract_image "$arch" \
            "ghcr.io/immich-app/immich-machine-learning:$IMMICH_VERSION" \
            "immich-ml" \
            "/usr/src/immich_ml|immich_ml" \
            "/usr/src/healthcheck.py|healthcheck.py" \
            "/opt/venv|opt-venv" \
            "/usr/local/bin/python3.11|python3.11-bin" \
            "/usr/local/lib/python3.11|python3.11-lib" \
            "/usr/local/lib/libpython3.11.so.1.0|libpython3.11.so.1.0"
    done
    echo
    log "ctx size: $(du -sh "$CTX_DIR" | awk '{print $1}')"
fi

# --- Ensure builder exists ----------------------------------------------------
if ! docker buildx inspect "$BUILDER_NAME" &>/dev/null; then
    log "Creating buildx builder $BUILDER_NAME..."
    docker buildx create --name "$BUILDER_NAME" --driver docker-container --bootstrap >/dev/null
fi
docker buildx use "$BUILDER_NAME"

# --- Build --------------------------------------------------------------------
echo
if [ "$PUSH" = "1" ]; then
    log "=== Multi-arch push build: $PLATFORMS ==="
    docker buildx build \
        --platform "$PLATFORMS" \
        --push \
        --build-arg "IMMICH_VERSION=$IMMICH_VERSION" \
        -t "${IMAGE_NAME}:${VERSION}" \
        -t "${IMAGE_NAME}:latest" \
        --cache-from "type=registry,ref=${IMAGE_NAME}:buildcache" \
        --cache-to "type=registry,ref=${IMAGE_NAME}:buildcache,mode=max" \
        .
    log "Pushed: ${IMAGE_NAME}:${VERSION} and :latest"
else
    log "=== Local --load build: $PLATFORMS ==="
    docker buildx build \
        --platform "$PLATFORMS" \
        --load \
        --build-arg "IMMICH_VERSION=$IMMICH_VERSION" \
        -t "${IMAGE_NAME}:${VERSION}" \
        .
    log "Built: ${IMAGE_NAME}:${VERSION}"
    echo "Run with: docker run --rm -p 2283:2283 -v photoframe-data:/data ${IMAGE_NAME}:${VERSION}"
fi
echo
log "Done."
