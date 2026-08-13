#!/bin/bash

# Fuego Wallet Build & Run Script
# Builds unified daemon + Flutter app, then runs with debug logging

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[OK]${NC} $1"; }
print_fail() { echo -e "${RED}[FAIL]${NC} $1"; }

cd "$(dirname "$0")/.."
ROOT="$(pwd)"

echo ""
echo "==========================================="
echo " Fuego Wallet Build & Run"
echo "==========================================="
echo ""

# ── Step 1: Build unified daemon ──
print_status "Step 1: Building unified daemon..."

if [ ! -d "xfgo" ]; then
    print_status "Cloning fuego-suite..."
    git clone --depth 1 --recurse-submodules --shallow-submodules \
        https://github.com/usexfg/fuego-suite.git xfgo
fi

cd xfgo

if [ ! -f "build/src/unified" ]; then
    print_status "Configuring build..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install boost openssl icu4c jsoncpp cmake ninja 2>/dev/null || true
        cmake -B build -G Ninja \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0
    else
        sudo apt-get install -y libboost-all-dev libssl-dev libicu-dev libjsoncpp-dev cmake ninja-build 2>/dev/null || true
        cmake -B build -G Ninja \
            -DCMAKE_BUILD_TYPE=Release
    fi
    
    print_status "Building..."
    ninja -C build unified
    print_success "Unified daemon built"
else
    print_success "Unified daemon already built"
fi

cd ..

print_status "Building Rust backend (fuego_walletd)..."
cargo build --release --manifest-path rust-fuego-wallet/core/Cargo.toml || print_fail "cargo build failed"

# ── Step 2: Build Flutter app ──
print_status "Step 2: Building Flutter app..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    flutter build macos --release
    APP_PATH="build/macos/Build/Products/Release/fuego_wallet.app"
    BIN_PATH="$APP_PATH/Contents/MacOS"
    RES_PATH="$APP_PATH/Contents/Resources/bin"
    mkdir -p "$BIN_PATH" "$RES_PATH"

    # Bundle unified daemon into app (if the C++ build exists)
    if [ -f "$ROOT/xfgo/build/src/unified" ]; then
        print_status "Bundling unified daemon into app..."
        cp "$ROOT/xfgo/build/src/unified" "$BIN_PATH/"
        chmod +x "$BIN_PATH/unified"
        print_success "Unified daemon bundled at: $BIN_PATH/unified"
    else
        print_status "Unified daemon not built (C++ xfgo build missing) — skipping (Rust walletd covers it)"
    fi

    # Bundle Rust walletd + fuegod — REQUIRED for local mode
    print_status "Bundling Rust walletd + fuegod into app..."
    WALLETD=""
    for c in "$ROOT/rust-fuego-wallet/target/release/fuego_walletd" "$ROOT/rust-fuego-wallet/target/debug/fuego_walletd"; do
        if [ -x "$c" ]; then WALLETD="$c"; break; fi
    done
    FUEGOD=""
    for c in "$ROOT/rust-fuego-wallet/target/release/fuegod" "$ROOT/xfgo/build/src/fuegod" "$ROOT/rust-fuego-wallet/target/debug/fuegod"; do
        if [ -x "$c" ]; then FUEGOD="$c"; break; fi
    done
    if [ -n "$WALLETD" ]; then
        cp "$WALLETD" "$BIN_PATH/fuego_walletd"
        cp "$WALLETD" "$RES_PATH/fuego_walletd"
        chmod +x "$BIN_PATH/fuego_walletd" "$RES_PATH/fuego_walletd"
        print_success "fuego_walletd bundled"
    else
        print_fail "fuego_walletd not built — run: cargo build --release --manifest-path rust-fuego-wallet/core/Cargo.toml"
        exit 1
    fi
    if [ -n "$FUEGOD" ]; then
        cp "$FUEGOD" "$BIN_PATH/fuegod"
        cp "$FUEGOD" "$RES_PATH/fuegod"
        chmod +x "$BIN_PATH/fuegod" "$RES_PATH/fuegod"
        print_success "fuegod bundled"
    else
        print_fail "fuegod not built — bundle will fail in local mode"
        exit 1
    fi
else
    flutter build linux --release
    APP_PATH="build/linux/x64/release/bundle"
    if [ -f "$ROOT/xfgo/build/src/unified" ]; then
        cp "$ROOT/xfgo/build/src/unified" "$APP_PATH/"
        chmod +x "$APP_PATH/unified"
        print_success "Unified daemon bundled at: $APP_PATH/unified"
    fi
    WALLETD=""
    for c in "$ROOT/rust-fuego-wallet/target/release/fuego_walletd" "$ROOT/rust-fuego-wallet/target/debug/fuego_walletd"; do
        if [ -x "$c" ]; then WALLETD="$c"; break; fi
    done
    FUEGOD=""
    for c in "$ROOT/rust-fuego-wallet/target/release/fuegod" "$ROOT/xfgo/build/src/fuegod" "$ROOT/rust-fuego-wallet/target/debug/fuegod"; do
        if [ -x "$c" ]; then FUEGOD="$c"; break; fi
    done
    if [ -n "$WALLETD" ]; then
        cp "$WALLETD" "$APP_PATH/fuego_walletd" && chmod +x "$APP_PATH/fuego_walletd"
    else
        print_fail "fuego_walletd not built — run: cargo build --release --manifest-path rust-fuego-wallet/core/Cargo.toml"
        exit 1
    fi
    if [ -n "$FUEGOD" ]; then
        cp "$FUEGOD" "$APP_PATH/fuegod" && chmod +x "$APP_PATH/fuegod"
    else
        print_fail "fuegod not built — bundle will fail in local mode"
        exit 1
    fi
fi

# ── Step 3: Run app ──
print_status "Step 3: Running app..."

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo ""
    echo "App bundle: $APP_PATH"
    echo "Run manually:"
    echo "  open \"$APP_PATH\""
    echo ""
    echo "Or run fuego_walletd standalone to test local mode:"
    echo "  $APP_PATH/Contents/MacOS/fuego_walletd -P 18189 serve --daemon-host 127.0.0.1 --daemon-port 18180 --local"
    echo ""
    echo "Then test connectivity:"
    echo "  curl http://127.0.0.1:18189/health"
    echo "  curl -X POST http://127.0.0.1:18189/json_rpc -H 'Content-Type: application/json' -d '{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"getBalance\",\"params\":{\"accountIndex\":0}}'"
else
    echo ""
    echo "Run the app:"
    echo "  $APP_PATH/fuego_wallet"
    echo ""
    echo "Or test fuego_walletd standalone:"
    echo "  $APP_PATH/fuego_walletd -P 18189 serve --daemon-host 127.0.0.1 --daemon-port 18180 --local"
fi

print_success "Build complete"
