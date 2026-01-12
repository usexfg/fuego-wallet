#!/bin/bash
# macOS platform configuration

# Detect architecture
ARCH=$(uname -m)

# Set Boost paths based on architecture
if [ "$ARCH" = "arm64" ]; then
    # Apple Silicon (ARM64) - Homebrew installs to /opt/homebrew
    BOOST_ROOT="/opt/homebrew/opt/boost@1.85"
else
    # Intel Mac - Homebrew installs to /usr/local
    BOOST_ROOT="/usr/local/opt/boost@1.85"
fi

# Export environment variables
export BOOST_ROOT
export LDFLAGS="-L${BOOST_ROOT}/lib"
export CPPFLAGS="-I${BOOST_ROOT}/include"
export BOOST_VERSION="1.85.0"

# Platform-specific binary names
export STARK_CLI_BINARY="xfg-stark-cli-macos"
export WALLET_DAEMON_BINARY="fuego-walletd-macos"

echo "Platform: macOS ($ARCH)"
echo "Boost root: $BOOST_ROOT"
