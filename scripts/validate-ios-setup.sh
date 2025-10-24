#!/bin/bash

# XF₲ Wallet iOS Setup Validation Script
# This script validates the iOS development environment setup

set -e

echo "🔍 Validating XF₲ Wallet iOS Development Environment"
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

# Validation results
validation_passed=true

# Check if running on macOS
print_status "Checking macOS compatibility..."
if [[ "$OSTYPE" != "darwin"* ]]; then
    print_error "This script must be run on macOS for iOS development"
    validation_passed=false
else
    macos_version=$(sw_vers -productVersion)
    print_success "macOS version: $macos_version"
fi

# Check Xcode installation
print_status "Checking Xcode installation..."
if ! command -v xcodebuild &> /dev/null; then
    print_error "Xcode is not installed"
    validation_passed=false
else
    xcode_version=$(xcodebuild -version | head -n1)
    print_success "Found $xcode_version"
fi

# Check Xcode Command Line Tools
print_status "Checking Xcode Command Line Tools..."
if ! xcode-select -p &> /dev/null; then
    print_error "Xcode Command Line Tools are not installed"
    validation_passed=false
else
    print_success "Xcode Command Line Tools are installed"
fi

# Check Flutter installation
print_status "Checking Flutter installation..."
if ! command -v flutter &> /dev/null; then
    print_error "Flutter is not installed or not in PATH"
    validation_passed=false
else
    flutter_version=$(flutter --version | head -n1)
    print_success "Found $flutter_version"
    
    # Check Flutter doctor
    print_status "Running Flutter doctor..."
    if flutter doctor; then
        print_success "Flutter doctor passed"
    else
        print_warning "Flutter doctor found issues"
    fi
fi

# Check CocoaPods installation
print_status "Checking CocoaPods installation..."
if ! command -v pod &> /dev/null; then
    print_error "CocoaPods is not installed"
    validation_passed=false
else
    pod_version=$(pod --version)
    print_success "Found CocoaPods $pod_version"
fi

# Check iOS project structure
print_status "Checking iOS project structure..."
if [ ! -d "ios" ]; then
    print_error "iOS directory not found"
    validation_passed=false
else
    print_success "iOS directory found"
    
    # Check for required iOS files
    required_files=(
        "ios/Runner.xcworkspace"
        "ios/Runner/Info.plist"
        "ios/Runner/AppDelegate.swift"
        "ios/Podfile"
    )
    
    for file in "${required_files[@]}"; do
        if [ -f "$file" ]; then
            print_success "Found $file"
        else
            print_error "Missing $file"
            validation_passed=false
        fi
    done
fi

# Check Podfile.lock
print_status "Checking Podfile.lock..."
if [ -f "ios/Podfile.lock" ]; then
    print_success "Podfile.lock found"
else
    print_warning "Podfile.lock not found. Run 'pod install' in ios directory"
fi

# Check xfg-stark-cli binary
print_status "Checking xfg-stark-cli binary..."
if [ -f "assets/bin/xfg-stark-cli-macos" ]; then
    if [ -x "assets/bin/xfg-stark-cli-macos" ]; then
        print_success "xfg-stark-cli-macos found and executable"
    else
        print_error "xfg-stark-cli-macos is not executable"
        validation_passed=false
    fi
else
    print_warning "xfg-stark-cli-macos not found. Run setup-ios-development.sh"
fi

# Check Flutter dependencies
print_status "Checking Flutter dependencies..."
if [ -f "pubspec.lock" ]; then
    print_success "pubspec.lock found"
else
    print_warning "pubspec.lock not found. Run 'flutter pub get'"
fi

# Test Flutter iOS build capability
print_status "Testing Flutter iOS build capability..."
if flutter build ios --debug --no-codesign --dry-run 2>/dev/null; then
    print_success "Flutter iOS build test passed"
else
    print_warning "Flutter iOS build test failed (this might be due to code signing requirements)"
fi

# Check iOS simulator availability
print_status "Checking iOS simulator availability..."
if xcrun simctl list devices available | grep -q "iPhone"; then
    print_success "iOS simulators are available"
else
    print_warning "No iOS simulators found. Install simulators in Xcode"
fi

# Check for required environment variables
print_status "Checking environment variables..."
if [ -n "$FLUTTER_ROOT" ]; then
    print_success "FLUTTER_ROOT is set: $FLUTTER_ROOT"
else
    print_warning "FLUTTER_ROOT is not set"
fi

# Check iOS development configuration
print_status "Checking iOS development configuration..."
if [ -f "ios_development_config.json" ]; then
    print_success "iOS development configuration found"
    cat ios_development_config.json
else
    print_warning "iOS development configuration not found. Run setup-ios-development.sh"
fi

# Check GitHub Actions workflow
print_status "Checking GitHub Actions workflow..."
if [ -f ".github/workflows/ios-release.yml" ]; then
    print_success "iOS release workflow found"
else
    print_warning "iOS release workflow not found"
fi

# Check for required secrets (if running in CI)
if [ -n "$GITHUB_ACTIONS" ]; then
    print_status "Checking GitHub Actions secrets..."
    required_secrets=(
        "IOS_P12_BASE64"
        "IOS_P12_PASSWORD"
        "IOS_TEAM_ID"
        "APPSTORE_ISSUER_ID"
        "APPSTORE_API_KEY_ID"
        "APPSTORE_API_PRIVATE_KEY"
    )
    
    for secret in "${required_secrets[@]}"; do
        if [ -n "${!secret}" ]; then
            print_success "Secret $secret is set"
        else
            print_warning "Secret $secret is not set"
        fi
    done
fi

# Summary
echo ""
echo "📊 Validation Summary"
echo "===================="

if [ "$validation_passed" = true ]; then
    print_success "✅ iOS development environment is properly configured"
    echo ""
    echo "You can now:"
    echo "1. Run 'flutter run -d ios' to test on simulator"
    echo "2. Open ios/Runner.xcworkspace in Xcode"
    echo "3. Configure code signing in Xcode"
    echo "4. Build and test on physical devices"
else
    print_error "❌ iOS development environment has issues"
    echo ""
    echo "Please fix the issues above and run this script again"
    echo "For help, see IOS_DEVELOPMENT_SETUP.md"
fi

# Exit with appropriate code
if [ "$validation_passed" = true ]; then
    exit 0
else
    exit 1
fi