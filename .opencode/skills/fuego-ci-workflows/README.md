# Fuego Wallet CI Workflows

Expert knowledge base for managing the Fuego Wallet CI/CD pipeline — 6 GitHub Actions workflows building across 6 platforms with an embedded blockchain SDK.

## Usage

Load this skill when working with any CI workflow or build configuration:

```
.opencode/skills/fuego-ci-workflows/SKILL.md
```

### When to Use

- Diagnose CI build failures (Boost, vcpkg, Flutter, code signing)
- Modify existing workflows or add new ones
- Configure release secrets for App Store / Play Store / Snapcraft
- Update the fuego-suite submodule or Boost version
- Debug platform-specific issues (macOS sed, Linux jsoncpp, Windows vcpkg)

## Quick Reference

| Workflow | Platforms | Output | Release Target |
|----------|-----------|--------|----------------|
| `desktop-build.yml` | macOS, Windows, Linux | .zip, .zip, .tar.gz | GitHub Releases |
| `linux-appstore-release.yml` | Snap, Flatpak, AppImage | .snap, .flatpak, .AppImage | Snap Store, Flathub |
| `ios-release.yml` | iOS | .ipa | TestFlight, App Store |
| `android-release.yml` | Android | .apk, .aab | Google Play |
| `fdroid-release.yml` | F-Droid | .apk (unsigned) | F-Droid |
| `sdk-build.yml` | Linux, macOS, Windows, Android, iOS | SDK install | Artifacts only |

## Critical Constraints

- **Boost ≤1.83**: Required by `hearth` branch's `io_service` API. macOS builds from source; Linux uses `libboost1.83-dev`.
- **Branch `hearth`**: All workflows clone `fuego-suite` at the `hearth` branch.
- **Flutter 3.27.0**: All workflows except `sdk-build.yml` (3.19.0).
- **sed portability**: GNU sed on Linux (`-i`), BSD sed on macOS (`-i ''`).
- **jsoncpp patch**: Ubuntu needs `#include <jsoncpp/json.h>` not `<json/json.h>`.

## Common Fixes

```
# Boost "io_service" not found → Install Boost 1.83
# sed "invalid flag" → Use sed -i '' on macOS
# json/json.h not found → Apply jsoncpp sed patch
# vcpkg fails → Re-bootstrap vcpkg
# Flutter API deprecations → Replace initialValue/activeThumbColor
```

## Files

```
.opencode/skills/fuego-ci-workflows/
├── SKILL.md                  # Main skill — triggers, workflows, failure modes
├── README.md                 # This file
├── references/
│   └── detailed-guide.md     # Extended reference (arch details, secrets, CMake flags)
├── examples/                 # (empty)
└── scripts/                  # (empty)
```
