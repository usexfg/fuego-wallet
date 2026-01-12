#!/bin/bash
# macOS platform configuration

# Detect architecture
ARCH=$(uname -m)

# Use brew --prefix to get the correct Boost path
BOOST_ROOT=$(brew --prefix boost@1.85)

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
