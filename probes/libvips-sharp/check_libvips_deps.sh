#!/bin/bash
set -e
TD=$(mktemp -d); cd "$TD"
curl -fsSL -o pkg.tgz https://registry.npmjs.org/@img/sharp-libvips-linux-x64/-/sharp-libvips-linux-x64-1.2.4.tgz
tar -xzf pkg.tgz
echo "=== ldd on libvips-cpp.so.8.17.3 (using node:24-trixie-slim) ==="
docker run --rm -v "$TD:/work" --platform linux/amd64 node:24-trixie-slim sh -c '
apt-get update -qq >/dev/null 2>&1
apt-get install -y --no-install-recommends file binutils >/dev/null 2>&1
echo "--- ldd (missing libs will show as not found) ---"
ldd /work/package/lib/libvips-cpp.so.8.17.3 2>&1
echo ""
echo "--- readelf DT_NEEDED ---"
readelf -d /work/package/lib/libvips-cpp.so.8.17.3 | grep NEEDED
'
cd /; rm -rf "$TD"
