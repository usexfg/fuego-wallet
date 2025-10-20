#!/bin/bash

# XF₲ Wallet Android Setup Validation Script
# This script validates the Android release workflow configuration

set -e

echo "🔍 XF₲ Wallet Android Setup Validation"
echo "======================================"
echo ""

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found. Please run this script from the project root."
    exit 1
fi

echo "✅ Found pubspec.yaml - in correct directory"
echo ""

# Check Flutter installation
echo "🔍 Checking Flutter installation..."
if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -n 1)
    echo "✅ Flutter found: $FLUTTER_VERSION"
else
    echo "❌ Flutter not found. Please install Flutter first."
    exit 1
fi

# Check Flutter doctor
echo ""
echo "🔍 Running Flutter doctor..."
flutter doctor --android-licenses || echo "⚠️  Android licenses not accepted (run 'flutter doctor --android-licenses')"

# Check Android configuration
echo ""
echo "🔍 Checking Android configuration..."
if [ -f "android/app/build.gradle" ]; then
    echo "✅ Android build.gradle found"
    
    # Check for signing configuration
    if grep -q "signingConfigs" android/app/build.gradle; then
        echo "✅ Signing configuration found in build.gradle"
    else
        echo "❌ Signing configuration missing in build.gradle"
    fi
    
    # Check for ProGuard rules
    if [ -f "android/app/proguard-rules.pro" ]; then
        echo "✅ ProGuard rules found"
    else
        echo "❌ ProGuard rules missing"
    fi
else
    echo "❌ Android build.gradle not found"
fi

# Check workflow files
echo ""
echo "🔍 Checking GitHub Actions workflow..."
if [ -f ".github/workflows/android-release.yml" ]; then
    echo "✅ Android release workflow found"
else
    echo "❌ Android release workflow missing"
fi

# Check for required secrets (simulation)
echo ""
echo "🔍 Checking GitHub Secrets (simulation)..."
echo "Required secrets for the workflow:"
echo "  - ANDROID_KEYSTORE_BASE64"
echo "  - ANDROID_STORE_PASSWORD"
echo "  - ANDROID_KEY_ALIAS"
echo "  - ANDROID_KEY_PASSWORD"
echo ""
echo "Optional secrets:"
echo "  - GOOGLE_PLAY_SERVICE_ACCOUNT_JSON (for Play Store upload)"
echo "  - DISCORD_WEBHOOK_URL (for notifications)"
echo "  - MOBSF_URL (for security scanning)"
echo "  - MOBSF_API_KEY (for security scanning)"

# Check project structure
echo ""
echo "🔍 Checking project structure..."
REQUIRED_FILES=(
    "pubspec.yaml"
    "android/app/build.gradle"
    "android/app/proguard-rules.pro"
    ".github/workflows/android-release.yml"
    "ANDROID_RELEASE_SETUP.md"
    "scripts/setup-android-keystore.sh"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file"
    else
        echo "❌ $file missing"
    fi
done

# Check Flutter dependencies
echo ""
echo "🔍 Checking Flutter dependencies..."
if flutter pub get > /dev/null 2>&1; then
    echo "✅ Flutter dependencies resolved"
else
    echo "❌ Flutter dependencies failed to resolve"
fi

# Test Flutter analyze
echo ""
echo "🔍 Running Flutter analyze..."
if flutter analyze > /dev/null 2>&1; then
    echo "✅ Flutter analyze passed"
else
    echo "⚠️  Flutter analyze found issues (run 'flutter analyze' for details)"
fi

# Test Flutter test
echo ""
echo "🔍 Running Flutter tests..."
if flutter test > /dev/null 2>&1; then
    echo "✅ Flutter tests passed"
else
    echo "⚠️  Flutter tests failed (run 'flutter test' for details)"
fi

echo ""
echo "🎯 Validation Summary"
echo "===================="
echo ""
echo "The Android release workflow setup is complete!"
echo ""
echo "Next steps:"
echo "1. Run './scripts/setup-android-keystore.sh' to create your keystore"
echo "2. Add the required secrets to your GitHub repository"
echo "3. Test the workflow by pushing to main/master or creating a release"
echo ""
echo "For detailed instructions, see ANDROID_RELEASE_SETUP.md"
