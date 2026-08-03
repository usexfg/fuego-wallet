# CLI Binaries

This directory contains platform-specific CLI binaries for the Fuego Wallet.

## Binaries

### Wallet Daemon
- `fuego_walletd-linux` - Linux wallet daemon binary
- `fuego_walletd-macos` - macOS wallet daemon binary
- `fuego_walletd-windows.exe` - Windows wallet daemon binary

### Unified Daemon
- `unified-linux` - Linux unified daemon (fuegod + walletd + xfg-swapd)
- `unified-macos` - macOS unified daemon
- `unified-windows.exe` - Windows unified daemon

## Usage

These binaries are automatically downloaded during the GitHub Actions build process and bundled with the application. The services handle extracting and executing the appropriate binary for the current platform.

## Sources

- Unified daemon: https://github.com/usexfg/fuego-suite (master branch)
- Build from source using the master branch for latest features
