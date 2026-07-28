# 🔥 Fuego Wallet GUI

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.22.2-blue?logo=flutter" alt="Flutter Version" />
  <img src="https://img.shields.io/badge/Dart-3.4.3-blue?logo=dart" alt="Dart Version" />
  <img src="https://img.shields.io/badge/Platform-Android%20%7C%20iOS-lightgrey" alt="Platform Support" />
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License" />
</p>

A desktop & mobile wallet app for **Fuego (XFG)** privacy cryptocurrency. 
Features include secure untraceable transactions, Fuego's new flatcoin: ΗΞΔŦ:burn XFG to mint or buy & sell on, HⲈⲆ☈ⲦН : Fuego's on-chain HEAT exchange, DeXFG atomic swaps, earn yield on ΗΞΔŦ_𝖢𝖣s, register your fire alias, built-in pool mining and more. 🔥


![](https://github.com/ColinRitman/xfg_wallet/blob/a3cc073a4ef9ab3961dde35d5ca3616a36181be3/assets/images/xfgwalletdesktopsplash.gif)


### 🔐 Advanced Security
- **PIN Authentication** with PBKDF2 secure hashing
- **Biometric Authentication** (fingerprint/Face ID)
- **AES-256-CBC Encryption** for wallet data
- **Secure Device Storage** with hardware keychain
- **25-word Mnemonic** backup / recovery 

### 💼 Wallet Management
- **Create New Wallets** with secure entropy
- **Restore from Backup** using mnemonic phrase or private keys
- **Real-time Balance Display** with privacy toggle
- **Blockchain Sync** progress tracking
- **Transaction History** with confirmation status monitoring

### 💸 Privacy Transactions
- **Send XFG** with default max privacy levels
- **Ring Signatures** (8-32 mixins for anonymity)
- **Receive with QR Codes** and integrated addresses
- **Open Alias Support** for oa1:xfg transactions 
- **Fee Estimation** and validation

### ⛏️ Built-in Mining
- **CPU Mining Controls** directly from device
- **Thread Configuration** (1-8 CPU threads)
- **Real-time Hashrate** monitoring
- **Mining Performance** tracking

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK**: 3.22.2 or higher
- **Dart SDK**: 3.4.3 or higher
- **Android Studio** / **Xcode** for platform-specific builds
- **Internet connection** to connect to Fuego network nodes

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/usexfg/fuego-flutter.git
   cd fuego-flutter
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Building for Production

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS (requires Xcode)
flutter build ios --release
```

## 🏗️ Architecture

### Project Structure
```
lib/
├── main.dart                    # App entry point
├── models/                      # Data models
├── services/                    # Business logic
│   ├── fuego_rpc_service.dart  # Fuego RPC communication
│   └── security_service.dart   # Security & encryption
├── providers/                   # State management
├── screens/                     # UI screens
│   ├── auth/                   # Authentication
│   ├── wallet_setup/           # Wallet creation/restore
│   ├── home/                   # Main dashboard
│   ├── transactions/           # Send/receive
│   ├── elderfier/              # Staking features
│   ├── messaging/              # Encrypted messaging
│   └── settings/               # Configuration
├── widgets/                     # Reusable components
└── utils/                       # Utilities & theming
```

### State Management
- **Provider Pattern** for reactive state management
- **Clean Architecture** with separation of concerns
- **Comprehensive Error Handling** throughout

### Security Implementation
- **Multi-layered Encryption** with industry standards
- **Hardware Security Integration** when available
- **Memory Protection** with automatic data clearing
- **Secure Key Derivation** and storage

## 🔧 Configuration

### Fuego Node Setup

The app connects to remote Fuego network nodes for full functionality. By default, it connects to community-maintained public nodes, but you can configure custom nodes in the app settings.

#### Default Remote Nodes
The app includes several pre-configured remote nodes:
- `207.244.247.64:18180` 
- `node1.usexfg.org`
- `node2.usexfg.org`
- `fuego.seednode1.com`
- `fuego.seednode2.com`

#### Custom Node Configuration
You can add custom nodes through the Settings > Node Connection menu, or modify the defaults in:
```dart
// lib/services/fuego_rpc_service.dart
static const List<String> defaultRemoteNodes = [
  'node1.usexfg.org',
  'node2.usexfg.org',
  // ... more nodes
];
```

#### Node Requirements
- RPC port: `18180` (default)
- Wallet RPC port: `8070`
- Must support standard CryptoNote RPC methods


## 🔒 Security Features

### Cryptographic Protection
- **AES-256-CBC** encryption for all stored wallet data
- **PBKDF2** key derivation with 100,000 iterations
- **Secure random generation** for keys and entropy
- **Hardware security module** integration when available

### Privacy Features
- **Dynamaxin** for highest possible privacy (per available decoy outputs: min 8 max 32) 
- **Subaddresses** for better transaction privacy
- **No data tracking** - all operations local

### Authentication Security
- **Multi-factor authentication** with PIN + biometric
- **Failed attempt protection** with progressive lockout
- **Secure session management** with timeout
- **Device binding** with hardware-specific keys

## 🌐 Supported Platforms

- ✅ **Android 7.0+** (API level 24+)
- ✅ **iOS 12.0+**
- 🔄 **Linux Desktop** (ready)
- 🔄 **Windows Desktop** (ready)
- 🔄 **macOS Desktop** (ready)

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run integration tests
flutter drive --target=test_driver/app.dart
```

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

### Development Setup

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and test thoroughly
4. Commit your changes: `git commit -m 'Add amazing feature'`
5. Push to the branch: `git push origin feature/amazing-feature`
6. Open a Pull Request

### Code Style

- Follow [Flutter's style guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter analyze` to check for issues
- Format code with `dart format`
- Write tests for new features

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Links

- **Fuego Website**: [https://usexfg.org](https://usexfg.org)
- **Main Repository**: [https://github.com/usexfg/fuego-suite](https://github.com/usexfg/fuego-suite) 
- **Discord**: [https://discord.gg/5UJcJJg](https://discord.gg/5UJcJJg)
- **Twitter**: [https://twitter.com/useXFG](https://twitter.com/useXFG)

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/usexfg/fuego-flutter/issues)
- **Discord**: [Fuego Community](https://discord.gg/5UJcJJg)
- **Email**: support@usexfg.org

## ⚠️ Disclaimer

This software is provided "as is" without warranty. Cryptocurrency transactions are irreversible. Always:
- **Backup your wallet** securely
- **Verify transactions** before sending
- **Use at your own risk**
- **Keep your backup phrase safe**

---

<p align="center">
  <strong> Built with 🔥 for The Fuego Mob</strong>
</p>  