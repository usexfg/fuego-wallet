#!/bin/bash
# Script to build or download fuego-walletd binary from fuego-suite HEAT branch
# Modified to use ARM64 and Boost 1.85

set -e

MODE="${1:-build}"  # Default to building from source, can be "download" for pre-built
REPO="usexfg/fuego-suite"
BRANCH="HE4T"

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


if [ "$MODE" != "build" ] && [ "$MODE" = "download" ]; then
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
    echo "Building from source ($BRANCH branch) with ARM64 and Boost 1.85..."

    # Install dependencies based on platform
    case "$PLATFORM" in
        linux-*)
            echo "Installing Linux dependencies..."
            sudo apt-get update
            sudo apt-get install -y build-essential cmake pkg-config libboost-all-dev libssl-dev libzmq3-dev
            ;;
        macos-*)
            echo "Installing macOS dependencies..."
            # Check if boost@1.85 is installed
            if brew list | grep -q "boost@1.85"; then
                echo "Using Boost 1.85 from Homebrew"
            else
                echo "Installing Boost 1.85 via Homebrew..."
                brew install boost@1.85
            fi
            brew install cmake pkg-config openssl@3 zeromq jsoncpp icu4c@78
            ;;
        windows)
            echo "Windows build requires vcpkg and Visual Studio Build Tools"
            echo "For local builds, use: git clone -b $BRANCH https://github.com/$REPO.git fuego-source"
            exit 1
            ;;
    esac

    # Clone and build
    rm -rf fuego-source
    git clone -b "$BRANCH" "https://github.com/$REPO.git" fuego-source
    cd fuego-source

    # Remove x86-specific compiler flags for ARM64 compatibility
    if [[ "$PLATFORM" == *"arm64"* ]]; then
        echo "Removing x86-specific compiler flags for ARM64..."
        sed -i .bak "s/-maes//g; s/-msse2//g; s/-msse4.1//g; s/-msse4.2//g" CMakeLists.txt
    fi

    # Fix json include path for HEAT branch
    if [ -f "src/CryptoNoteCore/ProofStructures.h" ]; then
        sed -i .bak "s/#include <json/json.h>/#include <jsoncpp/json.h>/g" src/CryptoNoteCore/ProofStructures.h
    fi

    mkdir build && cd build

    # Configure CMake with ARM64 and Boost 1.85 settings
    if [[ "$PLATFORM" == *"arm64"* ]]; then
        echo "Configuring for ARM64 with Boost 1.85..."
        if [[ "$PLATFORM" == "macos-arm64" ]]; then
            # macOS ARM64 specific settings
            export BOOST_ROOT="/opt/homebrew/opt/boost@1.85"
            export BOOST_INCLUDEDIR="/opt/homebrew/opt/boost@1.85/include"
            export BOOST_LIBRARYDIR="/opt/homebrew/opt/boost@1.85/lib"
            export CMAKE_PREFIX_PATH="/opt/homebrew/opt/boost@1.85:/opt/homebrew/opt/icu4c@78:/opt/homebrew/opt/openssl@3"

            cmake .. \
                -DBUILD_TESTS=OFF \
                -DCMAKE_OSX_ARCHITECTURES=arm64 \
                -DCMAKE_CXX_FLAGS="-DCRYPTOPP_DISABLE_ASM -I/opt/homebrew/opt/boost@1.85/include -I/opt/homebrew/opt/jsoncpp/include -I/opt/homebrew/opt/openssl@3/include -std=c++17" \
                -DCMAKE_BUILD_TYPE=Release \
                -DBoost_NO_BOOST_CMAKE=ON \
                -DBoost_NO_SYSTEM_PATHS=ON \
                -DBoost_INCLUDE_DIRS="/opt/homebrew/opt/boost@1.85/include" \
                -DBoost_LIBRARY_DIRS="/opt/homebrew/opt/boost@1.85/lib" \
                -DJSONCPP_INCLUDE_DIR="/opt/homebrew/opt/jsoncpp/include" \
                -DOPENSSL_ROOT_DIR="/opt/homebrew/opt/openssl@3" \
                -DICU_ROOT="/opt/homebrew/opt/icu4c@78"
        else
            # Linux ARM64 settings
            cmake .. \
                -DBUILD_TESTS=OFF \
                -DCMAKE_CXX_FLAGS="-DCRYPTOPP_DISABLE_ASM -std=c++17" \
                -DCMAKE_BUILD_TYPE=Release
        fi
    else
        # Default settings for other platforms
        cmake .. -DBUILD_TESTS=OFF -DCMAKE_OSX_ARCHITECTURES=arm64 -DCRYPTOPP_DISABLE_ASM=ON -DNO_AES=ON -DCMAKE_OSX_ARCHITECTURES=arm64 -DCMAKE_CXX_FLAGS="-DCRYPTOPP_DISABLE_ASM -I/usr/include -std=c++17"
    fi

    make -j$(sysctl -nc hw.ncpu) PaymentGateService

    # Copy binary and rename to fuego-walletd for the wallet app
    cd ../..
    mkdir -p assets/bin
    if [ "$PLATFORM" = "windows" ]; then
        cp "fuego-source/build/src/walletd/walletd.exe" "assets/bin/fuego-walletd-$PLATFORM.exe"
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
