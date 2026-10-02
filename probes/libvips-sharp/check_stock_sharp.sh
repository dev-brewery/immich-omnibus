#!/bin/bash
set -e
TD=$(mktemp -d); cd "$TD"
echo "=== fetch @img/sharp-linux-x64@0.34.5 prebuilt ==="
curl -fsSL -o sharp.tgz https://registry.npmjs.org/@img/sharp-linux-x64/-/sharp-linux-x64-0.34.5.tgz 2>&1 | tail -3
tar -xzf sharp.tgz
echo ""
echo "=== package contents ==="
find package/ -type f | head -20
echo ""
echo "=== ldd the prebuilt sharp-linux-x64.node ==="
# node:24-trixie-slim has the glib deps we just installed
docker run --rm -v "$TD:/w" --platform linux/amd64 node:24-trixie-slim sh -c '
  apt-get update -qq >/dev/null 2>&1
  apt-get install -y --no-install-recommends libglib2.0-0 binutils >/dev/null 2>&1
  NODE=$(find /w/package -name "sharp-linux-x64.node" | head -1)
  echo "node file: $NODE"
  echo "--- ldd ---"
  ldd "$NODE" 2>&1
  echo "--- readelf NEEDED ---"
  readelf -d "$NODE" | grep NEEDED
'
cd /; rm -rf "$TD"
