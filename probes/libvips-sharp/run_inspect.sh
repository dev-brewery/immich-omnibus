#!/bin/bash
set -e
echo "=== ls in running container ==="
docker run --rm --entrypoint sh --platform linux/amd64 ghcr.io/immich-app/immich-server:v2.7.5 -c '
    ls -la /usr/local/lib/libvips* /usr/local/lib/libheif* /usr/local/lib/libjxl* 2>&1
    echo "--- inode check ---"
    stat -c "%i %s %n" /usr/local/lib/libvips*.so.42.19.3 /usr/local/lib/libvips.so.42.19.3 2>&1
    echo "--- which layer ---"
    echo "file command on one:"
    file /usr/local/lib/libvips-cpp.so.42.19.3 2>&1 | head
'
