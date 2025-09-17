#!/bin/bash
# Download XFG STARK CLI from colinritman/xfgwin releases

PLATFORM=$(uname -s | tr '[:upper:]' '[:lower:]')
if [[ "$PLATFORM" == "darwin" ]]; then
  PLATFORM="macos"
elif [[ "$PLATFORM" == "linux" ]]; then
  PLATFORM="linux"
else
  echo "❌ Unsupported platform: $PLATFORM"
  exit 1
fi

ASSET_NAME="xfg-stark-cli-$PLATFORM.tar.gz"
BINARY_NAME="xfg-stark-cli"

echo "📥 Downloading STARK CLI for $PLATFORM..."

# Get download URL
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/ColinRitman/xfgwin/releases/latest | jq -r ".assets[] | select(.name==\"$ASSET_NAME\") | .browser_download_url")

if [ -z "$DOWNLOAD_URL" ]; then
  echo "❌ Could not find download URL for $ASSET_NAME"
  exit 1
fi

# Download and extract
curl -L -o "$ASSET_NAME" "$DOWNLOAD_URL"
tar -xzf "$ASSET_NAME"
chmod +x "$BINARY_NAME"

echo "✅ STARK CLI downloaded successfully"
echo "Binary: $BINARY_NAME"
echo "Version: $($BINARY_NAME --version)"