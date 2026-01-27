#!/bin/bash
# ===============================================
# Check Docker Image Sizes (No Download)
# Uses docker manifest inspect to get sizes
# Requires: docker login ghcr.io
# ===============================================

set -e

REGISTRY="ghcr.io"
IMAGE_NAME="juniyadi/php-base"

# Check authentication
check_auth() {
    # GHCR requires authentication even for public images
    # Try docker manifest inspect first (uses cached credentials)
    if docker manifest inspect "${REGISTRY}/${IMAGE_NAME}:8.5-alpine-amd64" >/dev/null 2>&1; then
        return 0
    fi

    # If no cached credentials, try to login with token if available
    if [ -n "$GHCR_TOKEN" ]; then
        echo "Using GHCR_TOKEN for authentication..."
        echo "$GHCR_TOKEN" | docker login "${REGISTRY}" -u "$GITHUB_USER" --password-stdin
        return 0
    fi

    # Check for GitHub token in standard locations
    if [ -n "$GITHUB_TOKEN" ]; then
        echo "Using GITHUB_TOKEN for authentication..."
        echo "$GITHUB_TOKEN" | docker login "${REGISTRY}" -u "$GITHUB_ACTOR" --password-stdin
        return 0
    fi

    echo "Error: Not authenticated to ${REGISTRY}"
    echo ""
    echo "GHCR requires authentication even for public images."
    echo ""
    echo "Options to authenticate:"
    echo "  1. Run: docker login ${REGISTRY}"
    echo "  2. Set GHCR_TOKEN environment variable (PAT with read:packages)"
    echo "  3. In CI: Use actions/docker/login-action@v3"
    echo ""
    echo "For GitHub Actions, add this step before running the script:"
    echo "  - name: Login to GHCR"
    echo "    uses: docker/login-action@v3"
    echo "    with:"
    echo "      registry: ${REGISTRY}"
    echo "      username: \${{ github.actor }}"
    echo "      password: \${{ secrets.GITHUB_TOKEN }}"
    exit 1
}

# Define all image variants
declare -a IMAGES=(
    "8.2-alpine-amd64"
    "8.2-alpine-arm64"
    "8.3-alpine-amd64"
    "8.3-alpine-arm64"
    "8.4-alpine-amd64"
    "8.4-alpine-arm64"
    "8.4-debian-amd64"
    "8.4-debian-arm64"
    "8.5-alpine-amd64"
    "8.5-alpine-arm64"
    "8.5-debian-amd64"
    "8.5-debian-arm64"
)

# Multi-arch manifest tags
declare -a MANIFESTS=(
    "8.2-alpine"
    "8.3-alpine"
    "8.4-alpine"
    "8.4-debian"
    "8.5-alpine"
    "8.5-debian"
    "8.5"
    "latest"
)

echo "========================================"
echo "Docker Image Sizes (via manifest inspect)"
echo "Registry: ${REGISTRY}/${IMAGE_NAME}"
echo "========================================"
echo ""

# Check authentication first
check_auth
echo "Authentication verified. Checking image sizes..."
echo ""

# Function to get image size
get_size() {
    local tag="$1"
    local full_image="${REGISTRY}/${IMAGE_NAME}:${tag}"

    # Get manifest as JSON
    local manifest
    manifest=$(docker manifest inspect "$full_image" 2>/dev/null)

    if [ -z "$manifest" ]; then
        echo "N/A"
        return 1
    fi

    # Sum all layer sizes
    local total_size
    total_size=$(echo "$manifest" | jq -r '.layers[]? | .size' 2>/dev/null | awk '{s+=$1} END {print s}')

    if [ -z "$total_size" ] || [ "$total_size" = "0" ]; then
        # Try alternative manifest format (index with child manifests)
        total_size=$(echo "$manifest" | jq -r '.manifests[]? | .size' 2>/dev/null | awk '{s+=$1} END {print s}')
    fi

    if [ -n "$total_size" ] && [ "$total_size" != "0" ]; then
        echo "$total_size"
    else
        echo "N/A"
    fi
}

# Function to format size
format_size() {
    local size_bytes="$1"
    if [ -z "$size_bytes" ] || [ "$size_bytes" = "N/A" ]; then
        echo "N/A"
    elif [ "$size_bytes" -gt 1073741824 ]; then
        echo "$(echo "scale=2; $size_bytes/1073741824" | bc) GB"
    elif [ "$size_bytes" -gt 1048576 ]; then
        echo "$(echo "scale=2; $size_bytes/1048576" | bc) MB"
    elif [ "$size_bytes" -gt 1024 ]; then
        echo "$(echo "scale=2; $size_bytes/1024" | bc) KB"
    else
        echo "${size_bytes} B"
    fi
}

# Print table header
printf "| %-8s | %-8s | %-8s | %-12s | %-20s |\n" "Version" "Base" "Arch" "Size" "Full Tag"
printf "|%-10s|%-10s|%-10s|%-14s|%-22s|\n" "--------" "--------" "--------" "------------" "--------------------"

# Track stats
total_arch_images=0
total_manifests=0

# Check individual architecture images
for img in "${IMAGES[@]}"; do
    version=$(echo "$img" | cut -d'-' -f1)
    base=$(echo "$img" | cut -d'-' -f2)
    arch=$(echo "$img" | cut -d'-' -f3)

    size_bytes=$(get_size "$img")
    formatted=$(format_size "$size_bytes")
    full_tag="${REGISTRY}/${IMAGE_NAME}:${img}"

    if [ "$size_bytes" != "N/A" ]; then
        ((total_arch_images++))
    fi

    printf "| %-8s | %-8s | %-8s | %-12s | %-20s |\n" "$version" "$base" "$arch" "$formatted" "$full_tag"
done

echo ""
echo "========================================"
echo "Multi-Arch Manifests (Combined Size)"
echo "========================================"
echo ""
printf "| %-15s | %-15s | %-20s |\n" "Tag" "Size" "Full Tag"
printf "|%-17s|%-17s|%-22s|\n" "---------------" "---------------" "--------------------"

# Check multi-arch manifests
for manifest in "${MANIFESTS[@]}"; do
    size_bytes=$(get_size "$manifest")
    formatted=$(format_size "$size_bytes")
    full_tag="${REGISTRY}/${IMAGE_NAME}:${manifest}"

    if [ "$size_bytes" != "N/A" ]; then
        ((total_manifests++))
    fi

    printf "| %-15s | %-15s | %-20s |\n" "$manifest" "$formatted" "$full_tag"
done

echo ""
echo "========================================"
echo "Summary"
echo "========================================"
echo "Architecture-specific images checked: $total_arch_images"
echo "Multi-arch manifests checked: $total_manifests"
echo "========================================"
