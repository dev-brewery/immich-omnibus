#!/bin/bash
docker run --rm --entrypoint sh devbrewery/photoframe-immich:latest -c '
echo "=== grep server routes in dist ==="
grep -rnE "ping|server-info|ServerController|Mapped.*ping" /opt/immich-server/dist/controllers/ 2>/dev/null | grep -vE "//" | head -20
echo ""
echo "=== all controller files ==="
ls /opt/immich-server/dist/controllers/ | head -20
'
