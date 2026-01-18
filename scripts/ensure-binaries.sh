#!/bin/bash

# XF₲ Wallet Binary Download Script
# This script ensures all required binaries are downloaded before running tests or builds

set -e

echo "📦 Ensuring XF₲ Wallet binaries are available"
echo "============================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
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

# Create assets/bin directory if it doesn't exist
mkdir -p assets/bin

# Check if we're running in CI environment
if [ -n "$GITHUB_ACTIONS" ]; then
    print_status "Running in GitHub Actions environment"
    # In CI, we'll download specific binaries for the platform
    case "$RUNNER_OS" in
        macOS)
            print_status "Downloading macOS binaries..."
            # Download xfg-stark-cli for macOS
            if [ ! -f "assets/bin/xfg-stark-cli-macos" ]; then
                print_status "Downloading xfg-stark-cli-macos..."
                curl -L -o xfg-stark-cli-macos.tar.gz "https://github.com/ColinRitman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-macos.tar.gz"
                tar -xzf xfg-stark-cli-macos.tar.gz
                BINARY_PATH=$(find . -type f -name "xfg-stark-cli*" -perm +111 | head -n1 || true)
                if [ -z "$BINARY_PATH" ]; then
                    BINARY_PATH=$(find . -type f -name "xfg-stark-cli*" | head -n1 || true)
                fi
                if [ -n "$BINARY_PATH" ]; then
                    chmod +x "$BINARY_PATH"
                    mv "$BINARY_PATH" assets/bin/xfg-stark-cli-macos
                    print_success "xfg-stark-cli-macos downloaded"
                else
                    print_error "xfg-stark-cli not found after extraction"
                fi
                rm -f xfg-stark-cli-macos.tar.gz
            else
                print_success "xfg-stark-cli-macos already exists"
            fi
            ;;
        Linux)
            print_status "Downloading Linux binaries..."
            # Download xfg-stark-cli for Linux
            if [ ! -f "assets/bin/xfg-stark-cli-linux" ]; then
                print_status "Downloading xfg-stark-cli-linux..."
                curl -L -o xfg-stark-cli-linux.tar.gz "https://github.com/ColinRitman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-linux.tar.gz"
                tar -xzf xfg-stark-cli-linux.tar.gz
                BINARY_PATH=$(find . -type f -name "xfg-stark-cli*" -perm -111 | head -n1 || true)
                if [ -z "$BINARY_PATH" ]; then
                    BINARY_PATH=$(find . -type f -name "xfg-stark-cli*" | head -n1 || true)
                fi
                if [ -n "$BINARY_PATH" ]; then
                    chmod +x "$BINARY_PATH"
                    mv "$BINARY_PATH" assets/bin/xfg-stark-cli-linux
                    print_success "xfg-stark-cli-linux downloaded"
                else
                    print_error "xfg-stark-cli not found after extraction"
                fi
                rm -f xfg-stark-cli-linux.tar.gz
            else
                print_success "xfg-stark-cli-linux already exists"
            fi
            ;;
        Windows)
            print_status "Downloading Windows binaries..."
            # Download xfg-stark-cli for Windows
            if [ ! -f "assets/bin/xfg-stark-cli-windows.exe" ]; then
                print_status "Downloading xfg-stark-cli-windows.exe..."
                curl -L -o xfg-stark-cli-windows.zip "https://github.com/ColinRitman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-windows.zip"
                unzip xfg-stark-cli-windows.zip
                BINARY_PATH=$(find . -type f -name "xfg-stark-cli*.exe" | head -n1 || true)
                if [ -n "$BINARY_PATH" ]; then
                    mv "$BINARY_PATH" assets/bin/xfg-stark-cli-windows.exe
                    print_success "xfg-stark-cli-windows.exe downloaded"
                else
                    print_error "xfg-stark-cli-windows.exe not found after extraction"
                fi
                rm -f xfg-stark-cli-windows.zip
            else
                print_success "xfg-stark-cli-windows.exe already exists"
            fi
            ;;
    esac
else
    # Local development - download all binaries
    print_status "Downloading xfg-stark-cli binaries for all platforms..."

    # Linux binary
    if [ ! -f "assets/bin/xfg-stark-cli-linux" ]; then
        print_status "Downloading xfg-stark-cli-linux..."
        curl -L -o xfg-stark-cli-linux.tar.gz "https://github.com/ColinRitman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-linux.tar.gz"
        tar -xzf xfg-stark-cli-linux.tar.gz
        BINARY_PATH=$(find . -type f -name "xfg-stark-cli*" -perm -111 | head -n1 || true)
        if [ -z "$BINARY_PATH" ]; then
            BINARY_PATH=$(find . -type f -name "xfg-stark-cli*" | head -n1 || true)
        fi
        if [ -n "$BINARY_PATH" ]; then
            chmod +x "$BINARY_PATH"
            mv "$BINARY_PATH" assets/bin/xfg-stark-cli-linux
            print_success "xfg-stark-cli-linux downloaded"
        else
            print_error "xfg-stark-cli not found after extraction"
        fi
        rm -f xfg-stark-cli-linux.tar.gz
    else
        print_success "xfg-stark-cli-linux already exists"
    fi

    # macOS binary
    if [ ! -f "assets/bin/xfg-stark-cli-macos" ]; then
        print_status "Downloading xfg-stark-cli-macos..."
        curl -L -o xfg-stark-cli-macos.tar.gz "https://github.com/ColinRitman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-macos.tar.gz"
        tar -xzf xfg-stark-cli-macos.tar.gz
        BINARY_PATH=$(find . -type f -name "xfg-stark-cli*" -perm +111 | head -n1 || true)
        if [ -z "$BINARY_PATH" ]; then
            BINARY_PATH=$(find . -type f -name "xfg-stark-cli*" | head -n1 || true)
        fi
        if [ -n "$BINARY_PATH" ]; then
            chmod +x "$BINARY_PATH"
            mv "$BINARY_PATH" assets/bin/xfg-stark-cli-macos
            print_success "xfg-stark-cli-macos downloaded"
        else
            print_error "xfg-stark-cli not found after extraction"
        fi
        rm -f xfg-stark-cli-macos.tar.gz
    else
        print_success "xfg-stark-cli-macos already exists"
    fi

    # Windows binary
    if [ ! -f "assets/bin/xfg-stark-cli-windows.exe" ]; then
        print_status "Downloading xfg-stark-cli-windows.exe..."
        curl -L -o xfg-stark-cli-windows.zip "https://github.com/ColinRitman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-windows.zip"
        unzip xfg-stark-cli-windows.zip
        BINARY_PATH=$(find . -type f -name "xfg-stark-cli*.exe" | head -n1 || true)
        if [ -n "$BINARY_PATH" ]; then
            mv "$BINARY_PATH" assets/bin/xfg-stark-cli-windows.exe
            print_success "xfg-stark-cli-windows.exe downloaded"
        else
            print_error "xfg-stark-cli-windows.exe not found after extraction"
        fi
        rm -f xfg-stark-cli-windows.zip
    else
        print_success "xfg-stark-cli-windows.exe already exists"
    fi
fi

# Note: fuego-walletd is now built from source in CI/CD workflows
# See .github/workflows/ for fuego build process
print_status "Note: fuego-walletd built from source during CI/CD"

# Linux binary
if [ ! -f "assets/bin/xfg-stark-cli-linux" ]; then
    print_status "Downloading xfg-stark-cli-linux..."
    curl -L -o xfg-stark-cli-linux "https://github.com/ColinRitman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-linux"
    chmod +x xfg-stark-cli-linux
    mv xfg-stark-cli-linux assets/bin/
    print_success "xfg-stark-cli-linux downloaded"
else
    print_success "xfg-stark-cli-linux already exists"
fi

# macOS binary
if [ ! -f "assets/bin/xfg-stark-cli-macos" ]; then
    print_status "Downloading xfg-stark-cli-macos..."
    curl -L -o xfg-stark-cli-macos "https://github.com/ColinRitman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-macos"
    chmod +x xfg-stark-cli-macos
    mv xfg-stark-cli-macos assets/bin/
    print_success "xfg-stark-cli-macos downloaded"
else
    print_success "xfg-stark-cli-macos already exists"
fi

# Windows binary
if [ ! -f "assets/bin/xfg-stark-cli-windows.exe" ]; then
    print_status "Downloading xfg-stark-cli-windows.exe..."
    curl -L -o xfg-stark-cli-windows.exe "https://github.com/ColinRitman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-windows.exe"
    mv xfg-stark-cli-windows.exe assets/bin/
    print_success "xfg-stark-cli-windows.exe downloaded"
else
    print_success "xfg-stark-cli-windows.exe already exists"
fi

# Note: fuego-walletd is now built from source in CI/CD workflows
# See .github/workflows/ for fuego build process
print_status "Note: fuego-walletd built from source during CI/CD"


# Verify all binaries are present and executable
print_status "Verifying binaries..."

required_binaries=(
    "assets/bin/xfg-stark-cli-linux"
    "assets/bin/xfg-stark-cli-macos"
    "assets/bin/xfg-stark-cli-windows.exe"
    # Note: fuego-walletd built from source in CI/CD workflows
    # Check .github/workflows/ for fuego build process
)

print_status "fuego-walletd will be built from source during CI/CD"

all_present=true
for binary in "${required_binaries[@]}"; do
    if [ -f "$binary" ]; then
        if [[ "$binary" != *.exe ]] && [ ! -x "$binary" ]; then
            chmod +x "$binary"
        fi
        print_success "✅ $binary is present and ready"
    else
        print_error "❌ $binary is missing"
        all_present=false
    fi
done

if [ "$all_present" = true ]; then
    print_success "🎉 All required binaries are available!"
    echo ""
    echo "Binaries ready for:"
    echo "- Flutter tests"
    echo "- Cross-platform builds"
    echo "- CI/CD pipelines"
else
    print_error "❌ Some binaries are missing. Please check the download process."
    exit 1
fi

# Show binary sizes
echo ""
print_status "Binary information:"
for binary in "${required_binaries[@]}"; do
    if [ -f "$binary" ]; then
        size=$(du -h "$binary" 2>/dev/null | cut -f1)
        if [ -n "$size" ]; then
            echo "  $binary: $size"
        else
            echo "  $binary: present"
        fi
    fi
done

# Also check for fuego-walletd binaries that might have been built
echo ""
print_status "Checking for fuego-walletd binaries:"
fuego_binaries=(
    "assets/bin/fuego-walletd-macos"
    "assets/bin/fuego-walletd-macos-arm64"
    "assets/bin/fuego-walletd-macos-x86"
    "assets/bin/fuego-walletd-linux"
    "assets/bin/fuego-walletd-windows.exe"
)

for binary in "${fuego_binaries[@]}"; do
    if [ -f "$binary" ]; then
        size=$(du -h "$binary" 2>/dev/null | cut -f1)
        if [ -n "$size" ]; then
            print_success "✅ $binary: $size"
        else
            print_success "✅ $binary: present"
        fi
    fi
done
