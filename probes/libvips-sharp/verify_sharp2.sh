#!/bin/bash
docker run --rm --entrypoint sh devbrewery/photoframe-immich:latest -c '
echo "=== full sharp error ==="
cd /opt/immich-server
node -e "try { require(\"sharp\"); } catch(e) { console.log(e.message); console.log(\"---\"); console.log(e.stack); }"
echo ""
echo "=== ldd on sharp-linux-x64.node ==="
ldd /opt/immich-server/node_modules/.pnpm/sharp@0.34.5/node_modules/sharp/src/build/Release/sharp-linux-x64.node 2>&1 | head -20
'
