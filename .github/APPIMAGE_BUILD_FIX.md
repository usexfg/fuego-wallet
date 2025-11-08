# AppImage Build Fix Documentation

## Issue Summary

The Linux GLIBC 2.35 AppImage build was failing with the following error:

```
cp: cannot stat '../../../../app_icon_256.png': No such file or directory
```

## Root Cause

The AppImage creation step in the GitHub Actions workflow had an incorrect relative path to the icon file. The script was running from `build/linux/x64/release/bundle` and trying to access `../../../../app_icon_256.png`, but the correct path requires going up 5 directory levels, not 4.

### Path Analysis

- **Working Directory**: `build/linux/x64/release/bundle`
- **Target File**: `app_icon_256.png` (at project root)
- **Incorrect Path**: `../../../../app_icon_256.png` (4 levels up)
- **Correct Path**: `../../../../../app_icon_256.png` (5 levels up)

### Directory Structure

```
firefly-wallet-official/          ← Project root (where app_icon_256.png is)
├── app_icon_256.png              ← Target file
├── build/
│   └── linux/
│       └── x64/
│           └── release/
│               └── bundle/       ← Current working directory
```

## Changes Made

### 1. Fixed Icon Path (`.github/workflows/xfg-wallet-desktop.yml`)

**Before:**
```yaml
cp ../../../../app_icon_256.png fuego_wallet.png
```

**After:**
```yaml
cp ../../../../../app_icon_256.png fuego_wallet.png
```

### 2. Added Error Handling and Fallback

The updated workflow now includes:

- **File existence check** before copying
- **Fallback location** check (assets/icons/)
- **Error message** if icon not found
- **Exit with error** if all locations fail

```bash
if [ -f ../../../../../app_icon_256.png ]; then
  cp ../../../../../app_icon_256.png fuego_wallet.png
else
  echo "Warning: app_icon_256.png not found, checking alternate locations..."
  if [ -f ../../../../../assets/icons/app_icon_256.png ]; then
    cp ../../../../../assets/icons/app_icon_256.png fuego_wallet.png
  else
    echo "Error: Icon file not found!"
    exit 1
  fi
fi
```

### 3. Created Dedicated Desktop File

Created `linux/xfg-wallet.desktop` with proper formatting:

```desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=XF₲ Wallet
GenericName=Cryptocurrency Wallet
Comment=Privacy-focused cryptocurrency wallet for XF₲
Exec=fuego_wallet
Icon=fuego_wallet
Terminal=false
Categories=Finance;Network;
Keywords=cryptocurrency;wallet;privacy;fuego;xfg;
StartupWMClass=fuego_wallet
StartupNotify=true
```

### 4. Fixed Desktop File Generation

The workflow now:
1. Attempts to copy the dedicated desktop file from `linux/xfg-wallet.desktop`
2. Falls back to generating one inline if the file doesn't exist
3. Properly formats the inline desktop file (previous version had malformed EOF)

## Verification

### Local Testing

To verify the path is correct:

```bash
cd firefly-wallet-official
mkdir -p build/linux/x64/release/bundle
cd build/linux/x64/release/bundle
ls -la ../../../../../app_icon_256.png
```

Expected output: File should be found and displayed.

### CI/CD Testing

The workflow will now:
1. ✅ Find the icon file at the correct path
2. ✅ Copy it to the bundle directory as `fuego_wallet.png`
3. ✅ Create or copy a properly formatted desktop file
4. ✅ Successfully create the AppImage with icon and metadata

## Additional Improvements

### Desktop File Quality

The new desktop file includes:
- **Version**: Specifies Desktop Entry version 1.0
- **GenericName**: Helps with categorization
- **Keywords**: Improves searchability
- **StartupWMClass**: Proper window management
- **StartupNotify**: Visual feedback on launch
- **Terminal=false**: GUI application indicator

### Error Handling

The workflow now provides clear error messages:
- Warns when primary location fails
- Lists alternate locations checked
- Exits with error code if all locations fail
- Makes debugging easier for future issues

## Files Modified

1. **`.github/workflows/xfg-wallet-desktop.yml`**
   - Fixed icon path from 4 to 5 directory levels
   - Added error handling and fallback logic
   - Improved desktop file generation
   - Better inline documentation

2. **`linux/xfg-wallet.desktop`** (New File)
   - Created dedicated desktop entry file
   - Follows FreeDesktop.org standards
   - Includes all recommended fields

## Testing Checklist

Before merging, verify:

- [ ] Icon file exists at project root: `app_icon_256.png`
- [ ] Desktop file exists at: `linux/xfg-wallet.desktop`
- [ ] Path calculation is correct (5 levels up from bundle)
- [ ] CI/CD build completes successfully
- [ ] AppImage is created with icon
- [ ] AppImage shows proper metadata when inspected

## Future Recommendations

### Option 1: Use Absolute Path (Safer)
Instead of relative paths, use `$GITHUB_WORKSPACE`:

```bash
cp $GITHUB_WORKSPACE/app_icon_256.png fuego_wallet.png
```

### Option 2: Copy Icon During Build
Add icon to bundle during Flutter build:

```yaml
- name: Copy icon to bundle
  run: |
    cp app_icon_256.png build/linux/x64/release/bundle/fuego_wallet.png
```

### Option 3: Include in Assets
Add icon to Flutter assets and reference from there:

```yaml
flutter:
  assets:
    - app_icon_256.png
```

## Related Issues

- Previous GLIBC error was unrelated (system library compatibility)
- This fix addresses only the AppImage icon/desktop file issue
- GLIBC compatibility is handled by the tar.gz artifacts

## Status

- **Fixed**: 2024-11-08
- **Tested**: Path verified locally
- **Ready**: For CI/CD deployment
- **Workflow**: `xfg-wallet-desktop.yml`
- **Job**: `build-linux-compat` (GLIBC 2.35)

## Contact

For issues or questions about this fix, refer to:
- Build logs in GitHub Actions
- `BUILD_FIX_SUMMARY.md` - Dart compilation fixes
- `LINUX_BUILD_FIXED.md` - General Linux build reference