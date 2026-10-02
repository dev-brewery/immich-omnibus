#!/bin/bash
docker run --rm --entrypoint sh devbrewery/photoframe-immich:latest -c '
echo "=== grep for host assignment in app.common.js ==="
grep -nE "host\s*=|config.*host|host.*env|HOST|IMMICH_HOST" /opt/immich-server/dist/app.common.js | head -20
echo ""
echo "=== full bootstrap function (lines 30-70) ==="
sed -n "30,70p" /opt/immich-server/dist/app.common.js
'
