#!/bin/bash
# Script to download fuego-walletd binary from releases
# Can be called from CI workflows or manually

set -e

VERSION="${1:-latest}"  # Default to latest version
REPO="usexfg/fuego"
ASSET_PREFIX="fuego-walletd"

# Determine platform-specific binary name and architecture
detect_platform() {
    case "$(uname -s)" in
        Linux*)
            ARCH=$(uname -m)
            if [ "$ARCH" = "x86_64" ]; then
                ARCH="x86_64"
            elif [ "$ARCH" = "aarch64" ]; then
                ARCH="arm64"
            fi
            echo "linux-$ARCH"
            ;;
        Darwin*)
            ARCH=$(uname -m)
            if [ "$ARCH" = "arm64" ]; then
                echo "macos-arm64"
            else
                echo "macos-x86_64"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "windows"
            ;;
        *)
            echo "unsupported"
            ;;
    esac
}

PLATFORM=$(detect_platform)

if [ "$PLATFORM" = "unsupported" ]; then
    echo "Unsupported platform"
    exit 1
fi

# Determine binary name
if [ "$PLATFORM" = "windows" ]; then
    BINARY_NAME="fuego-walletd-windows.exe"
    RELEASE_ASSET="${ASSET_PREFIX}-windows.exe"
else
    BINARY_NAME="fuego-walletd-$PLATFORM"
    RELEASE_ASSET="${ASSET_PREFIX}-${PLATFORM}"
fi

echo "Platform: $PLATFORM"
echo "Binary: $BINARY_NAME"
echo "Release Asset: $RELEASE_ASSET"

# Download using GitHub API
if [ "$VERSION" = "latest" ]; then
    echo "Downloading latest release..."
    DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | \
        grep "browser_download_url.*$RELEASE_ASSET" | \
        head -n 1 | \
        cut -d '"' -f 4)
else
    echo "Downloading version $VERSION..."
    DOWNLOAD_URL=$(curl -s "https://api.github.com/repos/$REPO/releases/tags/v$VERSION" | \
        grep "browser_download_url.*$RELEASE_ASSET" | \
        head -n 1 | \
        cut -d '"' -f 4)
fi

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Failed to find release asset: $RELEASE_ASSET"
    exit 1
fi

echo "Download URL: $DOWNLOAD_URL"

# Download to assets/bin directory
mkdir -p assets/bin
curl -L -o "assets/bin/$BINARY_NAME" "$DOWNLOAD_URL"

# Make executable on non-Windows platforms
if [ "$PLATFORM" != "windows" ]; then
    chmod +x "assets/bin/$BINARY_NAME"
fi

echo "Downloaded: assets/bin/$BINARY_NAME"
ls -lh "assets/bin/$BINARY_NAME"

