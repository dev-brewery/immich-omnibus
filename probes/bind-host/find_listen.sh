#!/bin/bash
docker run --rm --entrypoint sh devbrewery/photoframe-immich:latest -c '
echo "=== IMMICH_HOST env in container ==="
printenv | grep -E "IMMICH|HOST"
echo ""
echo "=== grep for listen in main.js ==="
grep -nE "listen\(|0\.0\.0\.0|IMMICH_HOST" /opt/immich-server/dist/main.js 2>/dev/null | head -10
echo ""
echo "=== grep workers api ==="
find /opt/immich-server/dist -name "*.js" | xargs grep -lE "listen.*port|app\.listen" 2>/dev/null | head -5
'
