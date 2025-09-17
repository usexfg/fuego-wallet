#!/bin/bash

# Test script for auto-STARK functionality in Fuego Wallet
# This script tests the complete flow from burn transaction to HEAT mint ready

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
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

# Test configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUTO_STARK_SCRIPT="$SCRIPT_DIR/scripts/auto_stark_proof.sh"
CLI_PATH="$SCRIPT_DIR/../xfgwin/target/debug/xfg-stark-cli"

# Test data
TEST_TX_HASH="7D0725F8E03021B99560ADD456C596FEA7D8DF23529E23765E56923B73236E4D"
TEST_RECIPIENT="0x742d35Cc6634C0532925a3b8D4C9db96C4b4d8b6"
TEST_AMOUNT="8000000"

print_info "Testing Auto-STARK functionality for Fuego Wallet"
print_info "Test transaction hash: $TEST_TX_HASH"
print_info "Test recipient: $TEST_RECIPIENT"
print_info "Test amount: $TEST_AMOUNT"

# Check if auto-stark script exists
if [ ! -f "$AUTO_STARK_SCRIPT" ]; then
    print_error "Auto STARK script not found at: $AUTO_STARK_SCRIPT"
    exit 1
fi

# Check if CLI exists
if [ ! -f "$CLI_PATH" ]; then
    print_warning "STARK CLI not found at: $CLI_PATH"
    print_info "Building STARK CLI..."
    cd "$SCRIPT_DIR/../xfgwin"
    cargo build --bin xfg-stark-cli
    if [ ! -f "$CLI_PATH" ]; then
        print_error "Failed to build STARK CLI"
        exit 1
    fi
fi

# Make script executable
chmod +x "$AUTO_STARK_SCRIPT"

# Set environment variables
export FUEGO_AUTO_STARK_PROOF="true"
export FUEGO_ELDERNODE_VERIFICATION="true"
export FUEGO_ELDERNODE_TIMEOUT="300"

print_info "Running auto-STARK proof generation..."

# Run the auto-stark script
if "$AUTO_STARK_SCRIPT" "$TEST_TX_HASH" "$TEST_RECIPIENT" "$TEST_AMOUNT"; then
    print_success "Auto-STARK proof generation completed successfully!"
    
    # Check if proof files were created
    PROOF_DIR="/tmp/fuego-stark-proofs"
    if [ -d "$PROOF_DIR" ]; then
        print_info "Proof files created in: $PROOF_DIR"
        ls -la "$PROOF_DIR"
    fi
    
    print_success "Test completed successfully!"
    print_info "The auto-STARK functionality is working correctly."
    print_info "Users can now automatically generate STARK proofs after burn transactions."
    
else
    print_error "Auto-STARK proof generation failed!"
    print_info "Check the logs above for error details."
    exit 1
fi

print_info "Test completed!"
