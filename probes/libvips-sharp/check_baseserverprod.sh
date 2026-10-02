#!/bin/bash
# Check base-server-prod images for working libvips.
# User already has :20241105 locally.
echo "=== base-server-prod:20241105 (local) ==="
docker run --rm --entrypoint sh --platform linux/amd64 ghcr.io/immich-app/base-server-prod:20241105 -c '
    ls -la /usr/local/lib/libvips*.so.42.* 2>/dev/null
    echo "---"
    ldconfig -p | grep -E "libvips|libheif|libjxl" | head -10
' 2>&1

echo ""
echo "=== list recent base-server-prod tags from registry ==="
# Use docker manifest on a probable-modern tag. Immich bumps these with dates.
for tag in 20250101 20250301 20250601 20250801 20251001 20260101 20260301 latest; do
    if docker manifest inspect ghcr.io/immich-app/base-server-prod:$tag >/dev/null 2>&1; then
        echo "exists: $tag"
    fi
done
