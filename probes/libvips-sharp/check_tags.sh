#!/bin/bash
echo "=== Check 'release' tag (current stable) ==="
docker pull --platform linux/amd64 ghcr.io/immich-app/immich-server:release 2>&1 | tail -3
docker run --rm --entrypoint sh --platform linux/amd64 ghcr.io/immich-app/immich-server:release -c '
    echo "version tag label:"; grep -r "build-url\|IMMICH_BUILD_IMAGE=" /etc 2>/dev/null | head
    echo "libvips.so.42.19.3 size:"; stat -c "%s %n" /usr/local/lib/libvips.so.42.19.3 2>/dev/null
    echo "sharp load test:"
    cd /usr/src/app/server 2>/dev/null
    node -e "try { require(\"sharp\"); console.log(\"SHARP OK\"); } catch(e) { console.log(\"SHARP FAIL:\", e.message.split(chr(10))[0]); }" 2>&1 | head -3
' 2>&1
echo ""
echo "=== Check specific earlier version v1.140.0 (latest before v2 split) ==="
docker pull --platform linux/amd64 ghcr.io/immich-app/immich-server:v1.140.0 2>&1 | tail -3
docker run --rm --entrypoint sh --platform linux/amd64 ghcr.io/immich-app/immich-server:v1.140.0 -c '
    echo "libvips.so.42 target size:"; ls -la /usr/local/lib/libvips.so.42* 2>/dev/null
    echo "sharp load test:"
    cd /usr/src/app/server 2>/dev/null
    node -e "try { require(\"sharp\"); console.log(\"SHARP OK\"); } catch(e) { console.log(\"SHARP FAIL:\", e.message.split(chr(10))[0]); }" 2>&1 | head -3
' 2>&1
