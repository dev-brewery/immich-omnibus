#!/bin/bash
# Test script - validates the omnibus image works correctly
# Usage: ./test.sh [image_tag]

set -e

IMAGE="${1:-devbrewery/photoframe-immich:latest}"
CONTAINER_NAME="photoframe-immich-test"
TIMEOUT=120

RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; NC=$'\033[0m'

cleanup() {
    printf '%s%s%s\n' "$YELLOW" "Cleaning up..." "$NC"
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    docker volume rm photoframe-test-data 2>/dev/null || true
}
trap cleanup EXIT

printf '%s%s%s\n' "$GREEN" "=== Photoframe Immich Test Suite ===" "$NC"
echo "Image: $IMAGE"
echo

printf '%s%s%s\n' "$YELLOW" "[1/5] Locating image..." "$NC"
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
    docker pull "$IMAGE"
fi
printf '%s%s%s\n' "$GREEN" "  OK image present" "$NC"

printf '%s%s%s\n' "$YELLOW" "[2/5] Starting container..." "$NC"
docker run -d \
    --name "$CONTAINER_NAME" \
    -p 2283:2283 \
    -v photoframe-test-data:/data \
    "$IMAGE" >/dev/null
printf '%s%s%s\n' "$GREEN" "  OK container started" "$NC"

printf '%s%s%s\n' "$YELLOW" "[3/5] Waiting for Immich HTTP (max ${TIMEOUT}s)..." "$NC"
ELAPSED=0
until curl -sf http://localhost:2283/api/server/ping 2>/dev/null | grep -q "pong"; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    if [ $ELAPSED -ge $TIMEOUT ]; then
        printf '%s%s%s\n' "$RED" "  FAIL timed out waiting for Immich" "$NC"
        echo "Container logs:"
        docker logs "$CONTAINER_NAME" --tail 80
        exit 1
    fi
    echo "  Waiting... (${ELAPSED}s)"
done
printf '%s%s%s\n' "$GREEN" "  OK Immich responding on port 2283" "$NC"

printf '%s%s%s\n' "$YELLOW" "[4/5] Checking PostgreSQL..." "$NC"
if docker exec "$CONTAINER_NAME" /usr/lib/postgresql/17/bin/pg_isready -h 127.0.0.1 -p 5432 -U immich -q 2>/dev/null; then
    printf '%s%s%s\n' "$GREEN" "  OK PostgreSQL ready" "$NC"
else
    printf '%s%s%s\n' "$RED" "  FAIL PostgreSQL not ready" "$NC"
    docker logs "$CONTAINER_NAME" --tail 40
    exit 1
fi

printf '%s%s%s\n' "$YELLOW" "[5/5] Checking Redis..." "$NC"
if docker exec "$CONTAINER_NAME" redis-cli -h 127.0.0.1 -p 6379 ping 2>/dev/null | grep -q "PONG"; then
    printf '%s%s%s\n' "$GREEN" "  OK Redis PONG" "$NC"
else
    printf '%s%s%s\n' "$RED" "  FAIL Redis not responding" "$NC"
    docker logs "$CONTAINER_NAME" --tail 40
    exit 1
fi

echo
printf '%s%s%s\n' "$GREEN" "=== All tests passed ===" "$NC"
echo "Image $IMAGE is ready for deployment."
