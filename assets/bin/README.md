# CLI Binaries

This directory contains platform-specific CLI binaries for the XF₲ Wallet.

## Binaries

- `xfg-stark-cli-linux` - Linux binary for STARK proof generation
- `xfg-stark-cli-macos` - macOS binary for STARK proof generation  
- `xfg-stark-cli.exe` - Windows binary for STARK proof generation

## Usage

These binaries are automatically downloaded during the GitHub Actions build process and bundled with the application. The CLIService handles extracting and executing the appropriate binary for the current platform.

## Source

Binaries are downloaded from: https://github.com/ColinRitman/xfgwin/releases/tag/v0.8.8
