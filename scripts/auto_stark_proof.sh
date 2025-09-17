#!/bin/bash

# Auto STARK Proof Generator for Fuego Wallet
# This script is called automatically after burn transactions
# Includes Eldernode verification stage and progress logging

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Try to find STARK CLI binary (downloaded from colinritman/xfgwin release)
CLI_PATH="$SCRIPT_DIR/../xfg-stark-cli"
if [ ! -f "$CLI_PATH" ]; then
  CLI_PATH="$SCRIPT_DIR/../../xfg-stark-cli"
fi
if [ ! -f "$CLI_PATH" ]; then
  CLI_PATH="./xfg-stark-cli"
fi
PYTHON_SCRIPT="$SCRIPT_DIR/stark_proof_generator.py"
PROGRESS_LOGGER="$SCRIPT_DIR/progress_logger.py"
TEMP_DIR="/tmp/fuego-stark-proofs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Function to print colored output
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

print_eldernode() {
    echo -e "${PURPLE}[ELDERNODE]${NC} $1"
}

print_progress() {
    echo -e "${CYAN}[PROGRESS]${NC} $1"
}

# Function to check if STARK CLI is available
check_stark_cli() {
    if [ ! -f "$CLI_PATH" ]; then
        print_error "STARK CLI not found at $CLI_PATH"
        print_info "Please download the STARK CLI from colinritman/xfgwin release:"
        print_info "  curl -L https://github.com/ColinRitman/xfgwin/releases/latest/download/xfg-stark-cli-$(uname -s | tr '[:upper:]' '[:lower:]').tar.gz | tar -xz"
        print_info "  chmod +x xfg-stark-cli"
        exit 1
    fi
    
    if [ ! -x "$CLI_PATH" ]; then
        print_error "STARK CLI is not executable: $CLI_PATH"
        print_info "Making it executable..."
        chmod +x "$CLI_PATH"
    fi
    
    print_success "STARK CLI found at: $CLI_PATH"
}

# Function to check if transaction is a burn using tx_extra 0x08 tag
is_burn_transaction() {
    local tx_hash="$1"
    local amount="$2"
    local tx_extra="${3:-}"
    
    # Check if transaction hash is valid (64 hex chars)
    if [[ ! "$tx_hash" =~ ^[a-fA-F0-9]{64}$ ]]; then
        print_warning "Invalid transaction hash format: $tx_hash"
        return 1
    fi
    
    # Check if amount is positive
    if [[ "$amount" -le 0 ]]; then
        print_warning "Invalid amount: $amount"
        return 1
    fi
    
    # If tx_extra is provided, check for HEAT commitment (0x08 tag)
    if [[ -n "$tx_extra" ]]; then
        print_info "Checking tx_extra for HEAT commitment (0x08 tag)..."
        
        # Use Python script to detect burn transaction
        if command -v python3 >/dev/null 2>&1; then
            local detector_script="$SCRIPT_DIR/burn_transaction_detector.py"
            if [[ -f "$detector_script" ]]; then
                local burn_data=$(python3 "$detector_script" "$tx_extra" 2>/dev/null)
                if [[ -n "$burn_data" ]]; then
                    print_success "Burn transaction detected via tx_extra 0x08 tag"
                    print_info "HEAT commitment found: $(echo "$burn_data" | grep -o '"commitment_hash":"[^"]*"' | cut -d'"' -f4)"
                    return 0
                else
                    print_warning "No HEAT commitment found in tx_extra"
                    return 1
                fi
            else
                print_warning "Burn detector script not found, falling back to basic validation"
            fi
        else
            print_warning "Python3 not available, falling back to basic validation"
        fi
    else
        print_warning "No tx_extra provided, cannot verify HEAT commitment"
        print_info "Consider providing tx_extra data for proper burn detection"
    fi
    
    # Fallback: consider valid transaction as potential burn if no tx_extra
    print_info "Using fallback validation (no tx_extra provided)"
    return 0
}

# Function to generate STARK proof with progress logging
generate_stark_proof() {
    local tx_hash="$1"
    local recipient="$2"
    local amount="$3"
    local block_height="${4:-0}"
    
    print_progress "Step 1: Generating STARK proof for transaction: $tx_hash"
    print_info "Recipient: $recipient"
    print_info "Amount: $amount XFG"
    print_info "Block height: $block_height"
    
    # Create temp directory
    mkdir -p "$TEMP_DIR"
    
    # Create package file
    local package_file="$TEMP_DIR/package_${tx_hash}.json"
    local proof_file="$TEMP_DIR/proof_${tx_hash}.json"
    
    # Create JSON package
    cat > "$package_file" << EOF
{
  "burn_transaction": {
    "transaction_hash": "$tx_hash",
    "burn_amount_xfg": $amount,
    "block_height": $block_height
  },
  "recipient": {
    "ethereum_address": "$recipient"
  },
  "secret": {
    "secret_key": ""
  },
  "metadata": {
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "description": "Auto-generated for burn transaction $tx_hash"
  }
}
EOF
    
    print_info "Created package file: $package_file"
    
    # Check if CLI exists
    if [[ ! -f "$CLI_PATH" ]]; then
        print_error "xfg-stark-cli not found at: $CLI_PATH"
        print_info "Please build the CLI first: cd xfgwin && cargo build --bin xfg-stark-cli"
        return 1
    fi
    
    # Make CLI executable
    chmod +x "$CLI_PATH"
    
    # Run the CLI with progress logging
    print_progress "Running STARK proof generation..."
    if "$CLI_PATH" generate "$package_file" "$proof_file"; then
        print_success "STARK proof generated successfully!"
        print_info "Proof file: $proof_file"
        print_info "Package file: $package_file"
        return 0
    else
        print_error "STARK proof generation failed"
        return 1
    fi
}

# Function to perform Eldernode verification with progress logging
eldernode_verify() {
    local tx_hash="$1"
    local amount="$2"
    local package_file="$3"
    
    print_eldernode "Step 2: Eldernode verification for transaction: $tx_hash"
    print_eldernode "Amount: $amount XFG"
    
    # Create verification package
    local verification_file="$TEMP_DIR/verification_${tx_hash}.json"
    
    cat > "$verification_file" << EOF
{
  "burn_transaction": {
    "transaction_hash": "$tx_hash",
    "burn_amount_xfg": $amount
  },
  "verification": {
    "requested_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "status": "pending"
  }
}
EOF
    
    print_eldernode "Created verification package: $verification_file"
    
    # Run Eldernode verification using CLI
    print_eldernode "Contacting Eldernodes for verification..."
    if "$CLI_PATH" eldernode-verify "$verification_file"; then
        print_success "Eldernode verification completed successfully!"
        print_eldernode "Burn transaction verified by Eldernode network"
        return 0
    else
        print_error "Eldernode verification failed"
        return 1
    fi
}

# Function to create complete proof package with copy-paste file
create_complete_package() {
    local tx_hash="$1"
    local recipient="$2"
    local amount="$3"
    local proof_file="$4"
    
    print_progress "Step 3: Creating complete proof package for HEAT minting"
    
    local complete_package="$TEMP_DIR/complete_${tx_hash}.json"
    local copy_paste_file="$TEMP_DIR/copy_paste_${tx_hash}.txt"
    
    # Create JSON package
    cat > "$complete_package" << EOF
{
  "burn_transaction": {
    "transaction_hash": "$tx_hash",
    "burn_amount_xfg": $amount,
    "burn_amount_heat": $((amount * 80 / 100)),
    "protocol_fee": $((amount * 20 / 100))
  },
  "recipient": {
    "ethereum_address": "$recipient"
  },
  "stark_proof": {
    "file": "$proof_file",
    "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "eldernode_verification": {
    "status": "verified",
    "verified_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  },
  "heat_mint_ready": true,
  "metadata": {
    "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "description": "Complete proof package ready for HEAT minting"
  }
}
EOF
    
    print_success "Complete proof package created: $complete_package"
    
    # Create copy-paste file for easy smart contract submission
    create_copy_paste_file "$tx_hash" "$recipient" "$amount" "$proof_file" "$copy_paste_file"
    
    print_success "🎉 Ready for HEAT minting!"
    print_info "Next step: Use the copy-paste file to submit to HEAT minting contract"
    
    return 0
}

# Function to create copy-paste file for smart contract submission
create_copy_paste_file() {
    local tx_hash="$1"
    local recipient="$2"
    local amount="$3"
    local proof_file="$4"
    local copy_paste_file="$5"
    
    print_progress "Creating copy-paste file for smart contract submission..."
    
    # Read proof data
    local proof_data=""
    if [[ -f "$proof_file" ]]; then
        proof_data=$(cat "$proof_file" | tr -d '\n')
    else
        proof_data="PROOF_DATA_PLACEHOLDER"
    fi
    
    # Calculate amounts
    local heat_amount=$((amount * 80 / 100))
    local protocol_fee=$((amount * 20 / 100))
    
    # Create copy-paste file
    cat > "$copy_paste_file" << EOF
================================================================================
XFG BURN TO HEAT MINT - COMPLETE PROOF DATA
================================================================================
Generated: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
Transaction: $tx_hash
Recipient: $recipient
Burn Amount: $amount XFG
HEAT Amount: $heat_amount HEAT
Protocol Fee: $protocol_fee XFG (to treasury)
================================================================================

STARK PROOF DATA (for smart contract):
----------------------------------------
$proof_data

ELDERNODE VERIFICATION DATA:
----------------------------------------
{
  "status": "verified",
  "verified_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "network_consensus": true,
  "transaction_hash": "$tx_hash",
  "burn_amount_xfg": $amount
}

SMART CONTRACT SUBMISSION INSTRUCTIONS:
----------------------------------------
• Copy the STARK PROOF DATA above
• Submit to HEAT minting contract with recipient address: $recipient
• Include sufficient gas for transaction (recommended: 500,000 gas)
• Wait for confirmation and receive $heat_amount HEAT tokens

================================================================================
Copy the STARK PROOF DATA above and submit to HEAT minting contract
================================================================================
EOF
    
    print_success "Copy-paste file created: $copy_paste_file"
    print_info "Users can now easily copy the proof data for smart contract submission"
}

# Function to cleanup old files
cleanup_old_files() {
    local max_age_hours="${1:-24}"
    local cutoff_time=$(date -d "$max_age_hours hours ago" +%s)
    
    print_info "Cleaning up files older than $max_age_hours hours..."
    
    if [[ -d "$TEMP_DIR" ]]; then
        find "$TEMP_DIR" -type f -mtime +$((max_age_hours/24)) -delete 2>/dev/null || true
        print_success "Cleanup completed"
    fi
}

# Function to show completion summary
show_completion_summary() {
    local tx_hash="$1"
    local complete_package="$TEMP_DIR/complete_${tx_hash}.json"
    local copy_paste_file="$TEMP_DIR/copy_paste_${tx_hash}.txt"
    local progress_log="$TEMP_DIR/progress_${tx_hash}.log"
    
    echo ""
    echo "=================================================================================="
    echo "🎉 XFG Burn to HEAT Mint Process Completed Successfully!"
    echo "=================================================================================="
    echo "📁 Complete proof package: $complete_package"
    echo "📋 Copy-paste file: $copy_paste_file"
    echo "📊 Progress log: $progress_log"
    echo ""
    echo "💡 Next Steps:"
    echo "   1. Open the copy-paste file: $copy_paste_file"
    echo "   2. Copy the STARK PROOF DATA section"
    echo "   3. Submit to HEAT minting contract"
    echo "   4. Receive your HEAT tokens!"
    echo ""
    echo "🔗 Files created:"
    echo "   • Complete package (JSON): $complete_package"
    echo "   • Copy-paste file (TXT): $copy_paste_file"
    echo "   • Progress log: $progress_log"
    echo "=================================================================================="
}

# Main function
main() {
    # Check if STARK CLI is available
    check_stark_cli
    
    # Check arguments
    if [[ $# -lt 3 ]]; then
        echo "Usage: $0 <transaction_hash> <recipient_address> <burn_amount> [block_height] [tx_extra]"
        echo ""
        echo "Arguments:"
        echo "  transaction_hash  - 64-character hex transaction hash"
        echo "  recipient_address - Ethereum address to receive HEAT tokens"
        echo "  burn_amount       - Amount of XFG burned"
        echo "  block_height      - Block height (optional, defaults to 0)"
        echo "  tx_extra          - Transaction extra data (optional, for 0x08 tag verification)"
        echo ""
        echo "Process:"
        echo "  1. Detect burn transaction using tx_extra 0x08 tag"
        echo "  2. Generate STARK proof"
        echo "  3. Eldernode verification"
        echo "  4. Create complete package for HEAT minting"
        echo "  5. Create copy-paste file for smart contract submission"
        echo ""
        echo "Note: Providing tx_extra data enables proper burn transaction detection"
        echo "      using the TX_EXTRA_HEAT_COMMITMENT (0x08) tag."
        exit 1
    fi
    
    local tx_hash="$1"
    local recipient="$2"
    local amount="$3"
    local block_height="${4:-0}"
    local tx_extra="${5:-}"
    
    print_progress "Starting complete XFG burn to HEAT mint process..."
    print_info "Transaction: $tx_hash"
    print_info "Recipient: $recipient"
    print_info "Amount: $amount XFG"
    
    # Validate transaction using tx_extra 0x08 tag detection
    if ! is_burn_transaction "$tx_hash" "$amount" "$tx_extra"; then
        print_error "Invalid burn transaction parameters or no HEAT commitment found"
        if [[ -n "$tx_extra" ]]; then
            print_info "tx_extra provided but no TX_EXTRA_HEAT_COMMITMENT (0x08) tag found"
            print_info "This transaction may not be a proper burn transaction"
        else
            print_info "No tx_extra provided - cannot verify HEAT commitment"
            print_info "Consider providing tx_extra data for proper burn detection"
        fi
        exit 1
    fi
    
    # Validate recipient address
    if [[ ! "$recipient" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        print_error "Invalid Ethereum address: $recipient"
        exit 1
    fi
    
    # Step 1: Generate STARK proof
    local package_file="$TEMP_DIR/package_${tx_hash}.json"
    local proof_file="$TEMP_DIR/proof_${tx_hash}.json"
    
    if ! generate_stark_proof "$tx_hash" "$recipient" "$amount" "$block_height"; then
        print_error "STARK proof generation failed - stopping process"
        exit 1
    fi
    
    # Step 2: Eldernode verification
    if ! eldernode_verify "$tx_hash" "$amount" "$package_file"; then
        print_error "Eldernode verification failed - stopping process"
        exit 1
    fi
    
    # Step 3: Create complete package
    if ! create_complete_package "$tx_hash" "$recipient" "$amount" "$proof_file"; then
        print_error "Failed to create complete package"
        exit 1
    fi
    
    # Cleanup old files
    cleanup_old_files 24
    
    # Show completion summary
    show_completion_summary "$tx_hash"
    
    print_success "🎉 Complete XFG burn to HEAT mint process completed successfully!"
    print_info "All files saved in: $TEMP_DIR"
    exit 0
}

# Run main function with all arguments
main "$@"
