#!/bin/bash

# Build script for Fuego Wallet with XFG STARK CLI integration
# This script builds both the wallet and the STARK CLI, then packages them together

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
STARK_CLI_DIR="$PROJECT_ROOT/xfgwin"
BUILD_DIR="$SCRIPT_DIR/build"
INSTALL_DIR="$SCRIPT_DIR/install"

print_info "Building Fuego Wallet with XFG STARK CLI integration"
print_info "Project root: $PROJECT_ROOT"
print_info "STARK CLI directory: $STARK_CLI_DIR"
print_info "Build directory: $BUILD_DIR"

# Check if STARK CLI source exists
if [ ! -d "$STARK_CLI_DIR" ]; then
    print_error "STARK CLI source not found at: $STARK_CLI_DIR"
    print_info "Please ensure the xfgwin directory exists in the project root"
    exit 1
fi

# Create build directory
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

# Step 1: Build STARK CLI
print_info "Step 1: Building XFG STARK CLI..."
cd "$STARK_CLI_DIR"

if command -v cargo &> /dev/null; then
    print_info "Building STARK CLI with cargo..."
    cargo build --bin xfg-stark-cli --release
    
    if [ $? -eq 0 ]; then
        print_success "STARK CLI built successfully"
        STARK_CLI_PATH="$STARK_CLI_DIR/target/release/xfg-stark-cli"
    else
        print_error "Failed to build STARK CLI"
        exit 1
    fi
else
    print_error "Cargo not found. Please install Rust and Cargo"
    exit 1
fi

# Step 2: Build Fuego Wallet
print_info "Step 2: Building Fuego Wallet..."
cd "$SCRIPT_DIR"

# Check if cmake is available
if ! command -v cmake &> /dev/null; then
    print_error "CMake not found. Please install CMake"
    exit 1
fi

# Configure and build wallet
print_info "Configuring wallet build..."
cmake -DCMAKE_BUILD_TYPE=Release ..

print_info "Building wallet..."
make -j$(nproc)

if [ $? -eq 0 ]; then
    print_success "Fuego Wallet built successfully"
else
    print_error "Failed to build Fuego Wallet"
    exit 1
fi

# Step 3: Copy STARK CLI and scripts to wallet directory
print_info "Step 3: Integrating STARK CLI with wallet..."

# Create scripts directory in build
mkdir -p "$BUILD_DIR/scripts"

# Copy STARK CLI
if [ -f "$STARK_CLI_PATH" ]; then
    cp "$STARK_CLI_PATH" "$BUILD_DIR/"
    chmod +x "$BUILD_DIR/xfg-stark-cli"
    print_success "STARK CLI copied to build directory"
else
    print_error "STARK CLI binary not found at: $STARK_CLI_PATH"
    exit 1
fi

# Copy scripts
if [ -f "$SCRIPT_DIR/scripts/auto_stark_proof.sh" ]; then
    cp "$SCRIPT_DIR/scripts/auto_stark_proof.sh" "$BUILD_DIR/"
    chmod +x "$BUILD_DIR/auto_stark_proof.sh"
    print_success "Auto STARK proof script copied"
fi

if [ -f "$SCRIPT_DIR/scripts/stark_proof_generator.py" ]; then
    cp "$SCRIPT_DIR/scripts/stark_proof_generator.py" "$BUILD_DIR/"
    chmod +x "$BUILD_DIR/stark_proof_generator.py"
    print_success "STARK proof generator script copied"
fi

if [ -f "$SCRIPT_DIR/scripts/progress_logger.py" ]; then
    cp "$SCRIPT_DIR/scripts/progress_logger.py" "$BUILD_DIR/"
    chmod +x "$BUILD_DIR/progress_logger.py"
    print_success "Progress logger script copied"
fi

# Step 4: Test integration
print_info "Step 4: Testing STARK CLI integration..."

# Test if STARK CLI is accessible
if [ -f "$BUILD_DIR/xfg-stark-cli" ]; then
    print_info "Testing STARK CLI..."
    "$BUILD_DIR/xfg-stark-cli" --help > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        print_success "STARK CLI is working correctly"
    else
        print_warning "STARK CLI test failed, but continuing..."
    fi
else
    print_error "STARK CLI not found in build directory"
    exit 1
fi

# Step 5: Create installation package
print_info "Step 5: Creating installation package..."

# Create install directory
mkdir -p "$INSTALL_DIR"

# Copy wallet binary
if [ -f "$BUILD_DIR/fuegowallet" ]; then
    cp "$BUILD_DIR/fuegowallet" "$INSTALL_DIR/"
    print_success "Wallet binary copied to install directory"
fi

# Copy STARK CLI and scripts
cp "$BUILD_DIR/xfg-stark-cli" "$INSTALL_DIR/"
cp "$BUILD_DIR/auto_stark_proof.sh" "$INSTALL_DIR/"
cp "$BUILD_DIR/stark_proof_generator.py" "$INSTALL_DIR/"
cp "$BUILD_DIR/progress_logger.py" "$INSTALL_DIR/"

# Make scripts executable
chmod +x "$INSTALL_DIR"/*.sh
chmod +x "$INSTALL_DIR"/*.py

print_success "Installation package created in: $INSTALL_DIR"

# Step 6: Create distribution package
print_info "Step 6: Creating distribution package..."

DIST_DIR="$SCRIPT_DIR/dist"
mkdir -p "$DIST_DIR"

# Create tar.gz package
PACKAGE_NAME="fuego-wallet-with-stark-$(date +%Y%m%d)"
tar -czf "$DIST_DIR/$PACKAGE_NAME.tar.gz" -C "$INSTALL_DIR" .

print_success "Distribution package created: $DIST_DIR/$PACKAGE_NAME.tar.gz"

# Step 7: Summary
print_info "Build Summary:"
echo "=================="
echo "✅ STARK CLI built and integrated"
echo "✅ Fuego Wallet built successfully"
echo "✅ Scripts copied and made executable"
echo "✅ Installation package created: $INSTALL_DIR"
echo "✅ Distribution package created: $DIST_DIR/$PACKAGE_NAME.tar.gz"
echo ""
echo "To install:"
echo "  tar -xzf $DIST_DIR/$PACKAGE_NAME.tar.gz"
echo "  ./fuegowallet"
echo ""
echo "To test STARK integration:"
echo "  ./auto_stark_proof.sh <tx_hash> <recipient> <amount>"

print_success "🎉 Fuego Wallet with XFG STARK CLI integration completed successfully!"
