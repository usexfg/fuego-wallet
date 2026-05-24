# Fuego Wallet CI — Detailed Reference Guide

## Architecture Overview

The Fuego Wallet CI pipeline consists of 6 GitHub Actions workflows that together build, sign, and distribute a cross-platform Flutter application with an embedded Fuego blockchain SDK.

### The SDK Build Chain

```
fuego-suite (hearth branch)
  ├── git submodules (recursive)
  ├── cmake configure
  │   ├── -DBUILD_TESTS=OFF
  │   ├── -DCMAKE_POSITION_INDEPENDENT_CODE=ON
  │   └── -DCMAKE_BUILD_TYPE=Release
  ├── make (builds .a/.so/.dylib/.dll files)
  └── SDK cmake (fuego-sdk/CMakeLists.txt)
      ├── -DFUEGO_DIR=../../fuego-core
      └── GLOB_RECURSE for *.a in build/src/
          └── libfuego_sdk.so/.dylib/.dll
              └── assets/bin/
                  └── Flutter build
```

### The Rust Crypto Chain

```
native/crypto/ (separate Rust project)
  ├── cargo build --release
  ├── libfuego_crypto.so/.dylib/.dll
  └── assets/bin/
      └── Flutter build
```

Rust crypto is built separately from the fuego-suite submodule. It is a standalone Rust project under `native/crypto/` and does not depend on Boost or the core C++ SDK.

### Flutter Packaging

```
Flutter app
  ├── assets/bin/
  │   ├── libfuego_sdk-{platform}.so/.dylib/.dll   (from SDK build)
  │   └── libfuego_crypto-{arch}.so/.dylib/.dll     (from Rust build)
  ├── flutter build {platform} --release
  └── {archive format}
      ├── macOS: .app → .zip
      ├── Windows: Release/ → .zip
      ├── Linux: bundle/ → .tar.gz
      ├── Android: .apk + .aab
      └── iOS: .app → .ipa
```

## Platform-Specific Build Details

### macOS (desktop-build.yml)

**Runner**: `macos-latest`

**Rust targets**: `x86_64-apple-darwin`, `aarch64-apple-darwin` (universal binary)
**SDK build**: SKIPPED (Boost compilation takes 15+ minutes; relies on Linux artifact)
**Flutter**: `flutter build macos --release`
**Artifact**: `Fuego-Wallet-macOS.zip` containing `fuego_wallet.app`

**What goes in `assets/bin/` for macOS:**
- `libfuego_crypto-x86_64.dylib`
- `libfuego_crypto-arm64.dylib`
- `libfuego_sdk.dylib` (if SDK build were enabled)

### Linux (desktop-build.yml)

**Runner**: `ubuntu-latest`

**Rust target**: `x86_64-unknown-linux-gnu`
**SDK build**: `libboost-all-dev` (system packages), `Boost_USE_STATIC_LIBS=ON`
**Flutter**: `flutter build linux --release`
**Artifact**: `fuego-wallet-Linux.tar.gz` containing `build/linux/x64/release/bundle/`

**sed patches applied**:
1. Boost `system` component removal from `CMakeLists.txt`
2. (Not needed: jsoncpp path on standard Ubuntu)

### Windows (desktop-build.yml)

**Runner**: `windows-latest`

**Rust target**: `x86_64-pc-windows-msvc`
**SDK build**: vcpkg at `C:/vcpkg` with toolchain file
**Flutter**: `flutter build windows --release`
**Artifact**: `Fuego-Wallet-Windows.zip` containing `build\windows\runner\Release\`

**vcpkg details**:
- Cloned from `https://github.com/Microsoft/vcpkg.git`
- Bootstrapped via `bootstrap-vcpkg.bat`
- Packages: `jsoncpp boost-system boost-filesystem boost-thread boost-date-time boost-chrono boost-regex boost-program-options openssl zeromq`
- Triplet: `x64-windows`
- CMake: `-DCMAKE_TOOLCHAIN_FILE=C:/vcpkg/scripts/buildsystems/vcpkg.cmake`

### iOS (ios-release.yml)

**Runner**: `macos-latest`

**SDK build**: Boost 1.83 compiled from source (static linking, no system component)
**Flutter**: `flutter build ios --release` → xcodebuild archive → IPA
**Code signing**: Requires 6 secrets (P12, API keys, team ID)
**Upload targets**: TestFlight (API), App Store (API)

**iOS SDK cross-compilation flags:**
```
-DCMAKE_SYSTEM_NAME=iOS
-DCMAKE_OSX_DEPLOYMENT_TARGET=12.0
-DCMAKE_OSX_ARCHITECTURES=arm64
```

### Android (android-release.yml + fdroid-release.yml)

**Runner**: `ubuntu-latest`

**Two separate build flows:**

**android-release.yml** (Play Store):
- SDK built with host toolchain (no NDK for SDK)
- Gradle `assembleRelease` + `bundleRelease`
- APK signed with `apksigner` using keystore from secrets
- AAB uploaded to Google Play via `r0adkll/upload-google-play@v1`
- MobSF security scan

**fdroid-release.yml** (F-Droid):
- Rust crypto built via `cargo-ndk` for 4 ABIs
- SDK built with host toolchain
- `flutter build apk --split-per-abi --release`
- No code signing (F-Droid signs with their own key)
- SHA256 checksums generated

## Secrets Reference

### iOS (6 secrets)

| Secret | Source | Format |
|--------|--------|--------|
| `IOS_P12_BASE64` | Apple Developer → Certificates | base64 of .p12 file |
| `IOS_P12_PASSWORD` | Set when exporting p12 | string |
| `APPSTORE_ISSUER_ID` | App Store Connect → Users → Keys | UUID |
| `APPSTORE_API_KEY_ID` | App Store Connect → Keys | string |
| `APPSTORE_API_PRIVATE_KEY` | App Store Connect → Keys → Download | PEM file contents |
| `IOS_TEAM_ID` | Apple Developer → Membership | 10-char team ID |

### Android (7 secrets)

| Secret | Source | Format |
|--------|--------|--------|
| `ANDROID_KEYSTORE_BASE64` | `base64 android/app/keystore.jks` | base64 string |
| `ANDROID_STORE_PASSWORD` | Set when creating keystore | string |
| `ANDROID_KEY_ALIAS` | Set when creating key | string |
| `ANDROID_KEY_PASSWORD` | Set when creating key | string |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Google Play Console → Service Accounts | JSON |
| `MOBSF_URL` | MobSF server URL | URL |
| `MOBSF_API_KEY` | MobSF API key | string |

### Linux (1 secret)

| Secret | Source | Format |
|--------|--------|--------|
| `SNAP_STORE_LOGIN` | Snapcraft → Account → Export login | base64 of exported file |

### Global (1 secret)

| Secret | Source | Format |
|--------|--------|--------|
| `DISCORD_WEBHOOK_URL` | Discord Server → Integrations → Webhook | URL |

## CMake Flags Reference

### Core (fuego-suite/CMakeLists.txt)

| Flag | Value | When |
|------|-------|------|
| `BUILD_TESTS` | `OFF` | Always |
| `CMAKE_POSITION_INDEPENDENT_CODE` | `ON` | Always |
| `CMAKE_BUILD_TYPE` | `Release` | Release builds |
| `Boost_USE_STATIC_LIBS` | `ON` | Linux, macOS (when building SDK) |
| `CMAKE_TOOLCHAIN_FILE` | vcpkg path | Windows only |

### SDK (fuego-sdk/CMakeLists.txt)

| Flag | Description | Default |
|------|-------------|---------|
| `FUEGO_SDK_BUILD_SHARED` | Build as shared library | `ON` |
| `FUEGO_SDK_TESTNET` | Enable testnet | `OFF` |
| `FUEGO_SDK_BUILD_EMBEDDED_NODE` | Embed full node | `OFF` |
| `FUEGO_DIR` | Path to core source | `../fuego` (CACHE PATH) |
| `CMAKE_OSX_DEPLOYMENT_TARGET` | macOS min version | `10.14` |

### Android (sdk-build NDK)

| Flag | Value |
|------|-------|
| `CMAKE_TOOLCHAIN_FILE` | `$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake` |
| `ANDROID_ABI` | `arm64-v8a` |
| `ANDROID_NATIVE_API_LEVEL` | `24` |

### iOS (sdk-build cross-compile)

| Flag | Value |
|------|-------|
| `CMAKE_SYSTEM_NAME` | `iOS` |
| `CMAKE_OSX_DEPLOYMENT_TARGET` | `12.0` |
| `CMAKE_OSX_ARCHITECTURES` | `arm64` |

## GitHub Actions Tips & Patterns

### Matrix Strategy

The workflows do NOT use a build matrix. Each platform is a separate job with explicit steps. This was done because the platform differences (package managers, sed flags, archive formats) are too large for clean matrix abstraction.

### Conditional Steps

Common patterns:

```yaml
# Run only on release
- if: github.event_name == 'release'
  run: upload-to-store.sh

# Run on dispatch with input
- if: github.event.inputs.upload_to_testflight == 'true'
  run: upload.sh

# Always run, even if upstream fails
- if: always()
  run: notify.sh

# Run on PR (debug/no-codesign)
- if: github.event_name == 'pull_request'
  run: flutter build apk --debug
```

### Artifact Sharing

Jobs share artifacts via `actions/upload-artifact@v4` and `actions/download-artifact@v4`:

```yaml
- uses: actions/upload-artifact@v4
  with:
    name: my-artifact
    path: path/to/files

- uses: actions/download-artifact@v4
  with:
    name: my-artifact
```

### Caching

Rust builds are cached via `swatinem/rust-cache@v2`. No other caches are used (Boost compilation is not cached — this is a performance opportunity).

## Troubleshooting Quick Reference

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `io_service` not found | Boost ≥1.84 | Install Boost 1.83 |
| `sed: invalid flag` | macOS vs Linux sed | Use `sed -i ''` on macOS |
| `json/json.h` not found | Ubuntu jsoncpp paths | Apply jsoncpp sed patch |
| vcpkg cmake fails | vcpkg not bootstrapped | Run `bootstrap-vcpkg.bat` |
| Flutter analyze deprecation | Flutter 3.27 API changes | Replace `initialValue`/`activeThumbColor` |
| Rust crate not found | Missing target | `rustup target add <triple>` |
| Code signing fails | Missing/misconfigured secrets | Verify all signing secrets |
| `libfuego_sdk.so` not in bundle | SDK build step failed | Check CMake output |
| APK not signed | Missing keystore | Check `ANDROID_KEYSTORE_BASE64` |
| Snapcraft login fails | Expired/revoked login | Re-export from Snapcraft |
| Disk space on runner | GitHub Actions 14GB limit | Clean build artifacts, use `actions/gh-actions-cache` |
