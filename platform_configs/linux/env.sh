#!/bin/bash
# Linux platform configuration

# Set Boost paths for Linux
BOOST_ROOT="/usr"
export BOOST_ROOT
export LDFLAGS="-L${BOOST_ROOT}/lib/x86_64-linux-gnu"
export CPPFLAGS="-I${BOOST_ROOT}/include"
export BOOST_VERSION="1.85.0"

# Platform-specific binary names
export STARK_CLI_BINARY="xfg-stark-cli-linux"
export WALLET_DAEMON_BINARY="fuego-walletd-linux"

echo "Platform: Linux"
echo "Boost root: $BOOST_ROOT"
