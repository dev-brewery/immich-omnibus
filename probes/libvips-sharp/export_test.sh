#!/bin/bash
set -e
TD=$(mktemp -d)
cid=$(docker create --platform linux/amd64 ghcr.io/immich-app/immich-server:v2.7.5)
echo "container=$cid"
docker export "$cid" | tar -x -C "$TD" \
    usr/local/lib/libvips-cpp.so.42.19.3 \
    usr/local/lib/libvips.so.42.19.3 \
    usr/local/lib/libheif.so.1.20.2 \
    usr/local/lib/libjxl.so.0.11.1
docker rm "$cid" >/dev/null
echo "=== via docker export + tar ==="
ls -la "$TD/usr/local/lib/"
rm -rf "$TD"
