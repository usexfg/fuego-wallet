#!/bin/bash
# Build fuego-walletd from source using HEAT branch of fuego-suite
# Optimized for CI environments

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BRANCH="${1:-HEAT}"
REPO="usexfg/fuego-suite"

echo "🔧 Building fuego-walletd from source"
echo "====================================="
echo "Branch: $BRANCH"
echo "Repo: $REPO"
echo "Project root: $PROJECT_ROOT"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
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

PLATFORM=$(detect_platform)
print_info "Detected platform: $PLATFORM"

# Install dependencies based on platform
install_dependencies() {
    print_info "Installing build dependencies..."

    case "$PLATFORM" in
        linux)
            if command -v apt-get &> /dev/null; then
                print_info "Using apt-get..."
                sudo apt-get update
                sudo apt-get install -y \
                    build-essential \
                    cmake \
                    pkg-config \
                    libboost-all-dev \
                    libssl-dev \
                    libzmq3-dev
            elif command -v yum &> /dev/null; then
                print_info "Using yum..."
                sudo yum groupinstall -y "Development Tools"
                sudo yum install -y \
                    cmake \
                    boost-devel \
                    openssl-devel \
                    zeromq-devel
            elif command -v dnf &> /dev/null; then
                print_info "Using dnf..."
                sudo dnf groupinstall -y "Development Tools"
                sudo dnf install -y \
                    cmake \
                    boost-devel \
                    openssl-devel \
                    zeromq-devel
            else
                print_warning "Package manager not detected, skipping dependency installation"
            fi
            ;;
        macos)
            if command -v brew &> /dev/null; then
                print_info "Using Homebrew..."
                brew install cmake pkg-config boost openssl zeromq
            else
                print_warning "Homebrew not found, please install dependencies manually"
            fi
            ;;
        windows)
            print_warning "Windows build requires manual dependency setup"
            print_info "Expected: vcpkg, Visual Studio Build Tools, CMake"
            return 1
            ;;
    esac

    print_success "Dependencies installed"
}

# Clone and build fuego
build_fuego() {
    local build_dir="$PROJECT_ROOT/fuego-source-build"

    print_info "Cloning fuego-suite ($BRANCH branch)..."
    rm -rf "$build_dir"
    git clone -b "$BRANCH" "https://github.com/$REPO.git" "$build_dir"

    # Fix json include path for HEAT branch
    print_info "Patching ProofStructures.h for JSON includes..."
    cd "$build_dir"
    if [ -f "src/CryptoNoteCore/ProofStructures.h" ]; then
        sed -i .bak "s/#include <json/json.h>/#include <jsoncpp/json.h>/g" src/CryptoNoteCore/ProofStructures.h
        print_success "Patched ProofStructures.h"
    fi

    print_info "Configuring build..."
    cd "$build_dir"
    mkdir -p build
    cd build

    # Configure CMake
    print_info "Running CMake..."
    cmake .. \
        -DBUILD_TESTS=OFF \
        -DJSONCPP_INCLUDE_DIR=/usr/include \
        -DCMAKE_CXX_FLAGS="-I/usr/include"

    print_info "Building PaymentGateService (walletd)..."
    make -j$(nproc) PaymentGateService

    print_success "Build completed"

    # Output binary path
    local binary_path="$build_dir/build/src/walletd/walletd"
    echo "$binary_path"
}

# Copy binary to assets
copy_binary() {
    local binary_path="$1"
    local target_dir="$PROJECT_ROOT/assets/bin"

    print_info "Copying binary to $target_dir..."
    mkdir -p "$target_dir"

    if [ "$PLATFORM" = "windows" ]; then
        local target_name="fuego-walletd-windows.exe"
        cp "$binary_path.exe" "$target_dir/$target_name"
        print_success "Copied: $target_dir/$target_name"
    else
        local target_name="fuego-walletd-$PLATFORM"
        cp "$binary_path" "$target_dir/$target_name"
        chmod +x "$target_dir/$target_name"
        print_success "Copied: $target_dir/$target_name"
    fi
}

# Cleanup
cleanup() {
    local build_dir="$PROJECT_ROOT/fuego-source-build"
    if [ -d "$build_dir" ]; then
        print_info "Cleaning up build directory..."
        rm -rf "$build_dir"
        print_success "Cleanup completed"
    fi
}

# Main execution
main() {
    print_info "Starting build process..."

    # Install dependencies
    install_dependencies

    # Build fuego
    binary_path=$(build_fuego)

    # Copy binary
    copy_binary "$binary_path"

    # Cleanup (optional, can be commented out for debugging)
    # cleanup

    print_success "✅ fuego-walletd build completed successfully!"
    echo ""
    echo "Binary location: $PROJECT_ROOT/assets/bin/fuego-walletd-$PLATFORM"

    # Verify
    if [ "$PLATFORM" != "windows" ]; then
        ls -lh "$PROJECT_ROOT/assets/bin/fuego-walletd-$PLATFORM"
    else
        ls -lh "$PROJECT_ROOT/assets/bin/fuego-walletd-windows.exe"
    fi
}

# Run main
main "$@"
