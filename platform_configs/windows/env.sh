#!/bin/bash
# Windows platform configuration

# Set Boost paths for Windows (MSYS2/MinGW)
BOOST_ROOT="/c/boost"
export BOOST_ROOT
export LDFLAGS="-L${BOOST_ROOT}/lib"
export CPPFLAGS="-I${BOOST_ROOT}/include"
export BOOST_VERSION="1.85.0"

# Platform-specific binary names
export STARK_CLI_BINARY="xfg-stark-cli-windows.exe"
export WALLET_DAEMON_BINARY="fuego-walletd-windows.exe"

echo "Platform: Windows"
echo "Boost root: $BOOST_ROOT"
