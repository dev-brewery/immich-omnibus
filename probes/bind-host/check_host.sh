#!/bin/bash
docker run --rm --entrypoint sh devbrewery/photoframe-immich:latest -c '
echo "=== config.repository.js 130-145 ==="
sed -n "125,150p" /opt/immich-server/dist/repositories/config.repository.js
echo ""
echo "=== search for IMMICH_HOST usage ==="
grep -n "IMMICH_HOST\|dto.IMMICH\|\.host\s*=\s*\|host:\s*\"\\|host:\s*dto" /opt/immich-server/dist/repositories/config.repository.js | head -20
'
