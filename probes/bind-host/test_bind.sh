#!/bin/bash
CONTAINER=photoframe-bind-test
docker rm -f "$CONTAINER" 2>/dev/null
docker run -d --name "$CONTAINER" -p 22830:2283 devbrewery/photoframe-immich:latest >/dev/null
echo "container: $(docker ps -q -f name=$CONTAINER) — waiting 75s..."
sleep 75
echo ""
echo "=== docker inspect port mapping ==="
docker inspect "$CONTAINER" --format "{{json .NetworkSettings.Ports}}"
echo ""
echo "=== curl HOST -> mapped 22830 ==="
curl -sv --max-time 8 http://localhost:22830/api/server-info/ping 2>&1 | tail -20
echo ""
echo "=== /proc/net/tcp listening (inside) ==="
docker exec "$CONTAINER" sh -c "
awk '\$4 == \"0A\" { split(\$2, a, \":\"); printf \"listen: %s:%d\n\", a[1], strtonum(\"0x\"a[2]) }' /proc/net/tcp /proc/net/tcp6 2>/dev/null | sort -u
"
docker rm -f "$CONTAINER" >/dev/null
