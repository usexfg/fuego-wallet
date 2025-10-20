# XF₲ Wallet iOS Development Setup Guide

This guide provides comprehensive instructions for setting up iOS development for the XF₲ Wallet Flutter application.

## Prerequisites

### 1. Development Environment
- **macOS**: macOS 12.0 or later (required for iOS development)
- **Xcode**: Version 14.0 or later
- **Flutter**: Version 3.24.0 or later
- **CocoaPods**: Latest version
- **Apple Developer Account**: Required for code signing and distribution

### 2. Required Tools Installation

```bash
# Install Xcode from App Store
# Install Flutter
curl -O https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_3.24.0-stable.zip
unzip flutter_macos_3.24.0-stable.zip
export PATH="$PATH:`pwd`/flutter/bin"

# Install CocoaPods
sudo gem install cocoapods

# Verify installation
flutter doctor
```

### 3. iOS Development Setup

```bash
# Enable iOS development
flutter config --enable-ios

# Install iOS dependencies
cd ios
pod install
cd ..

# Verify iOS setup
flutter doctor --verbose
```

## Project Configuration

### 1. Bundle Identifier
The app uses the bundle identifier: `com.fuego.fuego_wallet`

### 2. App Information
- **Display Name**: Fuego Wallet
- **Bundle Name**: fuego_wallet
- **Version**: 1.0.0+1

### 3. Required Permissions
The app requires the following permissions (configured in `ios/Runner/Info.plist`):
- Photo Library access for wallet file selection
- Documents folder access
- Desktop folder access
- Downloads folder access

## Code Signing Setup

### 1. Apple Developer Account Setup
1. Create an Apple Developer account at [developer.apple.com](https://developer.apple.com)
2. Enroll in the Apple Developer Program ($99/year)

### 2. Certificates and Provisioning Profiles

#### Development Certificate
```bash
# Open Keychain Access
# Request certificate from Certificate Authority
# Download and install the certificate
```

#### Distribution Certificate
```bash
# Create distribution certificate in Apple Developer Portal
# Download and install the certificate
```

#### Provisioning Profiles
1. Create App ID in Apple Developer Portal
2. Create Development Provisioning Profile
3. Create Distribution Provisioning Profile
4. Download and install profiles

### 3. Xcode Configuration
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner project
3. Go to Signing & Capabilities
4. Configure Team and Bundle Identifier
5. Select appropriate provisioning profile

## GitHub Actions Secrets

Configure the following secrets in your GitHub repository:

### Required Secrets
- `IOS_P12_BASE64`: Base64 encoded P12 certificate file
- `IOS_P12_PASSWORD`: Password for the P12 certificate
- `IOS_TEAM_ID`: Apple Developer Team ID
- `APPSTORE_ISSUER_ID`: App Store Connect API Issuer ID
- `APPSTORE_API_KEY_ID`: App Store Connect API Key ID
- `APPSTORE_API_PRIVATE_KEY`: App Store Connect API Private Key

### Optional Secrets
- `DISCORD_WEBHOOK_URL`: Discord webhook for notifications

## Development Workflow

### 1. Local Development
```bash
# Run on iOS Simulator
flutter run -d ios

# Run on physical device
flutter run -d ios --release

# Build for iOS
flutter build ios --release
```

### 2. Testing
```bash
# Run tests
flutter test

# Run integration tests
flutter test integration_test/

# Analyze code
flutter analyze
```

### 3. Building for Distribution
```bash
# Build release version
flutter build ios --release

# Archive in Xcode
# Product → Archive
```

## CI/CD Pipeline

### 1. Automated Builds
The GitHub Actions workflow automatically:
- Builds the iOS app on macOS runners
- Runs tests and code analysis
- Creates signed IPA files
- Uploads to TestFlight (optional)
- Uploads to App Store (optional)

### 2. Workflow Triggers
- **Push to main/master**: Builds and tests
- **Pull Request**: Builds and tests
- **Release**: Full build, test, and distribution
- **Manual Dispatch**: Custom build options

### 3. Build Artifacts
- iOS IPA file
- Code coverage reports
- Security scan results

## Testing and Validation

### 1. Unit Tests
```bash
flutter test
```

### 2. Widget Tests
```bash
flutter test test/widget_test.dart
```

### 3. Integration Tests
```bash
flutter test integration_test/
```

### 4. Device Testing
- Test on various iOS devices
- Test on different iOS versions
- Test with different screen sizes

## Distribution

### 1. TestFlight
- Upload IPA to TestFlight for beta testing
- Manage test groups and builds
- Collect feedback and crash reports

### 2. App Store
- Submit for App Store review
- Manage app metadata and screenshots
- Handle app updates and releases

### 3. Enterprise Distribution
- For internal distribution
- Requires Enterprise Developer Program

## Troubleshooting

### Common Issues

#### 1. Code Signing Issues
```bash
# Clean and rebuild
flutter clean
cd ios
pod install
cd ..
flutter build ios --release
```

#### 2. Pod Installation Issues
```bash
# Update CocoaPods
sudo gem install cocoapods
cd ios
pod repo update
pod install
```

#### 3. Xcode Build Issues
- Clean build folder in Xcode
- Reset package caches
- Check provisioning profiles

#### 4. Flutter Issues
```bash
# Clean Flutter
flutter clean
flutter pub get
flutter doctor
```

### Debug Commands
```bash
# Check Flutter doctor
flutter doctor -v

# Check iOS setup
flutter doctor --android-licenses

# Check dependencies
flutter pub deps

# Analyze code
flutter analyze --verbose
```

## Security Considerations

### 1. Code Signing
- Always use proper certificates
- Keep private keys secure
- Rotate certificates regularly

### 2. App Transport Security
- Configure ATS in Info.plist
- Use HTTPS for all network requests
- Handle certificate pinning if needed

### 3. Data Protection
- Use Keychain for sensitive data
- Implement proper encryption
- Follow iOS security guidelines

## Performance Optimization

### 1. Build Optimization
- Use release builds for performance testing
- Profile app performance
- Optimize asset sizes

### 2. Memory Management
- Monitor memory usage
- Fix memory leaks
- Optimize image loading

### 3. Battery Usage
- Minimize background processing
- Optimize network requests
- Use efficient algorithms

## Monitoring and Analytics

### 1. Crash Reporting
- Integrate crash reporting (e.g., Firebase Crashlytics)
- Monitor crash rates
- Fix critical issues quickly

### 2. Performance Monitoring
- Monitor app performance
- Track user engagement
- Analyze usage patterns

### 3. App Store Analytics
- Monitor download metrics
- Track user ratings
- Analyze user feedback

## Maintenance

### 1. Regular Updates
- Keep Flutter SDK updated
- Update dependencies regularly
- Test on latest iOS versions

### 2. Security Updates
- Apply security patches
- Update certificates
- Review third-party dependencies

### 3. Performance Monitoring
- Regular performance testing
- Monitor app metrics
- Optimize based on data

## Support and Resources

### 1. Documentation
- [Flutter iOS Documentation](https://docs.flutter.dev/deployment/ios)
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [Xcode Documentation](https://developer.apple.com/documentation/xcode)

### 2. Community
- [Flutter Community](https://flutter.dev/community)
- [Stack Overflow](https://stackoverflow.com/questions/tagged/flutter)
- [GitHub Issues](https://github.com/flutter/flutter/issues)

### 3. Tools
- [Flutter Inspector](https://docs.flutter.dev/development/tools/flutter-inspector)
- [Xcode Instruments](https://developer.apple.com/documentation/xcode/instruments)
- [App Store Connect](https://appstoreconnect.apple.com/)

## Conclusion

This setup guide provides everything needed to develop, test, and distribute the XF₲ Wallet iOS application. Follow the steps carefully and refer to the troubleshooting section if you encounter any issues.

For additional support, please refer to the project's GitHub repository or contact the development team.