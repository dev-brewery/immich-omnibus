#!/bin/bash
set -e
CONTAINER=photoframe-manual
docker rm -f "$CONTAINER" 2>/dev/null || true
echo "=== starting container (detached) ==="
docker run -d --rm --name "$CONTAINER" -p 22830:2283 devbrewery/photoframe-immich:latest >/dev/null

echo "=== waiting for Immich to bind 2283... ==="
for i in $(seq 1 60); do
    if docker exec "$CONTAINER" sh -c "ss -ltn 2>/dev/null | grep -q :2283 || netstat -ltn 2>/dev/null | grep -q :2283"; then
        echo "  bound at attempt $i"
        break
    fi
    sleep 2
done

echo ""
echo "=== netstat inside container ==="
docker exec "$CONTAINER" sh -c "ss -ltn 2>/dev/null || netstat -ltn 2>/dev/null" | grep 2283

echo ""
echo "=== curl inside container (IPv4) ==="
docker exec "$CONTAINER" sh -c "curl -sf --max-time 5 http://127.0.0.1:2283/api/server-info/ping || echo FAILED"

echo ""
echo "=== curl inside container (IPv6 ::1) ==="
docker exec "$CONTAINER" sh -c "curl -sf --max-time 5 http://[::1]:2283/api/server-info/ping || echo FAILED"

echo ""
echo "=== curl FROM HOST to mapped port 22830 ==="
curl -sf --max-time 5 http://localhost:22830/api/server-info/ping || echo "HOST CURL FAILED"

echo ""
echo "=== immich-server log tail ==="
docker logs --tail 20 "$CONTAINER" 2>&1 | grep -aE "listening|ERROR|FATAL" | tail -10

docker rm -f "$CONTAINER" >/dev/null
