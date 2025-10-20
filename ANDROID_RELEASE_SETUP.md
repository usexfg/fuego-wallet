# XF₲ Wallet Android Release Setup Guide

This guide explains how to set up the complete Android release workflow for the XF₲ Wallet, including signed builds, Play Store uploads, and automated releases.

## Overview

The Android release workflow includes:
- ✅ Signed APK and AAB builds
- ✅ Automated testing and code analysis
- ✅ Security scanning with MobSF
- ✅ Play Store upload integration
- ✅ GitHub Releases with artifacts
- ✅ Discord notifications
- ✅ Manual workflow dispatch

## Prerequisites

### 1. Android Keystore Setup

First, you need to create an Android keystore for signing your release builds:

```bash
# Create a new keystore
keytool -genkey -v -keystore android-release-key.keystore -alias fuego-wallet-key -keyalg RSA -keysize 2048 -validity 10000

# Follow the prompts to set:
# - Keystore password
# - Key password
# - Your name, organization, city, state, country code
```

### 2. GitHub Secrets Configuration

Add the following secrets to your GitHub repository (Settings → Secrets and variables → Actions):

#### Required Secrets:
- `ANDROID_KEYSTORE_BASE64`: Base64 encoded keystore file
  ```bash
  base64 -i android-release-key.keystore | pbcopy
  ```
- `ANDROID_STORE_PASSWORD`: Keystore password
- `ANDROID_KEY_ALIAS`: Key alias (e.g., `fuego-wallet-key`)
- `ANDROID_KEY_PASSWORD`: Key password

#### Optional Secrets (for Play Store upload):
- `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`: Service account JSON for Play Console API
- `DISCORD_WEBHOOK_URL`: Discord webhook for release notifications
- `MOBSF_URL`: MobSF server URL for security scanning
- `MOBSF_API_KEY`: MobSF API key

### 3. Google Play Console Setup (Optional)

To enable automatic Play Store uploads:

1. Go to [Google Play Console](https://play.google.com/console)
2. Navigate to Setup → API access
3. Create a new service account
4. Download the JSON key file
5. Add the service account to your app with "Release Manager" permissions
6. Add the JSON content as `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` secret

## Workflow Triggers

The Android release workflow is triggered by:

1. **Push to main/master**: Builds debug APK for testing
2. **Pull Request**: Builds debug APK for testing
3. **Release published**: Builds signed APK/AAB and uploads to GitHub Releases
4. **Manual dispatch**: Allows manual triggering with options for build type and Play Store upload

## Workflow Features

### Build Process
- **Java 17** setup with Temurin distribution
- **Flutter 3.24.0** with stable channel
- **Android SDK** configuration
- **xfg-stark-cli** binary download and integration
- **Dependency installation** with `flutter pub get`
- **Code analysis** with `flutter analyze`
- **Test execution** with `flutter test`

### Signing Process
- **Keystore setup** from GitHub Secrets
- **APK signing** with apksigner
- **Signature verification** to ensure proper signing
- **AAB building** for Play Store distribution

### Security Features
- **MobSF security scanning** for APK analysis
- **ProGuard obfuscation** for release builds
- **Code analysis** and testing before release

### Distribution
- **GitHub Releases** with APK and AAB artifacts
- **Play Store upload** (optional, configurable)
- **Discord notifications** for release announcements
- **Release summaries** with build status and download links

## File Structure

```
.github/workflows/
├── android-release.yml          # Main Android workflow
└── flutter-desktop.yml          # Desktop builds

android/
├── app/
│   ├── build.gradle            # Updated with signing config
│   └── proguard-rules.pro      # ProGuard rules for optimization
└── key.properties              # Generated during workflow (not committed)

ANDROID_RELEASE_SETUP.md        # This documentation
```

## Usage Examples

### Manual Release
1. Go to Actions → XF₲ Wallet Android Build & Release
2. Click "Run workflow"
3. Select build type (release/debug)
4. Choose whether to upload to Play Store
5. Click "Run workflow"

### Automatic Release
1. Create a new release tag:
   ```bash
   git tag v1.0.0
   git push origin v1.0.0
   ```
2. Go to GitHub → Releases
3. Click "Create a new release"
4. Select the tag and publish
5. The workflow will automatically build and upload signed artifacts

### Debug Build
1. Push to main/master branch
2. The workflow will build a debug APK
3. Download from the Actions artifacts

## Troubleshooting

### Common Issues

1. **Keystore not found**: Ensure `ANDROID_KEYSTORE_BASE64` secret is properly set
2. **Signing failed**: Check that all keystore-related secrets are correct
3. **Play Store upload failed**: Verify `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` has correct permissions
4. **Build fails**: Check Flutter and Android SDK versions in the workflow

### Debug Steps

1. Check the Actions logs for detailed error messages
2. Verify all required secrets are set
3. Test the keystore locally:
   ```bash
   # Test keystore
   keytool -list -v -keystore android-release-key.keystore
   ```

## Security Considerations

- **Never commit keystore files** to the repository
- **Use strong passwords** for keystore and key
- **Rotate keys periodically** for security
- **Limit secret access** to necessary workflows only
- **Monitor workflow runs** for unauthorized access

## Maintenance

### Regular Tasks
- Update Flutter version in workflow when needed
- Rotate keystore passwords annually
- Update ProGuard rules as the app evolves
- Monitor security scan results

### Updates
- The workflow uses Flutter 3.24.0 - update as needed
- Android SDK versions are managed by the Flutter action
- Dependencies are updated via `flutter pub upgrade`

## Support

For issues with the Android release workflow:
1. Check the GitHub Actions logs
2. Verify all secrets are correctly set
3. Test the build process locally
4. Review this documentation for setup steps

The workflow is designed to be robust and handle most common scenarios automatically, but proper setup of secrets and keystore is essential for success.
