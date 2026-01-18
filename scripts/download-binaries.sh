#!/bin/bash
# Download pre-built binaries for Fuego Wallet CI
# This script downloads all required binaries for CI builds

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "📥 Downloading pre-built binaries for Fuego Wallet CI"
echo "===================================================="
echo "Project root: $PROJECT_ROOT"
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

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

# Create assets/bin directory
mkdir -p "$PROJECT_ROOT/assets/bin"
print_info "Created assets/bin directory"

# Download all binaries
download_binaries() {
    print_info "Downloading all required binaries..."

    # STARK CLI binaries
    print_info "Downloading STARK CLI binaries..."

    # Linux
    if [ ! -f "$PROJECT_ROOT/assets/bin/xfg-stark-cli-linux" ] || [ ! -s "$PROJECT_ROOT/assets/bin/xfg-stark-cli-linux" ]; then
        print_info "Downloading xfg-stark-cli-linux..."
        # Try tar.gz first, then zip
        curl -L -o "$PROJECT_ROOT/assets/bin/xfg-stark-cli-linux.tar.gz" "https://github.com/ColinRitman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-linux.tar.gz"
        # Extract and find the binary
        if [ -f "$PROJECT_ROOT/assets/bin/xfg-stark-cli-linux.tar.gz" ]; then
            cd "$PROJECT_ROOT/assets/bin"
            tar -xzf xfg-stark-cli-linux.tar.gz
            # Find and rename the actual binary
            BINARY_NAME=$(find . -type f -name "xfg-stark-cli*" -not -name "*.tar.gz" -not -name "*.zip" | head -n1)
            if [ -n "$BINARY_NAME" ]; then
                mv "$BINARY_NAME" xfg-stark-cli-linux
                chmod +x xfg-stark-cli-linux
                rm -f xfg-stark-cli-linux.tar.gz
                print_success "xfg-stark-cli-linux downloaded and extracted"
            else
                print_error "Failed to extract xfg-stark-cli-linux"
                rm -f xfg-stark-cli-linux.tar.gz
            fi
            cd - > /dev/null
        else
            print_error "Failed to download xfg-stark-cli-linux.tar.gz"
        fi
    else
        print_success "xfg-stark-cli-linux already exists"
    fi

    # macOS
    if [ ! -f "$PROJECT_ROOT/assets/bin/xfg-stark-cli-macos" ] || [ ! -s "$PROJECT_ROOT/assets/bin/xfg-stark-cli-macos" ]; then
        print_info "Downloading xfg-stark-cli-macos..."
        # Try tar.gz first, then zip
        curl -L -o "$PROJECT_ROOT/assets/bin/xfg-stark-cli-macos.tar.gz" "https://github.com/ColinRitman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-macos.tar.gz"
        # Extract and find the binary
        if [ -f "$PROJECT_ROOT/assets/bin/xfg-stark-cli-macos.tar.gz" ]; then
            cd "$PROJECT_ROOT/assets/bin"
            tar -xzf xfg-stark-cli-macos.tar.gz
            # Find and rename the actual binary
            BINARY_NAME=$(find . -type f -name "xfg-stark-cli*" -not -name "*.tar.gz" -not -name "*.zip" | head -n1)
            if [ -n "$BINARY_NAME" ]; then
                mv "$BINARY_NAME" xfg-stark-cli-macos
                chmod +x xfg-stark-cli-macos
                rm -f xfg-stark-cli-macos.tar.gz
                print_success "xfg-stark-cli-macos downloaded and extracted"
            else
                print_error "Failed to extract xfg-stark-cli-macos"
                rm -f xfg-stark-cli-macos.tar.gz
            fi
            cd - > /dev/null
        else
            print_error "Failed to download xfg-stark-cli-macos.tar.gz"
        fi
    else
        print_success "xfg-stark-cli-macos already exists"
    fi

    # Windows
    if [ ! -f "$PROJECT_ROOT/assets/bin/xfg-stark-cli-windows.exe" ] || [ ! -s "$PROJECT_ROOT/assets/bin/xfg-stark-cli-windows.exe" ]; then
        print_info "Downloading xfg-stark-cli-windows.exe..."
        # Try tar.gz first, then zip
        curl -L -o "$PROJECT_ROOT/assets/bin/xfg-stark-cli-windows.tar.gz" "https://github.com/ColinRitman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-windows.tar.gz"
        # Extract and find the binary
        if [ -f "$PROJECT_ROOT/assets/bin/xfg-stark-cli-windows.tar.gz" ]; then
            cd "$PROJECT_ROOT/assets/bin"
            tar -xzf xfg-stark-cli-windows.tar.gz
            # Find and rename the actual binary
            BINARY_NAME=$(find . -type f -name "xfg-stark-cli*.exe" -not -name "*.tar.gz" -not -name "*.zip" | head -n1)
            if [ -n "$BINARY_NAME" ]; then
                mv "$BINARY_NAME" xfg-stark-cli-windows.exe
                rm -f xfg-stark-cli-windows.tar.gz
                print_success "xfg-stark-cli-windows.exe downloaded and extracted"
            else
                # Try .zip if .tar.gz didn't work
                rm -f xfg-stark-cli-windows.tar.gz
                curl -L -o "$PROJECT_ROOT/assets/bin/xfg-stark-cli-windows.zip" "https://github.com/ColinRitman/xfgwin/releases/download/v0.8.8/xfg-stark-cli-windows.zip"
                if [ -f "$PROJECT_ROOT/assets/bin/xfg-stark-cli-windows.zip" ]; then
                    # Check if unzip is available
                    if ! command -v unzip &> /dev/null; then
                        print_warning "unzip not found, installing..."
                        if command -v apt-get &> /dev/null; then
                            sudo apt-get install -y unzip
                        elif command -v yum &> /dev/null; then
                            sudo yum install -y unzip
                        else
                            print_error "Cannot install unzip. Please install it manually."
                            rm -f xfg-stark-cli-windows.zip
                            return 1
                        fi
                    fi
                    unzip -o xfg-stark-cli-windows.zip
                    BINARY_NAME=$(find . -type f -name "xfg-stark-cli*.exe" -not -name "*.tar.gz" -not -name "*.zip" | head -n1)
                    if [ -n "$BINARY_NAME" ]; then
                        mv "$BINARY_NAME" xfg-stark-cli-windows.exe
                        rm -f xfg-stark-cli-windows.zip
                        print_success "xfg-stark-cli-windows.exe downloaded and extracted (from zip)"
                    else
                        print_error "Failed to extract xfg-stark-cli-windows.exe (from zip)"
                        rm -f xfg-stark-cli-windows.zip
                    fi
                else
                    print_error "Failed to download xfg-stark-cli-windows.zip"
                fi
            fi
            cd - > /dev/null
        else
            print_error "Failed to download xfg-stark-cli-windows.tar.gz"
        fi
    else
        print_success "xfg-stark-cli-windows.exe already exists"
    fi

    # Wallet daemon binaries (using placeholder binaries for now)
    print_info "Creating placeholder walletd binaries..."

    # Linux
    if [ ! -f "$PROJECT_ROOT/assets/bin/fuego-walletd-linux" ]; then
        print_info "Creating placeholder fuego-walletd-linux..."
        echo "#!/bin/bash" > "$PROJECT_ROOT/assets/bin/fuego-walletd-linux"
        echo 'echo "Fuego Wallet Daemon (Linux) - Placeholder"' >> "$PROJECT_ROOT/assets/bin/fuego-walletd-linux"
        echo 'echo "In CI, this will be replaced with the actual binary built from source"' >> "$PROJECT_ROOT/assets/bin/fuego-walletd-linux"
        chmod +x "$PROJECT_ROOT/assets/bin/fuego-walletd-linux"
        print_success "fuego-walletd-linux created (placeholder)"
    else
        print_success "fuego-walletd-linux already exists"
    fi

    # macOS
    if [ ! -f "$PROJECT_ROOT/assets/bin/fuego-walletd-macos" ]; then
        print_info "Creating placeholder fuego-walletd-macos..."
        echo "#!/bin/bash" > "$PROJECT_ROOT/assets/bin/fuego-walletd-macos"
        echo 'echo "Fuego Wallet Daemon (macOS) - Placeholder"' >> "$PROJECT_ROOT/assets/bin/fuego-walletd-macos"
        echo 'echo "In CI, this will be replaced with the actual binary built from source"' >> "$PROJECT_ROOT/assets/bin/fuego-walletd-macos"
        chmod +x "$PROJECT_ROOT/assets/bin/fuego-walletd-macos"
        print_success "fuego-walletd-macos created (placeholder)"
    else
        print_success "fuego-walletd-macos already exists"
    fi

    # Windows
    if [ ! -f "$PROJECT_ROOT/assets/bin/fuego-walletd-windows.exe" ]; then
        print_info "Creating placeholder fuego-walletd-windows.exe..."
        echo '@echo off' > "$PROJECT_ROOT/assets/bin/fuego-walletd-windows.exe"
        echo 'echo Fuego Wallet Daemon (Windows) - Placeholder' >> "$PROJECT_ROOT/assets/bin/fuego-walletd-windows.exe"
        echo 'echo In CI, this will be replaced with the actual binary built from source' >> "$PROJECT_ROOT/assets/bin/fuego-walletd-windows.exe"
        print_success "fuego-walletd-windows.exe created (placeholder)"
    else
        print_success "fuego-walletd-windows.exe already exists"
    fi
}

# Verify all binaries
verify_binaries() {
    print_info "Verifying all binaries..."

    required_binaries=(
        "assets/bin/fuego-walletd-linux"
        "assets/bin/fuego-walletd-macos"
        "assets/bin/fuego-walletd-windows.exe"
        "assets/bin/xfg-stark-cli-linux"
        "assets/bin/xfg-stark-cli-macos"
        "assets/bin/xfg-stark-cli-windows.exe"
    )

    all_present=true
    for binary in "${required_binaries[@]}"; do
        if [ -f "$PROJECT_ROOT/$binary" ]; then
            if [[ "$binary" != *.exe ]] && [ ! -x "$PROJECT_ROOT/$binary" ]; then
                chmod +x "$PROJECT_ROOT/$binary"
            fi
            print_success "✅ $binary is present"
        else
            print_error "❌ $binary is missing"
            all_present=false
        fi
    done

    if [ "$all_present" = true ]; then
        print_success "🎉 All required binaries are available!"
        return 0
    else
        print_error "❌ Some binaries are missing or invalid!"
        return 1
    fi
}

# Main execution
main() {
    print_info "Starting binary download process..."

    # Download binaries
    download_binaries

    # Verify all binaries
    verify_binaries

    print_success "✅ Binary download process completed!"
    echo ""
    echo "Binaries are ready for:"
    echo "- CI/CD builds"
    echo "- Local development"
    echo "- Cross-platform testing"
}

# Run main
main "$@"
