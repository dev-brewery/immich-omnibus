#!/bin/bash
CONTAINER=photoframe-manual
docker rm -f "$CONTAINER" 2>/dev/null || true
echo "=== starting container (detached) ==="
docker run -d --name "$CONTAINER" -p 22830:2283 devbrewery/photoframe-immich:latest >/dev/null
echo "  container id: $(docker ps -q -f name=$CONTAINER)"

echo ""
echo "=== 90s boot wait ==="
sleep 90

echo ""
echo "=== docker logs (tail 80) ==="
docker logs --tail 80 "$CONTAINER" 2>&1 | grep -avE "^$"

echo ""
echo "=== netstat inside container ==="
docker exec "$CONTAINER" sh -c "ss -ltn 2>/dev/null || netstat -ltn 2>/dev/null" | grep -E ":[0-9]+" || echo "no bindings visible"

echo ""
echo "=== ps inside ==="
docker exec "$CONTAINER" sh -c "ps auxf 2>/dev/null | head -30"

docker rm -f "$CONTAINER" >/dev/null
