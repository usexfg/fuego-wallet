#!/bin/bash

# Fuego Wallet Release Script
# This script helps create releases for all operating systems

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "CMakeLists.txt" ] || [ ! -f "Fuego-GUI.pro" ]; then
    print_error "This script must be run from the fuego-wallet root directory"
    exit 1
fi

# Get version from CryptoNoteWallet.cmake
VERSION=$(grep "set(CN_VERSION" CryptoNoteWallet.cmake | sed 's/set(CN_VERSION //' | sed 's/)//')
print_status "Building Fuego Wallet version: $VERSION"

# Create release directory
RELEASE_DIR="releases/v$VERSION"
mkdir -p "$RELEASE_DIR"

print_status "Release directory created: $RELEASE_DIR"

# Function to build for Linux
build_linux() {
    print_status "Building for Linux..."
    
    # Clean previous builds
    make clean
    
    # Build release
    make -j$(nproc) build-release
    
    # Create release package
    RELEASE_NAME="fuego-desktop-ubuntu-22.04-v$VERSION"
    mkdir -p "$RELEASE_DIR/$RELEASE_NAME/icon"
    
    # Copy files
    cp build/release/Fuego-Wallet "$RELEASE_DIR/$RELEASE_NAME/"
    cp fuego-desktop.desktop "$RELEASE_DIR/$RELEASE_NAME/"
    cp src/images/fuego.png "$RELEASE_DIR/$RELEASE_NAME/icon/"
    
    # Create archive
    cd "$RELEASE_DIR"
    tar -czf "$RELEASE_NAME.tar.gz" "$RELEASE_NAME"
    cd - > /dev/null
    
    print_status "Linux build completed: $RELEASE_DIR/$RELEASE_NAME.tar.gz"
}

# Function to build for macOS
build_macos() {
    print_status "Building for macOS..."
    
    # Check if we're on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        print_warning "macOS build can only be done on macOS. Skipping..."
        return
    fi
    
    # Clean previous builds
    make clean
    
    # Build using qmake
    qmake Fuego-GUI.pro
    make -j$(sysctl -n hw.ncpu)
    
    # Create release package
    RELEASE_NAME="fuego-desktop-macOS-v$VERSION"
    mkdir -p "$RELEASE_DIR/$RELEASE_NAME"
    
    # Copy files
    cp -r Fuego-Wallet.app "$RELEASE_DIR/$RELEASE_NAME/"
    
    # Create archive
    cd "$RELEASE_DIR"
    tar -czf "$RELEASE_NAME.tar.gz" "$RELEASE_NAME"
    cd - > /dev/null
    
    print_status "macOS build completed: $RELEASE_DIR/$RELEASE_NAME.tar.gz"
}

# Function to build for Windows
build_windows() {
    print_status "Building for Windows..."
    
    # Check if we're on Windows or have cross-compilation tools
    if [[ "$OSTYPE" != "msys"* ]] && [[ "$OSTYPE" != "cygwin"* ]]; then
        print_warning "Windows build requires Windows environment or cross-compilation tools. Skipping..."
        return
    fi
    
    # Clean previous builds
    make clean
    
    # Build using qmake
    qmake Fuego-GUI.pro "CONFIG+=release"
    nmake -f Makefile.Release
    
    # Create release package
    RELEASE_NAME="fuego-desktop-windows-v$VERSION"
    mkdir -p "$RELEASE_DIR/$RELEASE_NAME"
    
    # Copy files
    cp release/Fuego-Wallet.exe "$RELEASE_DIR/$RELEASE_NAME/"
    
    # Create archive
    cd "$RELEASE_DIR"
    powershell Compress-Archive -Path "$RELEASE_NAME" -DestinationPath "$RELEASE_NAME.zip"
    cd - > /dev/null
    
    print_status "Windows build completed: $RELEASE_DIR/$RELEASE_NAME.zip"
}

# Main build process
print_status "Starting build process for Fuego Wallet v$VERSION"

# Build for current platform
case "$OSTYPE" in
    linux*)
        build_linux
        ;;
    darwin*)
        build_macos
        ;;
    msys*|cygwin*)
        build_windows
        ;;
    *)
        print_warning "Unknown OS type: $OSTYPE. Attempting Linux build..."
        build_linux
        ;;
esac

print_status "Build process completed!"
print_status "Release files are available in: $RELEASE_DIR"

# List created files
if [ -d "$RELEASE_DIR" ]; then
    print_status "Created release files:"
    ls -la "$RELEASE_DIR"
fi