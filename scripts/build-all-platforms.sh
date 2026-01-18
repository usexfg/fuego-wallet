#!/bin/bash
# Build all platform binaries for Fuego Wallet
# This script builds walletd binaries for all supported platforms

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "🔧 Building all platform binaries for Fuego Wallet"
echo "=================================================="
echo "Project root: $PROJECT_ROOT"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Detect platform
detect_platform() {
    case "$(uname -s)" in
        Linux*)
            echo "linux"
            ;;
        Darwin*)
            echo "macos"
            ;;
        MINGW*|MSYS*|CYGWIN*)
            echo "windows"
            ;;
        *)
            echo "unsupported"
            ;;
    esac
}

CURRENT_PLATFORM=$(detect_platform)
print_info "Detected current platform: $CURRENT_PLATFORM"

# Create assets/bin directory
mkdir -p "$PROJECT_ROOT/assets/bin"
print_info "Created assets/bin directory"

# Build for Linux (if on Linux)
build_linux() {
    if [ "$CURRENT_PLATFORM" = "linux" ]; then
        print_info "Building Linux walletd binary..."

        # Check if binary already exists
        if [ -f "$PROJECT_ROOT/assets/bin/fuego-walletd-linux" ]; then
            print_success "Linux walletd binary already exists"
            return 0
        fi

        # Clone and build fuego
        local build_dir="$PROJECT_ROOT/fuego-source-build-linux"
        print_info "Cloning fuego-suite (HEAT branch)..."
        rm -rf "$build_dir"
        git clone -b HEAT "https://github.com/usexfg/fuego-suite.git" "$build_dir"

        # Fix json include path
        print_info "Patching ProofStructures.h for JSON includes..."
        cd "$build_dir"
        if [ -f "src/CryptoNoteCore/ProofStructures.h" ]; then
            sed -i.bak "s/#include <json/json.h>/#include <jsoncpp/json.h>/g" src/CryptoNoteCore/ProofStructures.h
        fi

        # Install dependencies
        print_info "Installing build dependencies..."
        sudo apt-get update
        sudo apt-get install -y build-essential cmake libboost-all-dev libssl-dev libzmq3-dev libjsoncpp-dev

        # Build
        print_info "Building walletd..."
        cd "$build_dir"
        mkdir -p build
        cd build
        cmake .. -DBUILD_TESTS=OFF
        make -j$(nproc) PaymentGateService

        # Copy binary
        local binary_path=$(find . -name "walletd" -type f -executable | head -n1)
        if [ -n "$binary_path" ]; then
            cp "$binary_path" "$PROJECT_ROOT/assets/bin/fuego-walletd-linux"
            chmod +x "$PROJECT_ROOT/assets/bin/fuego-walletd-linux"
            print_success "Linux walletd binary created: $PROJECT_ROOT/assets/bin/fuego-walletd-linux"
        else
            print_error "Failed to find walletd binary"
            return 1
        fi

        # Cleanup
        rm -rf "$build_dir"
    else
        print_warning "Skipping Linux build (not on Linux platform)"
    fi
}

# Build for macOS (if on macOS)
build_macos() {
    if [ "$CURRENT_PLATFORM" = "macos" ]; then
        print_info "Building macOS walletd binary..."

        # Check if binary already exists
        if [ -f "$PROJECT_ROOT/assets/bin/fuego-walletd-macos" ]; then
            print_success "macOS walletd binary already exists"
            return 0
        fi

        # Clone and build fuego
        local build_dir="$PROJECT_ROOT/fuego-source-build-macos"
        print_info "Cloning fuego-suite (HEAT branch)..."
        rm -rf "$build_dir"
        git clone -b HEAT "https://github.com/usexfg/fuego-suite.git" "$build_dir"

        # Install dependencies
        print_info "Installing build dependencies..."
        brew install cmake pkg-config zeromq jsoncpp openssl boost

        # Build
        print_info "Building walletd..."
        cd "$build_dir"
        mkdir -p build
        cd build
        cmake .. -DBUILD_TESTS=OFF
        make -j$(sysctl -n hw.ncpu) PaymentGateService

        # Copy binary
        local binary_path=$(find . -name "walletd" -type f -executable | head -n1)
        if [ -n "$binary_path" ]; then
            cp "$binary_path" "$PROJECT_ROOT/assets/bin/fuego-walletd-macos"
            chmod +x "$PROJECT_ROOT/assets/bin/fuego-walletd-macos"
            print_success "macOS walletd binary created: $PROJECT_ROOT/assets/bin/fuego-walletd-macos"
        else
            print_error "Failed to find walletd binary"
            return 1
        fi

        # Cleanup
        rm -rf "$build_dir"
    else
        print_warning "Skipping macOS build (not on macOS platform)"
    fi
}

# Download STARK CLI binaries for all platforms
download_stark_cli() {
    print_info "Downloading STARK CLI binaries..."

    # Linux
    if [ ! -f "$PROJECT_ROOT/assets/bin/xfg-stark-cli-linux" ]; then
        print_info "Downloading xfg-stark-cli-linux..."
        curl -L -o "$PROJECT_ROOT/assets/bin/xfg-stark-cli-linux" "https://github.com/ColinRitman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-linux"
        chmod +x "$PROJECT_ROOT/assets/bin/xfg-stark-cli-linux"
        print_success "xfg-stark-cli-linux downloaded"
    else
        print_success "xfg-stark-cli-linux already exists"
    fi

    # macOS
    if [ ! -f "$PROJECT_ROOT/assets/bin/xfg-stark-cli-macos" ]; then
        print_info "Downloading xfg-stark-cli-macos..."
        curl -L -o "$PROJECT_ROOT/assets/bin/xfg-stark-cli-macos" "https://github.com/ColinRitman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-macos"
        chmod +x "$PROJECT_ROOT/assets/bin/xfg-stark-cli-macos"
        print_success "xfg-stark-cli-macos downloaded"
    else
        print_success "xfg-stark-cli-macos already exists"
    fi

    # Windows
    if [ ! -f "$PROJECT_ROOT/assets/bin/xfg-stark-cli-windows.exe" ]; then
        print_info "Downloading xfg-stark-cli-windows.exe..."
        curl -L -o "$PROJECT_ROOT/assets/bin/xfg-stark-cli-windows.exe" "https://github.com/ColinRitman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-windows.exe"
        print_success "xfg-stark-cli-windows.exe downloaded"
    else
        print_success "xfg-stark-cli-windows.exe already exists"
    fi
}

# Verify all binaries
verify_binaries() {
    print_info "Verifying all binaries..."

    required_binaries=(
        "assets/bin/fuego-walletd-linux"
        "assets/bin/fuego-walletd-macos"
        "assets/bin/fuego-walletd-windows.exe"
        "assets/bin/xfg-stark-cli-linux"
        "assets/bin/xfg-stark-cli-macos"
        "assets/bin/xfg-stark-cli-windows.exe"
    )

    all_present=true
    for binary in "${required_binaries[@]}"; do
        if [ -f "$PROJECT_ROOT/$binary" ]; then
            if [[ "$binary" != *.exe ]] && [ ! -x "$PROJECT_ROOT/$binary" ]; then
                chmod +x "$PROJECT_ROOT/$binary"
            fi
            print_success "✅ $binary is present"
        else
            print_warning "⚠️  $binary is missing"
            # Don't fail for now, as some binaries might be built in CI
        fi
    done

    print_success "Binary verification completed"
}

# Main execution
main() {
    print_info "Starting build process for all platforms..."

    # Download STARK CLI binaries
    download_stark_cli

    # Build platform-specific binaries
    build_linux
    build_macos

    # Verify all binaries
    verify_binaries

    print_success "✅ All platform binaries processed!"
    echo ""
    echo "Next steps:"
    echo "- Commit the binaries to git if needed"
    echo "- Test the build with 'flutter build'"
    echo "- Run the app with 'flutter run'"
}

# Run main
main "$@"
