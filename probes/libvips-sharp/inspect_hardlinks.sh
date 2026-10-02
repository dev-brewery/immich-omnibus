#!/bin/bash
set -e
cid=$(docker create --platform linux/amd64 ghcr.io/immich-app/immich-server:v2.7.5)
echo "Looking for libvips in tar stream (first path gets content, rest are links):"
docker export "$cid" | tar -tv 2>/dev/null | grep -E 'libvips-cpp.so.42.19.3|libvips.so.42.19.3|libheif.so.1.20.2|libjxl.so.0.11.1' | head -30
docker rm "$cid" >/dev/null
