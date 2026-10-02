#!/bin/bash
docker run --rm --entrypoint sh devbrewery/photoframe-immich:latest -c '
echo "=== start of bootstrap function ==="
sed -n "1,30p" /opt/immich-server/dist/app.common.js
echo ""
echo "=== caller of bootstrapCommon ==="
grep -rnE "bootstrapCommon|IMMICH_HOST|process\.env\..*HOST" /opt/immich-server/dist/ 2>/dev/null | grep -vE "common\.js$" | head -10
'
