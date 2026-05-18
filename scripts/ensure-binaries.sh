#!/bin/bash

# Fuego Wallet Binary Download Script
# This script ensures all required binaries are downloaded before running tests or builds

set -e

echo "📦 Fuego Wallet binaries logic"
echo "============================================="

# We no longer need xfg-stark binaries as HEAT is now an on-chain XFG-colored stablecoin.
# zk proving/proofs is now handled in a separate repo at github.com/usexfg/zk-fire.
echo "No external binaries (xfg-stark, fuego-prover) needed for this build."

exit 0