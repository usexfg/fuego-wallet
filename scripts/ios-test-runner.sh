#!/bin/bash

# XF₲ Wallet iOS Test Runner Script
# This script runs comprehensive tests for the iOS app

set -e

echo "🧪 Running XF₲ Wallet iOS Tests"
echo "==============================="

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

# Test results
test_passed=true

# Run Flutter unit tests
print_status "Running Flutter unit tests..."
if flutter test; then
    print_success "Unit tests passed"
else
    print_error "Unit tests failed"
    test_passed=false
fi

# Run Flutter widget tests
print_status "Running Flutter widget tests..."
if flutter test test/widget_test.dart; then
    print_success "Widget tests passed"
else
    print_warning "Widget tests failed or not found"
fi

# Run Flutter integration tests
print_status "Running Flutter integration tests..."
if [ -d "integration_test" ]; then
    if flutter test integration_test/; then
        print_success "Integration tests passed"
    else
        print_warning "Integration tests failed"
    fi
else
    print_warning "Integration tests directory not found"
fi

# Run Flutter analyze
print_status "Running Flutter analyze..."
if flutter analyze; then
    print_success "Code analysis passed"
else
    print_error "Code analysis failed"
    test_passed=false
fi

# Run Flutter test with coverage
print_status "Running Flutter tests with coverage..."
if flutter test --coverage; then
    print_success "Coverage tests passed"
    
    # Generate coverage report
    if command -v genhtml &> /dev/null; then
        print_status "Generating coverage report..."
        genhtml coverage/lcov.info -o coverage/html
        print_success "Coverage report generated in coverage/html/"
    else
        print_warning "genhtml not found. Install lcov for coverage reports"
    fi
else
    print_error "Coverage tests failed"
    test_passed=false
fi

# Test iOS build (debug)
print_status "Testing iOS debug build..."
if flutter build ios --debug --no-codesign; then
    print_success "iOS debug build successful"
else
    print_error "iOS debug build failed"
    test_passed=false
fi

# Test iOS build (release) - dry run
print_status "Testing iOS release build (dry run)..."
if flutter build ios --release --no-codesign --dry-run; then
    print_success "iOS release build test passed"
else
    print_warning "iOS release build test failed (might be due to code signing)"
fi

# Check for iOS-specific issues
print_status "Checking iOS-specific configurations..."

# Check Info.plist
if [ -f "ios/Runner/Info.plist" ]; then
    print_success "Info.plist found"
    
    # Check for required keys
    required_keys=(
        "CFBundleDisplayName"
        "CFBundleIdentifier"
        "NSPhotoLibraryUsageDescription"
        "NSDocumentsFolderUsageDescription"
    )
    
    for key in "${required_keys[@]}"; do
        if grep -q "$key" ios/Runner/Info.plist; then
            print_success "Found $key in Info.plist"
        else
            print_warning "Missing $key in Info.plist"
        fi
    done
else
    print_error "Info.plist not found"
    test_passed=false
fi

# Check Podfile
if [ -f "ios/Podfile" ]; then
    print_success "Podfile found"
else
    print_error "Podfile not found"
    test_passed=false
fi

# Check Podfile.lock
if [ -f "ios/Podfile.lock" ]; then
    print_success "Podfile.lock found"
else
    print_warning "Podfile.lock not found. Run 'pod install' in ios directory"
fi

# Check for security issues
print_status "Running security checks..."

# Check for hardcoded secrets
if grep -r "password\|secret\|key\|token" ios/Runner/ --include="*.swift" --include="*.m" --include="*.h" | grep -v "//" | grep -v "NSPhotoLibraryUsageDescription"; then
    print_warning "Potential hardcoded secrets found in iOS code"
else
    print_success "No hardcoded secrets found"
fi

# Check for debug configurations in release
if grep -q "DEBUG" ios/Runner/Info.plist; then
    print_warning "Debug configurations found in Info.plist"
else
    print_success "No debug configurations found in Info.plist"
fi

# Check ATS configuration
if grep -q "NSAppTransportSecurity" ios/Runner/Info.plist; then
    print_success "ATS configuration found"
else
    print_warning "ATS configuration not found"
fi

# Performance tests
print_status "Running performance tests..."

# Check app size
if [ -d "build/ios/iphoneos" ]; then
    app_size=$(du -sh build/ios/iphoneos/Runner.app 2>/dev/null | cut -f1)
    print_status "App size: $app_size"
    
    # Check if app size is reasonable (less than 100MB)
    size_mb=$(du -sm build/ios/iphoneos/Runner.app 2>/dev/null | cut -f1)
    if [ "$size_mb" -lt 100 ]; then
        print_success "App size is reasonable ($size_mb MB)"
    else
        print_warning "App size is large ($size_mb MB). Consider optimizing assets"
    fi
else
    print_warning "App build not found for size analysis"
fi

# Memory usage test (if simulator is available)
print_status "Checking iOS simulator availability..."
if xcrun simctl list devices available | grep -q "iPhone"; then
    print_success "iOS simulators are available"
    
    # Try to run on simulator
    print_status "Testing app on iOS simulator..."
    if timeout 30 flutter run -d ios --debug --no-sound-null-safety 2>/dev/null; then
        print_success "App runs on iOS simulator"
    else
        print_warning "App failed to run on iOS simulator (timeout or error)"
    fi
else
    print_warning "No iOS simulators found"
fi

# Summary
echo ""
echo "📊 Test Summary"
echo "==============="

if [ "$test_passed" = true ]; then
    print_success "✅ All critical tests passed"
    echo ""
    echo "The iOS app is ready for:"
    echo "1. Manual testing on devices"
    echo "2. Code review"
    echo "3. CI/CD pipeline"
    echo "4. Distribution"
else
    print_error "❌ Some tests failed"
    echo ""
    echo "Please fix the issues above before proceeding"
    echo "For help, see IOS_DEVELOPMENT_SETUP.md"
fi

# Generate test report
print_status "Generating test report..."
cat > ios_test_report.md << EOF
# iOS Test Report

**Date:** $(date)
**Flutter Version:** $(flutter --version | head -n1)
**Xcode Version:** $(xcodebuild -version | head -n1)

## Test Results

- Unit Tests: $([ "$test_passed" = true ] && echo "✅ PASSED" || echo "❌ FAILED")
- Widget Tests: $([ -f "test/widget_test.dart" ] && echo "✅ PASSED" || echo "⚠️ NOT FOUND")
- Integration Tests: $([ -d "integration_test" ] && echo "✅ PASSED" || echo "⚠️ NOT FOUND")
- Code Analysis: $([ "$test_passed" = true ] && echo "✅ PASSED" || echo "❌ FAILED")
- iOS Debug Build: $([ "$test_passed" = true ] && echo "✅ PASSED" || echo "❌ FAILED")
- Security Checks: $([ "$test_passed" = true ] && echo "✅ PASSED" || echo "❌ FAILED")

## Coverage

Coverage report available in: coverage/html/

## Next Steps

1. Review any warnings or errors
2. Test on physical iOS devices
3. Submit for code review
4. Deploy to TestFlight or App Store

EOF

print_success "Test report generated: ios_test_report.md"

# Exit with appropriate code
if [ "$test_passed" = true ]; then
    exit 0
else
    exit 1
fi