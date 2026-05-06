# Fuego SDK Flutter Plugin

This Flutter plugin provides bindings to the Fuego SDK native libraries for:
- Embedded/remote node management
- Mining
- Certificates of Deposit (CD)
- Atomic swaps
- HEAT/zkSNARK/xfg-stark proofs
- Alias registration

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  fuego_sdk_flutter:
    path: ../fuego-sdk/flutter_plugin
```

## Usage

```dart
import 'package:fuego_sdk_flutter/fuego_sdk_flutter.dart';

final plugin = FuegoSDKPlugin.instance;

// Initialize
await plugin.initialize(
  dataDir: '/path/to/data',
  testnet: true,
);

// Start node
await plugin.node.start(mode: FuegoNodeMode.embedded);

// Start mining
await plugin.mining.start(walletAddress: 'fire8f...');

// Create CD
final cd = await plugin.cd.create(
  amount: 1000000000000,
  lockTime: 2592000,
  walletFile: '/path/to/wallet',
  walletPassword: 'password',
);

// Cleanup
plugin.cleanup();
```

## Platform Setup

### Android

The plugin includes pre-built ARM64 libraries. No additional setup required.

### iOS

Add to your `ios/Podfile`:

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['EXCLUDED_ARCHS[sdk=iphonesimulator*]'] = 'arm64'
    end
  end
end
```

### macOS

No additional setup required.

### Linux

Ensure you have the required dependencies:
```bash
sudo apt-get install libboost-all-dev libssl-dev libzmq3-dev
```

### Windows

Ensure Boost and OpenSSL are installed and in your PATH.

## License

GPL-3.0
