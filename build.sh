#!/bin/bash
# Build and push multi-platform image to Docker Hub
# Usage: ./build.sh [version] [--push]
# Example: ./build.sh v1.0.0 --push

set -e

IMAGE_NAME="devbrewery/photoframe-immich"
VERSION="${1:-latest}"
PUSH="${2:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== Photoframe Immich Build ===${NC}"
echo "Image: $IMAGE_NAME"
echo "Version: $VERSION"
echo ""

# Check for Docker buildx
if ! docker buildx version &>/dev/null; then
    echo -e "${RED}ERROR: docker buildx is not available${NC}"
    echo "Install Docker Buildx plugin: https://docs.docker.com/build/buildx/install/"
    exit 1
fi

# Create builder if it doesn't exist
if ! docker buildx inspect photoframe-builder &>/dev/null; then
    echo -e "${YELLOW}Creating buildx builder...${NC}"
    docker buildx create \
        --name photoframe-builder \
        --driver docker-container \
        --bootstrap --use
    echo ""
fi

docker buildx use photoframe-builder

# Build platforms
PLATFORMS="linux/amd64,linux/arm64"
echo -e "${GREEN}Building for: $PLATFORMS${NC}"
echo ""

if [ "$PUSH" = "--push" ]; then
    echo -e "${YELLOW}Building and pushing to Docker Hub...${NC}"
    docker buildx build \
        --platform "$PLATFORMS" \
        --push \
        -t "${IMAGE_NAME}:${VERSION}" \
        -t "${IMAGE_NAME}:latest" \
        --cache-from "type=registry,ref=${IMAGE_NAME}:buildcache" \
        --cache-to "type=registry,ref=${IMAGE_NAME}:buildcache,mode=max" \
        .
    echo ""
    echo -e "${GREEN}Pushed:${NC}"
    echo "  ${IMAGE_NAME}:${VERSION}"
    echo "  ${IMAGE_NAME}:latest"
else
    echo -e "${YELLOW}Building locally (not pushing)...${NC}"
    docker buildx build \
        --platform "$PLATFORMS" \
        --load \
        -t "${IMAGE_NAME}:${VERSION}" \
        .
    echo ""
    echo -e "${GREEN}Built:${NC} ${IMAGE_NAME}:${VERSION}"
    echo "Run with: docker run --rm -p 2283:2283 -v photoframe-data:/data ${IMAGE_NAME}:${VERSION}"
fi

echo ""
echo -e "${GREEN}Done.${NC}"
