#!/bin/bash

# Bundle macOS daemon dependencies into the app.
#
# The xfgo C++ daemons (fuegod, unified, xfg-swapd) link against homebrew
# dylibs at absolute paths (/opt/homebrew/opt/...). End users do not have
# those paths — without this step every C++ daemon dies with "Library not
# loaded" on a clean machine.
#
# Usage: bundle-macos-dylibs.sh <app_bundle_dir>
#
# Relocates all homebrew dylib references into Contents/Frameworks and
# re-signs everything (install_name_tool invalidates signatures).

set -euo pipefail

APP="${1:?usage: bundle-macos-dylibs.sh <app_bundle_dir>}"
BIN_DIR="$APP/Contents/MacOS"
FW_DIR="$APP/Contents/Frameworks"
mkdir -p "$FW_DIR"

DAEMONS=("$BIN_DIR/fuegod" "$BIN_DIR/unified" "$BIN_DIR/xfg-swapd")

for bin in "${DAEMONS[@]}"; do
    [ -f "$bin" ] || continue

    # 1. Copy every homebrew dylib the daemon references and rewrite the
    #    load command to the bundle-relative path.
    otool -L "$bin" | grep -o '/opt/homebrew/[^ ]*\.dylib' | sort -u | while read -r dylib; do
        name="$(basename "$dylib")"
        [ -f "$FW_DIR/$name" ] || cp "$dylib" "$FW_DIR/"
        install_name_tool -change "$dylib" "@executable_path/../Frameworks/$name" "$bin"
    done

    # 2. Re-sign the daemon (step 1 invalidated its signature).
    codesign --force --sign - "$bin" >/dev/null 2>&1 || true
done

# 3. Fix dylib-internal references (boost libs reference each other,
#    openssl/icu reference nothing homebrew) and re-sign each dylib.
for dylib in "$FW_DIR"/*.dylib; do
    [ -f "$dylib" ] || continue
    otool -L "$dylib" | grep -o '/opt/homebrew/[^ ]*\.dylib' | sort -u | while read -r ref; do
        install_name_tool -change "$ref" "@loader_path/$(basename "$ref")" "$dylib"
    done
    install_name_tool -id "@loader_path/$(basename "$dylib")" "$dylib"
    codesign --force --sign - "$dylib" >/dev/null 2>&1 || true
done

echo "Bundled $(ls "$FW_DIR" | wc -l | tr -d ' ') dylibs into $FW_DIR"
