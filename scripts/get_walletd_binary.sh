#!/bin/bash
# Script to build or download fuego-walletd binary from fuego-suite HEAT branch
# Can be called from CI workflows or manually

set -e

MODE="${1:-build}"  # Default to building from source, can be "download" for pre-built
REPO="usexfg/fuego-suite"
BRANCH="HEAT"

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

if [ "$MODE" = "download" ]; then
    echo "Downloading pre-built binary..."
    # Download to assets/bin directory
    mkdir -p assets/bin
    if [ -n "$DOWNLOAD_URL" ]; then
        curl -L -o "assets/bin/$BINARY_NAME" "$DOWNLOAD_URL"

        # Make executable on non-Windows platforms
        if [ "$PLATFORM" != "windows" ]; then
            chmod +x "assets/bin/$BINARY_NAME"
        fi

        echo "Downloaded: assets/bin/$BINARY_NAME"
        ls -lh "assets/bin/$BINARY_NAME"
    else
        echo "Warning: No pre-built release found, falling back to build from source"
        MODE="build"
    fi
fi

if [ "$MODE" = "build" ]; then
    echo "Building from source ($BRANCH branch)..."

    # Install dependencies based on platform
    case "$PLATFORM" in
        linux-*)
            echo "Installing Linux dependencies..."
            sudo apt-get update
            sudo apt-get install -y build-essential cmake pkg-config libboost-all-dev libssl-dev libzmq3-dev
            ;;
        macos-*)
            echo "Installing macOS dependencies..."
            brew install cmake pkg-config boost openssl zeromq jsoncpp
            ;;
        windows)
            echo "Windows build requires vcpkg and Visual Studio Build Tools"
            echo "For local builds, use: git clone -b $BRANCH https://github.com/$REPO.git fuego-source"
            exit 1
            ;;
    esac

    # Clone and build
    git clone -b "$BRANCH" "https://github.com/$REPO.git" fuego-source
    cd fuego-source
    mkdir build && cd build
    cmake .. -DBUILD_TESTS=OFF -DJSONCPP_INCLUDE_DIR=/usr/include -DCMAKE_CXX_FLAGS="-I/usr/include"
    make -j$(nproc) PaymentGateService

    # Copy binary and rename to fuego-walletd for the wallet app
    cd ../..
    mkdir -p assets/bin
    if [ "$PLATFORM" = "windows" ]; then
        copy "fuego-source/build/src/walletd/walletd.exe" "assets/bin/fuego-walletd-$PLATFORM.exe"
    else
        cp "fuego-source/build/src/walletd/walletd" "assets/bin/fuego-walletd-$PLATFORM"
        chmod +x "assets/bin/fuego-walletd-$PLATFORM"
    fi

    # Cleanup
    rm -rf fuego-source

    echo "Built: assets/bin/fuego-walletd-$PLATFORM"
    ls -lh "assets/bin/fuego-walletd-$PLATFORM"*
fi

echo ""
echo "Mode: $MODE"
echo "Repository: $REPO ($BRANCH branch)"
echo "Platform: $PLATFORM"
