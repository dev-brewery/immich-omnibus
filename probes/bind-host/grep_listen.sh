#!/bin/bash
docker run --rm --entrypoint sh devbrewery/photoframe-immich:latest -c '
echo "=== listen call + context in app.common.js ==="
grep -nE "listen|IMMICH_HOST|0\.0\.0\.0|127\.0\.0\.1" /opt/immich-server/dist/app.common.js | head -20
echo ""
echo "=== around listen call (20 lines context) ==="
grep -nE "listen" /opt/immich-server/dist/app.common.js
echo ""
echo "=== raw listen context (sed) ==="
LINE=$(grep -nE "\.listen\(" /opt/immich-server/dist/app.common.js | head -1 | cut -d: -f1)
if [ -n "$LINE" ]; then
  START=$((LINE-10))
  END=$((LINE+3))
  sed -n "${START},${END}p" /opt/immich-server/dist/app.common.js
fi
'
