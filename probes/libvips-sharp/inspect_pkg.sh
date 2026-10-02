#!/bin/bash
set -e
TD=$(mktemp -d); cd "$TD"
curl -fsSL -o pkg.tgz https://registry.npmjs.org/@img/sharp-libvips-linux-x64/-/sharp-libvips-linux-x64-1.2.4.tgz
tar -xzf pkg.tgz
echo "=== full lib/ listing ==="
ls -la package/lib/
echo ""
echo "=== all files in package ==="
find package/ -type f -o -type l | head -30
cd /; rm -rf "$TD"
