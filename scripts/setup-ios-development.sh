#!/bin/bash

# XF₲ Wallet iOS Development Setup Script
# This script sets up the iOS development environment for the XF₲ Wallet

set -e

echo "🚀 Setting up XF₲ Wallet iOS Development Environment"
echo "=================================================="

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

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script must be run on macOS for iOS development"
    exit 1
fi

# Check macOS version
macos_version=$(sw_vers -productVersion)
print_status "macOS version: $macos_version"

if [[ $(echo "$macos_version" | cut -d. -f1) -lt 12 ]]; then
    print_error "macOS 12.0 or later is required for iOS development"
    exit 1
fi

# Check if Xcode is installed
print_status "Checking for Xcode installation..."
if ! command -v xcodebuild &> /dev/null; then
    print_error "Xcode is not installed. Please install Xcode from the App Store"
    exit 1
fi

xcode_version=$(xcodebuild -version | head -n1)
print_success "Found $xcode_version"

# Check if Xcode Command Line Tools are installed
print_status "Checking for Xcode Command Line Tools..."
if ! xcode-select -p &> /dev/null; then
    print_warning "Xcode Command Line Tools not found. Installing..."
    xcode-select --install
    print_warning "Please complete the Xcode Command Line Tools installation and run this script again"
    exit 1
fi

print_success "Xcode Command Line Tools are installed"

# Check if Flutter is installed
print_status "Checking for Flutter installation..."
if ! command -v flutter &> /dev/null; then
    print_warning "Flutter is not installed. Installing Flutter..."
    
    # Download Flutter
    FLUTTER_VERSION="3.24.0"
    FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_${FLUTTER_VERSION}-stable.zip"
    
    print_status "Downloading Flutter $FLUTTER_VERSION..."
    curl -O "$FLUTTER_URL"
    
    print_status "Extracting Flutter..."
    unzip "flutter_macos_${FLUTTER_VERSION}-stable.zip"
    
    # Add Flutter to PATH
    export PATH="$PATH:$(pwd)/flutter/bin"
    echo 'export PATH="$PATH:'$(pwd)'/flutter/bin"' >> ~/.zshrc
    echo 'export PATH="$PATH:'$(pwd)'/flutter/bin"' >> ~/.bash_profile
    
    print_success "Flutter installed successfully"
else
    flutter_version=$(flutter --version | head -n1)
    print_success "Found $flutter_version"
fi

# Check Flutter doctor
print_status "Running Flutter doctor..."
flutter doctor

# Enable iOS development
print_status "Enabling iOS development in Flutter..."
flutter config --enable-ios

# Check if CocoaPods is installed
print_status "Checking for CocoaPods installation..."
if ! command -v pod &> /dev/null; then
    print_warning "CocoaPods is not installed. Installing CocoaPods..."
    sudo gem install cocoapods
    print_success "CocoaPods installed successfully"
else
    pod_version=$(pod --version)
    print_success "Found CocoaPods $pod_version"
fi

# Install iOS dependencies
print_status "Installing iOS dependencies..."
cd ios
pod install
cd ..

print_success "iOS dependencies installed successfully"

# Download xfg-stark-cli for macOS
print_status "Downloading xfg-stark-cli for macOS..."
curl -L -o xfg-stark-cli-macos "https://github.com/ColinRitman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-macos"
chmod +x xfg-stark-cli-macos
mkdir -p assets/bin
mv xfg-stark-cli-macos assets/bin/

print_success "xfg-stark-cli downloaded successfully"

# Install Flutter dependencies
print_status "Installing Flutter dependencies..."
flutter pub get

print_success "Flutter dependencies installed successfully"

# Run Flutter doctor again to verify setup
print_status "Running Flutter doctor to verify setup..."
flutter doctor

# Check if we can build for iOS
print_status "Testing iOS build capability..."
if flutter build ios --debug --no-codesign; then
    print_success "iOS build test successful"
else
    print_warning "iOS build test failed. This might be due to code signing requirements"
fi

# Create iOS development configuration file
print_status "Creating iOS development configuration..."
cat > ios_development_config.json << EOF
{
  "bundle_id": "com.fuego.fuego_wallet",
  "app_name": "Fuego Wallet",
  "version": "1.0.0+1",
  "flutter_version": "$(flutter --version | head -n1 | cut -d' ' -f2)",
  "xcode_version": "$(xcodebuild -version | head -n1 | cut -d' ' -f2)",
  "cocoapods_version": "$(pod --version)",
  "setup_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

print_success "iOS development configuration created"

# Display next steps
echo ""
echo "🎉 iOS Development Environment Setup Complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "1. Open ios/Runner.xcworkspace in Xcode"
echo "2. Configure your Apple Developer account in Xcode"
echo "3. Set up code signing certificates and provisioning profiles"
echo "4. Run 'flutter run -d ios' to test on simulator"
echo "5. Run 'flutter run -d ios --release' to test on device"
echo ""
echo "For detailed instructions, see IOS_DEVELOPMENT_SETUP.md"
echo ""
echo "Configuration saved to: ios_development_config.json"