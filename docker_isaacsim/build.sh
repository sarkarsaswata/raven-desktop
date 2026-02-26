#!/bin/bash
# Tag the image with a local namespace to prevent Docker from trying to 'pull' it
IMAGE_NAME="local/ubuntu-desktop-vnc:isaac-5.1"

echo "Building Isaac Sim Image: $IMAGE_NAME..."

# Build the image from the Dockerfile in the current directory
docker build -t "$IMAGE_NAME" .

echo "Build complete. Image is now available locally."
