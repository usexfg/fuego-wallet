# Skill: fuego-ci-workflows

Expert knowledge base for the Fuego Wallet CI/CD pipeline. Covers all 6 GitHub Actions workflows, platform-specific build quirks, Boost version constraints, submodule strategy, and how to diagnose/fix CI failures across macOS, Linux, Windows, Android, and iOS builds.

## When to Use

This skill should be used when:
- A CI workflow fails and needs diagnosis
- Adding a new workflow or modifying an existing one
- Changing the SDK build configuration (CMake, dependencies, Boost)
- Updating the fuego-suite submodule branch or version
- Debugging platform-specific build issues (macOS Boost, Windows vcpkg, Linux jsoncpp)
- Setting up code signing or store uploads (App Store Connect, Google Play, Snapcraft)
- Adding new secrets or artifacts to the release pipeline
- Reviewing or auditing CI security practices

## Trigger Phrases

- "CI workflow failed" / "build failure"
- "desktop build" / "macOS build" / "Windows build" / "Linux build"
- "Android release" / "iOS build" / "F-Droid" / "fdroid"
- "Snap package" / "flatpak" / "AppImage"
- "fuego-suite" / "hearth branch" / "fuego submodule"
- "Boost" / "vcpkg" / "jsoncpp"
- "code signing" / "App Store Connect" / "Google Play"
- "GitHub Actions" / "workflow" / "CI" / "release pipeline"

## Repository Structure

```
.github/workflows/
  desktop-build.yml           # Desktop builds: macOS, Windows, Linux + GitHub Release
  linux-appstore-release.yml  # Snap, Flatpak, AppImage + store uploads
  ios-release.yml             # iOS IPA + TestFlight + App Store upload
  android-release.yml         # Android APK/AAB + Play Store upload + MobSF scan
  fdroid-release.yml          # F-Droid unsigned APKs with SHA256 checksums
  sdk-build.yml               # Standalone SDK build across all platforms + Dart package
```

### Branch Strategy

All workflows target branches: `HEATMINT`, `master`, `azorahai`.

The `fuego-suite` submodule uses the `hearth` branch exclusively. This is set in both `.gitmodules` and all workflow environment variables via `FUEGO_SOURCE_BRANCH: hearth`.

### Path Triggers

Workflows only run when changes touch their relevant paths:
- **desktop-build.yml**: `lib/**`, `macos/**`, `windows/**`, `linux/**`, `fuego-sdk/**`, `pubspec.yaml`
- **linux-appstore.yml**: Same + `snapcraft.yaml`, `flatpak/**`
- **ios-release.yml**: `lib/**`, `ios/**`, `fuego-sdk/**`, `pubspec.yaml`
- **android-release.yml**: `lib/**`, `android/**`, `fuego-sdk/**`, `pubspec.yaml`
- **fdroid-release.yml**: Same paths as android
- **sdk-build.yml**: `fuego-sdk/**`, `fuego/**` (azorahai branch only)

## Workflow Summaries

### 1. desktop-build.yml — Desktop Build & Release

**Triggers**: Push/PR to HEATMINT, master, azorahai + manual dispatch + GitHub Release

**Jobs**:
- `build-macos` (macos-latest): Flutter 3.27, Rust crypto (x86_64 + arm64), SDK build SKIPPED, Flutter macOS build, zip artifact
- `build-windows` (windows-latest): Flutter, Rust, vcpkg deps, SDK build (vcpkg toolchain), Flutter Windows, zip artifact
- `build-linux` (ubuntu-latest): Flutter, Rust, system packages, SDK build (Boost_USE_STATIC_LIBS=ON), Flutter Linux, tar.gz artifact

**Key facts**:
- macOS SDK build is SKIPPED — relies on Linux-built artifact or local build
- Windows vcpkg is hardcoded to `C:/vcpkg`
- Rust crypto libs are built separately (not from submodule) and placed in `assets/bin/`
- All jobs upload artifacts and optionally attach to GitHub Release

### 2. linux-appstore-release.yml — Linux App Store Distribution

**Triggers**: Push/PR + manual dispatch (with `distribution_method` and `upload_to_store` inputs) + Release

**Jobs**:
- `build-sdk-linux`: Central SDK build (reused by all downstream jobs)
- `build-snap`: SDK → Flutter build → `snapcraft --destructive-mode`
- `build-flatpak`: SDK → Flutter build → `flatpak-builder`
- `build-appimage`: SDK → Flutter build → `appimagetool`
- `upload-to-snap-store`: Snapcraft login + upload
- `upload-to-flathub`: Manual submission required (prints message)
- `security-scan`: Basic presence checks
- `notify-release`: Discord webhook

**Key facts**:
- `SNAP_NAME` = `xfg-wallet`, `FLATPAK_APP_ID` = `com.fuego.fuego_wallet`
- Snapcraft uses `--destructive-mode` (builds directly on host, no LXD)
- Flatpak uses `com.fuego.fuego_wallet.yml` manifest in `flatpak/` directory

### 3. ios-release.yml — iOS Build & App Store

**Triggers**: Push/PR + manual dispatch (with `upload_to_testflight`, `upload_to_app_store`) + Release

**Jobs**:
- `build-ios` (macos-latest): SDK build with Boost 1.83 from source, Flutter iOS, xcodebuild archive + IPA export
- `upload-to-testflight`: App Store Connect API upload
- `upload-to-app-store`: App Store Connect API upload
- `security-scan`: Hardcoded secrets grep, ATS check in Info.plist
- `code-quality`: Flutter analyze + test coverage + lcov
- `notify-release`: Discord webhook

**Key facts**:
- Boost 1.83 built from source (last version with `io_service` alias)
- macOS sed uses `-i ''` (BSD sed), NOT GNU sed's `-i`
- Code signing via `apple-actions/import-codesign-certs@v2` and `download-provisioning-profiles@v1`
- 6 App Store Connect secrets required

### 4. android-release.yml — Android Build & Play Store

**Triggers**: Push/PR + manual dispatch (with `upload_to_play_store`) + Release

**Jobs**:
- `build-android` (ubuntu-latest): SDK build, Gradle assembleRelease + bundleRelease, apksigner
- `upload-to-play-store`: `r0adkll/upload-google-play@v1`
- `security-scan`: MobSF static analysis
- `notify-release`: Discord + GitHub Step Summary

**Key facts**:
- jsoncpp include path patched: `#include <json/json.h>` → `#include <jsoncpp/json.h>`
- Android keystore decoded from `ANDROID_KEYSTORE_BASE64` secret
- Both APK (signed) and AAB produced
- MobSF requires `MOBSF_URL` and `MOBSF_API_KEY` secrets

### 5. fdroid-release.yml — F-Droid Build

**Triggers**: Push/PR + manual dispatch + Release

**Jobs**:
- `build-fdroid-apk` (ubuntu-latest): Rust crypto via cargo-ndk (4 ABIs), SDK, Flutter build APK (split-per-abi), SHA256 checksums

**Key facts**:
- No code signing — F-Droid signs with their own key
- 4 Android ABIs: arm64-v8a, armeabi-v7a, x86, x86_64
- Uses `cargo-ndk` (install via `cargo install cargo-ndk`)
- NDK r25b from `nttld/setup-ndk@v1`
- Rust libs per ABI copied to `assets/bin/` with ABI suffixes
- No Play Store upload (F-Droid is separate)
- jsoncpp include path patch applied (same as android-release)

### 6. sdk-build.yml — Standalone SDK Build

**Triggers**: Push/PR to `azorahai` only (fuego-sdk/** or fuego/**)

**Jobs**:
- `build-linux` (ubuntu-22.04): CMake, make, make install → artifact
- `build-macos` (macos-latest): CMake with brew deps, make → artifact
- `build-windows` (windows-latest): Chocolatey deps, VS 2022 generator → artifact
- `build-android` (ubuntu-22.04): NDK 25, CMake with android toolchain → artifact (ARM64 only)
- `build-ios` (macos-latest): iOS cross-compile CMake → artifact (arm64, min 12.0)
- `dart-package` (ubuntu-22.04): Flutter 3.19, pub get, analyze, test, dry-run publish

**Key facts**:
- Uses Ubuntu 22.04 (not latest) for `build-linux`, `build-android`, `dart-package`
- Flutter 3.19.0 for dart-package (older than desktop's 3.27)
- Qt5 installed for Linux/macOS SDK build (not just desktop workflow)
- Only ARM64 for Android (not all 4 ABIs like fdroid)
- `dart-package` runs `flutter pub publish --dry-run`

## Build Dependencies by Platform

### Linux (Ubuntu)

```
build-essential git cmake libboost-all-dev libssl-dev libzmq3-dev libjsoncpp-dev
# Flutter Linux desktop (desktop-build, linux-appstore):
clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev
# SDK standalone (sdk-build):
libqt5gui5 libqt5widgets5 libqt5network5 qtbase5-dev
```

### macOS

```
brew install cmake pkg-config openssl zeromq jsoncpp
# optional: boost@1.86, qt@5, clang
# Boost 1.83 is built from source in ios-release.yml
```

### Windows

```
# vcpkg (desktop-build, via C:/vcpkg):
jsoncpp boost-system boost-filesystem boost-thread boost-date-time boost-chrono boost-regex boost-program-options openssl zeromq
# Chocolatey (sdk-build only):
boost-msvc-14.3 cmake qt5
```

### All Platforms (Rust)

```
# via dtolnay/rust-toolchain@stable
# native/crypto workspace
# Per-platform targets set as needed:
# macOS: x86_64-apple-darwin, aarch64-apple-darwin
# Linux: x86_64-unknown-linux-gnu
# Windows: x86_64-pc-windows-msvc
# Android: aarch64-linux-android, armv7-linux-androideabi, i686-linux-android, x86_64-linux-android
```

## Critical Constraints

### Boost Version (Most Common Failure)

The `hearth` branch of `fuego-suite` uses `boost::asio::io_service` and `io_service::work`, which were **removed in Boost 1.84+**. You MUST use Boost ≤1.83.

**Per-platform approach**:
- **macOS (ios-release)**: Build Boost 1.83 from source
  ```bash
  wget https://archives.boost.io/release/1.83.0/source/boost_1_83_0.tar.gz
  tar xzf boost_1_83_0.tar.gz
  cd boost_1_83_0
  ./bootstrap.sh --with-libraries=system,filesystem,thread,date_time,chrono,regex,serialization,program_options
  sudo ./b2 -j$(sysctl -n hw.ncpu) variant=release link=static install
  ```
- **Linux**: Ubuntu 24.04's `libboost1.83-dev` is compatible
- **Windows**: Use vcpkg with Boost 1.83 — avoid newer default versions

### Boost `system` Component Removal

All core build workflows remove `system` from `BOOST_COMPONENTS` via sed:
```
# Linux (GNU sed):
sed -i 's/set(BOOST_COMPONENTS system filesystem ...)/set(BOOST_COMPONENTS filesystem ...)/' CMakeLists.txt
# macOS (BSD sed):
sed -i '' 's/set(BOOST_COMPONENTS system filesystem ...)/set(BOOST_COMPONENTS filesystem ...)/' CMakeLists.txt
```

### jsoncpp Include Path

For Linux builds (android-release, fdroid-release), the core header needs patching:
```
sed -i 's/#include <json\/json.h>/#include <jsoncpp\/json.h>/g' src/CryptoNoteCore/ProofStructures.h
```

### CMake Configuration

The SDK `CMakeLists.txt` (`fuego-sdk/CMakeLists.txt`) uses:
- `CACHE PATH` for `FUEGO_DIR` (default `../fuego`, override with `-DFUEGO_DIR=...`)
- `GLOB_RECURSE` to find all `.a` files in `${FUEGO_DIR}/build/src/`
- C++17 standard
- Boost ≥1.55 required

Essential CMake flags:
```
-DBUILD_TESTS=OFF
-DCMAKE_POSITION_INDEPENDENT_CODE=ON
-DCMAKE_BUILD_TYPE=Release
-DBoost_USE_STATIC_LIBS=ON         # Linux/macOS static
-DCMAKE_TOOLCHAIN_FILE=...          # Windows: vcpkg, Android: NDK
```

### Flutter Version

All workflows except `sdk-build.yml` use Flutter **3.27.0** (stable channel).
`sdk-build.yml` uses Flutter **3.19.0** for the dart-package job.

### Branch: `hearth`

Every workflow that clones `fuego-suite` MUST use `-b hearth`. This is handled via the `FUEGO_SOURCE_BRANCH: hearth` environment variable and `.gitmodules` configuration.

The submodule path is `fuego` → `https://github.com/usexfg/fuego-suite.git` branch `hearth`.

## Common Failure Modes & Fixes

### 1. "undefined symbol: io_service" / Boost version mismatch

**Symptom**: Linker error about `boost::asio::io_service` not found.
**Cause**: Boost 1.84+ removed `io_service` (renamed to `io_context`).
**Fix**: Install Boost 1.83 or earlier. On macOS, compile from source. On Linux, use `libboost1.83-dev`.

### 2. Windows vcpkg Boost version conflict

**Symptom**: `find_package(Boost)` fails with version mismatch, or vcpkg installs wrong Boost version.
**Cause**: vcpkg may default to Boost ≥1.84 which breaks `io_service`.
**Fix**: Pin Boost to 1.83 via vcpkg overlay triplet or explicit version in `vcpkg.json`.

### 3. macOS sed: "invalid flag" / "extra characters"

**Symptom**: sed command in CI fails with `sed: 1: "...": invalid flag`.
**Cause**: macOS uses BSD sed which requires an argument to `-i` (e.g., `-i ''`). GNU sed's `-i` (no argument) is not supported.
**Fix**: Use `sed -i '' 's/.../.../'` on macOS. Use `sed -i 's/.../.../'` on Linux.

### 4. jsoncpp include not found

**Symptom**: `fatal error: json/json.h: No such file or directory`.
**Cause**: Ubuntu packages put jsoncpp headers in `jsoncpp/json/` not `json/`.
**Fix**: Apply the sed patch: `s/#include <json\/json.h>/#include <jsoncpp\/json.h>/g` on `ProofStructures.h`.

### 5. Flutter `initialValue` / `activeThumbColor` deprecation

**Symptom**: Flutter analyze fails with deprecated API warnings (Flutter 3.27).
**Fix**: Replace `initialValue` with `value` on Switch widgets. Replace `activeThumbColor` with `WidgetStateProperty.all(...)`.

### 6. Windows vcpkg not bootstrapped

**Symptom**: `vcpkg` command not found, or cmake toolchain file missing.
**Cause**: vcpkg was not installed or `bootstrap-vcpkg.bat` failed.
**Fix**: Ensure vcpkg is installed to `C:/vcpkg` and `bootstrap-vcpkg.bat` ran successfully. Verify `VCPKG_ROOT` env var.

### 7. Rust target not installed

**Symptom**: `error[E0463]: can't find crate for core` or similar Rust errors.
**Cause**: The `dtolnay/rust-toolchain@stable` action may not have the right targets.
**Fix**: Add the target explicitly via `rustup target add <target-triple>` or use the action's `targets` parameter.

### 8. macOS SDK build SKIPPED

**Symptom**: `build-macos` job shows "Skipping Core+SDK build on macOS" and builds without the SDK lib.
**Cause**: This is BY DESIGN. The desktop macOS build skips the SDK because Boost compilation takes too long.
**Fix**: If you need the SDK on macOS, uncomment the SDK build step and ensure Boost 1.83 is compiled first. Alternatively, use the Linux-built artifact.

### 9. Android NDK version mismatch

**Symptom**: NDK build errors about incompatible toolchain or API level.
**Cause**: Different workflows use different NDK versions.
**Fix**: `fdroid-release` and `android-release` use `nttld/setup-ndk@v1` (r25b). `sdk-build` uses `sdkmanager --install "ndk;25.2.9519653"`. Keep these consistent.

### 10. Secret missing for release

**Symptom**: Release workflow fails with "secret not found" or authentication errors.
**Cause**: Required secrets not set in GitHub repository settings.
**Fix**: Ensure these secrets exist (check workflow for exact names):

**iOS**:
- `IOS_P12_BASE64`, `IOS_P12_PASSWORD`, `APPSTORE_ISSUER_ID`, `APPSTORE_API_KEY_ID`, `APPSTORE_API_PRIVATE_KEY`, `IOS_TEAM_ID`

**Android**:
- `ANDROID_KEYSTORE_BASE64`, `ANDROID_STORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, `MOBSF_URL`, `MOBSF_API_KEY`

**Linux**:
- `SNAP_STORE_LOGIN`

**All**:
- `DISCORD_WEBHOOK_URL`

## Adding a New Workflow

1. Create the `.yml` file in `.github/workflows/`
2. Set `FUEGO_SOURCE_BRANCH: hearth` in env
3. Set `FLUTTER_VERSION: 3.27.0` in env
4. Set `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24: true` in env
5. Include `submodules: recursive` in checkout step
6. Add Boost 1.83 installation step
7. Apply the Boost `system` removal sed patch
8. For Linux builds, apply the jsoncpp include patch
9. Use `-DBUILD_TESTS=OFF -DCMAKE_POSITION_INDEPENDENT_CODE=ON` in CMake
10. Use `GLOB_RECURSE` for core `.a` files in SDK CMake
11. Test with `workflow_dispatch: {}` before enabling push triggers

## Validating CI Changes

Before committing workflow changes:
1. Test with `workflow_dispatch` on a branch (not master)
2. Check env vars: `FUEGO_SOURCE_BRANCH`, `FLUTTER_VERSION`, `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24`
3. Verify sed commands match platform (GNU vs BSD)
4. Check path triggers are correct for the files being changed
5. Review secret usage (only reference secrets needed for the job)
6. Verify artifact names don't conflict with other workflows
7. For release workflows, test the non-release path (push/PR) first

## Resources

- [GitHub Actions documentation](https://docs.github.com/en/actions)
- [Fuego Suite repository](https://github.com/usexfg/fuego-suite)
- [Boost 1.83.0 source](https://archives.boost.io/release/1.83.0/source/)
- [Flutter 3.27 release notes](https://docs.flutter.dev/release/release-notes)
- [Vcpkg GitHub](https://github.com/Microsoft/vcpkg)
