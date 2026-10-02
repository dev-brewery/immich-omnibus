#!/bin/bash
set -e
echo "=== Finding REAL libvips in upstream image ==="
docker run --rm --entrypoint sh --platform linux/amd64 ghcr.io/immich-app/immich-server:v2.7.5 -c '
echo "--- all libvips* files (non-zero) ---"
find / -xdev -name "libvips*" -size +0 2>/dev/null
echo "--- ldconfig cache entries ---"
ldconfig -p 2>/dev/null | grep -E "vips|heif|jxl"
echo "--- actual sharp node binary ---"
find /usr/src /opt/immich-server /usr/local -name "sharp-*.node" 2>/dev/null
echo "--- ld.so.conf.d ---"
cat /etc/ld.so.conf.d/*.conf 2>/dev/null
echo "--- env from entrypoint run ---"
env | grep -iE "path|ld_"
'
