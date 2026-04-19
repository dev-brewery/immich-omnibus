#!/bin/bash
# Test script — validates the omnibus image works correctly
# Usage: ./test.sh [image_tag]
# Example: ./test.sh devbrewery/photoframe-immich:latest

set -e

IMAGE="${1:-devbrewery/photoframe-immich:latest}"
CONTAINER_NAME="photoframe-immich-test"
TIMEOUT=120

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

cleanup() {
    echo -e "${YELLOW}Cleaning up...${NC}"
    docker stop "$CONTAINER_NAME" 2>/dev/null || true
    docker rm "$CONTAINER_NAME" 2>/dev/null || true
    docker volume rm photoframe-test-data 2>/dev/null || true
}
trap cleanup EXIT

echo -e "${GREEN}=== Photoframe Immich Test Suite ===${NC}"
echo "Image: $IMAGE"
echo ""

# Test 1: Image pulls successfully
echo -e "${YELLOW}[1/5] Pulling image...${NC}"
docker pull "$IMAGE"
echo -e "${GREEN}  ✓ Image pulled${NC}"

# Test 2: Container starts
echo -e "${YELLOW}[2/5] Starting container...${NC}"
docker run -d \
    --name "$CONTAINER_NAME" \
    -p 2283:2283 \
    -v photoframe-test-data:/data \
    -e IMMICH_ADMIN_EMAIL=test@test.com \
    -e IMMICH_ADMIN_PASSWORD=testpassword123 \
    "$IMAGE"

echo -e "${GREEN}  ✓ Container started${NC}"

# Test 3: Services become healthy within timeout
echo -e "${YELLOW}[3/5] Waiting for services to start (max ${TIMEOUT}s)...${NC}"
ELAPSED=0
until curl -sf http://localhost:2283/api/server-info/ping 2>/dev/null | grep -q "pong"; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo -e "${RED}  ✗ Timed out waiting for Immich${NC}"
        echo "Container logs:"
        docker logs "$CONTAINER_NAME" --tail 50
        exit 1
    fi
    echo "  Waiting... (${ELAPSED}s)"
done
echo -e "${GREEN}  ✓ Immich responding on port 2283${NC}"

# Test 4: PostgreSQL is running
echo -e "${YELLOW}[4/5] Checking PostgreSQL...${NC}"
if docker exec "$CONTAINER_NAME" pg_isready -h /var/run/postgresql -q 2>/dev/null; then
    echo -e "${GREEN}  ✓ PostgreSQL is running${NC}"
else
    echo -e "${RED}  ✗ PostgreSQL not responding${NC}"
    docker logs "$CONTAINER_NAME" --tail 30
    exit 1
fi

# Test 5: Redis is running
echo -e "${YELLOW}[5/5] Checking Redis...${NC}"
if docker exec "$CONTAINER_NAME" redis-cli -s /var/run/redis/redis.sock ping 2>/dev/null | grep -q "PONG"; then
    echo -e "${GREEN}  ✓ Redis is running${NC}"
else
    # Redis might not have redis-cli in the slim image, check socket instead
    if docker exec "$CONTAINER_NAME" test -S /var/run/redis/redis.sock 2>/dev/null; then
        echo -e "${GREEN}  ✓ Redis socket exists${NC}"
    else
        echo -e "${RED}  ✗ Redis not responding${NC}"
        docker logs "$CONTAINER_NAME" --tail 30
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}=== All tests passed ===${NC}"
echo "Image $IMAGE is ready for deployment."
