#!/bin/bash
# ============================================================================
# build.sh - Build the ubuntu-desktop Docker image
# ============================================================================

IMAGE_NAME="local/ubuntu-desktop:minimal"

echo "Building Ubuntu Desktop image: ${IMAGE_NAME}..."
docker build -t "${IMAGE_NAME}" .
echo "Build complete."
