# CLI Binaries

This directory contains platform-specific CLI binaries for the XF₲ Wallet.

## Binaries

### STARK Proof Generation
- `xfg-stark-cli-linux` - Linux binary for STARK proof generation
- `xfg-stark-cli-macos` - macOS binary for STARK proof generation  
- `xfg-stark-cli.exe` - Windows binary for STARK proof generation

### Wallet Daemon
- `fuego-walletd-linux` - Linux wallet daemon binary
- `fuego-walletd-macos` - macOS wallet daemon binary
- `fuego-walletd-windows.exe` - Windows wallet daemon binary

## Usage

These binaries are automatically downloaded during the GitHub Actions build process and bundled with the application. The services handle extracting and executing the appropriate binary for the current platform.

## Sources

- STARK CLI binaries: https://github.com/ColinRitman/xfgwin/releases/tag/v0.8.8
- Wallet daemon binaries: https://github.com/usexfg/fuego/releases/latest
