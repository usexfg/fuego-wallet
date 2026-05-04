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

# Download xfg-stark-cli binaries for all platforms
print_status "Downloading xfg-stark-cli binaries..."

# Linux binary
if [ ! -f "assets/bin/xfg-stark-cli-linux" ]; then
    print_status "Downloading xfg-stark-cli-linux..."
    curl -L -o xfg-stark-cli-linux "https://github.com/usexfg/zk-fire/releases/download/v0.8.8/xfg-stark-cli-linux"
    chmod +x xfg-stark-cli-linux
    mv xfg-stark-cli-linux assets/bin/
    print_success "xfg-stark-cli-linux downloaded"
else
    print_success "xfg-stark-linux already exists"
fi

# macOS binary
if [ ! -f "assets/bin/xfg-stark-cli-macos" ]; then
    print_status "Downloading xfg-stark-cli-macos..."
    curl -L -o xfg-stark-cli-macos "https://github.com/usexfg/zk-fire/releases/download/v0.8.8/xfg-stark-cli-macos"
    chmod +x xfg-stark-cli-macos
    mv xfg-stark-cli-macos assets/bin/
    print_success "xfg-stark-cli-macos downloaded"
else
    print_success "xfg-stark-macos already exists"
fi

# Windows binary
if [ ! -f "assets/bin/xfg-stark-cli-windows.exe" ]; then
    print_status "Downloading xfg-stark-cli-windows.exe..."
    curl -L -o xfg-stark-cli-windows.exe "https://github.com/usexfg/zk-fire/releases/download/v0.8.8/xfg-stark-cli-windows.exe"
    mv xfg-stark-cli-windows.exe assets/bin/
    print_success "xfg-stark-cli-windows.exe downloaded"
else
    print_success "xfg-stark-windows.exe already exists"
fi

# Note: fuego-walletd is now built from source in CI/CD workflows
# See .github/workflows/ for fuego build process
print_status "Note: fuego-walletd built from source during CI/CD"


# Verify all binaries are present and executable
print_status "Verifying binaries..."

required_binaries=(
    "assets/bin/xfg-stark-linux"
    "assets/bin/xfg-stark-macos"
    "assets/bin/xfg-stark-windows.exe"
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
        size=$(du -h "$binary" | cut -f1)
        echo "  $binary: $size"
    fi
done

# Download fuego-prover binaries
print_status "Downloading fuego-prover binaries..."

if [ ! -f "assets/bin/fuego-prover-linux" ]; then
    print_status "Downloading fuego-prover-linux..."
    curl -L -o fuego-prover-linux "https://github.com/usexfg/zk-fire/releases/latest/download/fuego-prover-linux"
    chmod +x fuego-prover-linux
    mv fuego-prover-linux assets/bin/
    print_success "fuego-prover-linux downloaded"
else
    print_success "fuego-prover-linux already exists"
fi

if [ ! -f "assets/bin/fuego-prover-macos" ]; then
    print_status "Downloading fuego-prover-macos..."
    curl -L -o fuego-prover-macos "https://github.com/usexfg/zk-fire/releases/latest/download/fuego-prover-macos"
    chmod +x fuego-prover-macos
    mv fuego-prover-macos assets/bin/
    print_success "fuego-prover-macos downloaded"
else
    print_success "fuego-prover-macos already exists"
fi

if [ ! -f "assets/bin/fuego-prover-windows.exe" ]; then
    print_status "Downloading fuego-prover-windows.exe..."
    curl -L -o fuego-prover-windows.exe "https://github.com/usexfg/zk-fire/releases/latest/download/fuego-prover-windows.exe"
    mv fuego-prover-windows.exe assets/bin/
    print_success "fuego-prover-windows.exe downloaded"
else
    print_success "fuego-prover-windows.exe already exists"
fi
