#!/bin/bash

# XF₲ Wallet Android Keystore Setup Script
# This script helps generate and configure the Android keystore for release builds

set -e

echo "🔐 XF₲ Wallet Android Keystore Setup"
echo "====================================="
echo ""

# Check if keytool is available
if ! command -v keytool &> /dev/null; then
    echo "❌ Error: keytool not found. Please install Java JDK first."
    echo "   On macOS: brew install openjdk"
    echo "   On Ubuntu: sudo apt-get install openjdk-11-jdk"
    exit 1
fi

# Default values
KEYSTORE_NAME="android-release-key.keystore"
KEY_ALIAS="fuego-wallet-key"
KEY_ALG="RSA"
KEY_SIZE="2048"
VALIDITY_DAYS="10000"

echo "This script will help you create an Android keystore for signing release builds."
echo "Keep the generated keystore file and passwords safe - you'll need them for GitHub Secrets."
echo ""

# Get keystore details from user
read -p "Keystore file name [$KEYSTORE_NAME]: " input_keystore
KEYSTORE_NAME=${input_keystore:-$KEYSTORE_NAME}

read -p "Key alias [$KEY_ALIAS]: " input_alias
KEY_ALIAS=${input_alias:-$KEY_ALIAS}

read -p "Key algorithm [$KEY_ALG]: " input_alg
KEY_ALG=${input_alg:-$KEY_ALG}

read -p "Key size [$KEY_SIZE]: " input_size
KEY_SIZE=${input_size:-$KEY_SIZE}

read -p "Validity in days [$VALIDITY_DAYS]: " input_validity
VALIDITY_DAYS=${input_validity:-$VALIDITY_DAYS}

echo ""
echo "Creating keystore with the following settings:"
echo "  Keystore file: $KEYSTORE_NAME"
echo "  Key alias: $KEY_ALIAS"
echo "  Key algorithm: $KEY_ALG"
echo "  Key size: $KEY_SIZE bits"
echo "  Validity: $VALIDITY_DAYS days"
echo ""

# Create the keystore
echo "🔨 Generating keystore..."
keytool -genkey -v \
    -keystore "$KEYSTORE_NAME" \
    -alias "$KEY_ALIAS" \
    -keyalg "$KEY_ALG" \
    -keysize "$KEY_SIZE" \
    -validity "$VALIDITY_DAYS"

echo ""
echo "✅ Keystore created successfully!"
echo ""

# Generate base64 encoded keystore
echo "📋 Generating base64 encoded keystore for GitHub Secrets..."
if command -v base64 &> /dev/null; then
    KEYSTORE_BASE64=$(base64 -i "$KEYSTORE_NAME")
    echo "Base64 encoded keystore:"
    echo "$KEYSTORE_BASE64"
    echo ""
    
    # Try to copy to clipboard if available
    if command -v pbcopy &> /dev/null; then
        echo "$KEYSTORE_BASE64" | pbcopy
        echo "📋 Base64 keystore copied to clipboard (macOS)"
    elif command -v xclip &> /dev/null; then
        echo "$KEYSTORE_BASE64" | xclip -selection clipboard
        echo "📋 Base64 keystore copied to clipboard (Linux)"
    fi
else
    echo "❌ base64 command not found. Please install base64 utility."
fi

echo ""
echo "🔧 Next Steps:"
echo "=============="
echo ""
echo "1. Add the following secrets to your GitHub repository:"
echo "   - ANDROID_KEYSTORE_BASE64: (copy the base64 string above)"
echo "   - ANDROID_STORE_PASSWORD: (the keystore password you entered)"
echo "   - ANDROID_KEY_ALIAS: $KEY_ALIAS"
echo "   - ANDROID_KEY_PASSWORD: (the key password you entered)"
echo ""
echo "2. Go to your GitHub repository → Settings → Secrets and variables → Actions"
echo "3. Click 'New repository secret' for each secret above"
echo ""
echo "4. Test the workflow by:"
echo "   - Pushing to main/master branch (debug build)"
echo "   - Creating a release (signed build)"
echo "   - Using manual workflow dispatch"
echo ""
echo "5. Keep the keystore file safe:"
echo "   - Store it in a secure location"
echo "   - Back it up securely"
echo "   - Never commit it to the repository"
echo ""

# Create a backup reminder
echo "💾 Backup Reminder:"
echo "==================="
echo "Store these files securely:"
echo "  - $KEYSTORE_NAME"
echo "  - Keystore password"
echo "  - Key password"
echo "  - Key alias: $KEY_ALIAS"
echo ""

# Verify keystore
echo "🔍 Verifying keystore..."
keytool -list -v -keystore "$KEYSTORE_NAME" -alias "$KEY_ALIAS" > /dev/null
echo "✅ Keystore verification successful!"

echo ""
echo "🎉 Setup complete! Your Android release workflow is ready to use."
echo "   See ANDROID_RELEASE_SETUP.md for detailed usage instructions."
