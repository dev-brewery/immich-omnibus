#!/bin/bash
echo "=== Test whether sharp actually loads in upstream image ==="
docker run --rm --entrypoint sh --platform linux/amd64 ghcr.io/immich-app/immich-server:v2.7.5 -c '
echo "--- ldd on sharp-linux-x64.node ---"
ldd /usr/src/app/server/node_modules/.pnpm/sharp@0.34.5/node_modules/sharp/src/build/Release/sharp-linux-x64.node 2>&1 | head -30
echo ""
echo "--- try to actually dlopen sharp from node ---"
cd /usr/src/app/server
node -e "try { const s = require(\"sharp\"); console.log(\"SHARP OK\", s.versions); } catch(e) { console.log(\"SHARP FAIL:\", e.message); }"
'
