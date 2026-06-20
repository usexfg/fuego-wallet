# Fuego's 🔥WinterFire❄️ Wallet   
## Fuego XFG wallet with support for HEAT + C0LD assets


![](https://github.com/ColinRitman/xfg_wallet/blob/a3cc073a4ef9ab3961dde35d5ca3616a36181be3/assets/images/xfgwalletdesktopsplash.gif)


## ⚡ Quick Start (2 Minutes)

```bash
# 1. Get the repository
# Use fuego-suite master branch for latest fixes
git clone https://github.com/usexfg/fuego-suite.git fuego-core
# OR with submodule init
git clone --recurse-submodules https://github.com/usexfg/fuego-wallet.git

# 2. Install Flutter dependencies
flutter pub get

# 3. Download required binaries
./scripts/ensure-binaries.sh

# 4. Build walletd (from fuego-wallet repository)
./scripts/get_walletd_binary.sh build

# 5. Run the wallet
flutter run -d linux  # or macos, windows, android, ios
```

---

## 📝 Build Notes

### SDK & Native Components

The project includes **multiple build targets** across platforms:

#### 1. Flutter App (Primary)
- **Platforms**: Linux, macOS, Windows, Android, iOS
- **Build command**: `flutter build <platform> --release`
- **Dependencies**: Native SDK binaries (libfuego_sdk, fuego_crypto)
- **Features**: UI, HTTP RPC fallback, user wallet management

#### 2. Native SDK (`fuego-sdk/dart`)
- **Platforms**: Linux, macOS, Windows (x64)
- **Build command**: `cargo build --release --target x86_64-unknown-linux-gnu` (Linux)
- **Dependencies**: Rust crypto library, C++ node libraries (from fuego-core)
- **Purpose**: Provides native functions accessible via Flutter FFI

#### 3. Fuego Core Node (fuego-core)
- **Platform**: Linux (primary), can be built on macOS/Windows
- **Status**: Currently building from `hearth` branch; consider updating to `master` to avoid C++ compilation issues (e.g., formatAmount ambiguity)
- **Dependencies**: Boost libraries, C++ dependencies
- **Key Components**: Node, mining, atomic swaps, CD service, alias registration

#### 4. Rust Crypto Library (`native/crypto`)
- **Purpose**: Security and cryptographic primitives for the SDK
- **Platforms**: Linux, macOS, Windows
- **Build command**: `cargo build --release --target <platform>`

### 🔑 Repository Structure

The wallet repository includes separate components with different roles:

```
fuego-wallet/
├── lib/                    ← Flutter application
├── fuego-sdk/              ← Native SDK (requires `fuego-core`)
├── fuego-core/             ← Native blockchain node (upstream repo)
├── native/crypto/          ← Rust crypto library
└── scripts/                ← Build and binary management
```

### ⚠️ Known Issues

#### Current Focus: Flutter App Build ✅
- All 3 desktop platforms (macOS, Linux, Windows) build successfully
- The Flutter app validates all Dart code compiles
- Native SDK builds are optional for CI validation

#### Deferred: Native SDK Build ❌

The **fuego-core** native node build is currently deferred due to upstream compilation issues:

1. **formatAmount ambiguity** in SimpleWallet.cpp (multiple overloads for same type)
2. **Boost compilation** from source takes 30+ minutes
3. **Complex C++ dependencies** requiring platform-specific setup

**Decision**: Build the Flutter app independently of native SDK
- Rely on HTTP RPC fallback when native SDK unavailable
- Pre-built native SDK binaries can be added later from fuego-suite releases
- Focus development and CI on the Flutter layer (user interface)

### 🔄 Build Order

#### Option 1: Current Path (Recommended)

```bash
# Step 1: Clone fuego-core first (dependency)
.gitmodules/init
git submodule update --init --recursive

# Step 2: Build Flutter app (works standalone)
flutter pub get
flutter build macos --release  # Test on macOS first
```

#### Option 2: Full Native Integration (Future)

```bash
# Step 1: Build native components
./scripts/get_walletd_binary.sh build  # Build walletd
cargo build --release               # Build Rust crypto
# (fuego-core build requires manual setup)

# Step 2: Build Flutter with native SDK
flutter pub get
flutter build linux --release
```

### 📋 Next Steps

#### Short Term (Next Sprint)
1. ✅ Validate Flutter build across 3 platforms
2. ✅ Document HTTP RPC fallback for when native SDK unavailable
3. ✅ Create scripts to extract native SDK binaries from pre-built releases

#### Medium Term (Phase 2)
1. Investigate fixing upstream `formatAmount` ambiguity in fuego-core
2. Update build process to use `fuego-suite master` branch instead of `hearth`
3. Develop documentation for local native SDK setup

#### Long Term (Future Features)
1. Native SDK integration for full feature parity
2. CI validation of complete end-to-end flow
3. Cross-platform deployment scripts

---

## 🚀 New Features

### 1. **Ξternal Flame** 
Burn XFG to mint Fuego Ξmbers (HEAT) on Ethereum L1
- **Standard Burn:** 0.8 XFG → 8 Million HEAT
- **Large Burn:** 800 XFG → 8 Billion HEAT
- **zkSTARK Proofs:** Local generation or via walletd

### 2. **COLD Interest Lounge** (Formerly COLD Banking)
Manage COLD tokens on Ethereum with C0DL3 interest
- **Web3 Connection:** Direct to Ethereum mainnet
- **Balance Tracking:** Real-time COLD token balance
- **C0DL3 Interest:** Track earnings in HEAT tokens
- **Token Transfer:** Send COLD to any address

---

## 📁 Project Structure

```
fuego-wallet/
├── lib/
│   ├── services/
│   │   ├── walletd_service.dart       ← NEW: Walletd/Optimizer integration
│   │   └── web3_cold_service.dart     ← NEW: Ethereum Web3 for COLD
│   ├── screens/
│   │   ├── banking/
│   │   │   └── banking_screen.dart    ← UPDATED: Ξternal Flame + COLD tabs
│   │   ├── main/
│   │   │   └── main_screen.dart       ← UPDATED: Navigation with HEAT+
│   │   └── home/
│   │       └── home_screen.dart       ← UPDATED: Service status
│   └── utils/
│       └── theme.dart                 ← UPDATED: New colors
├── assets/
│   ├── bin/
│   │   ├── xfg-stark-cli-linux       ← Burn proofs
│   │   ├── xfg-stark-cli-macos
│   │   └── xfg-stark-cli-windows.exe
│   └── fonts/                        ← Monospace for logs
├── scripts/
│   ├── ensure-binaries.sh            ← Download CLI
│   └── get_walletd_binary.sh         ← Build/download walletd
├── pubspec.yaml                      ← Added web3dart
├── README.md                         ← THIS FILE
├── INTEGRATION_CHANGES.md            ← Full documentation
├── IMPLEMENTATION_SUMMARY.md         ← Technical details
├── FINAL_SUMMARY.md                  ← Complete overview
└── CHECKLIST.md                      ← User testing guide
```

## ⚙️ How It Works

### Flow 1: XFG Ξthereal Mint  (Burn → Mint)
```
User selects burn amount
        ↓
Starts walletd (if integrated mode)
        ↓
Optimizer runs (auto-deposit, auto-optimize)
        ↓
Generates STARK proof (xfg-stark-cli or walletd)
        ↓
Navigate to Burn Deposits screen
        ↓
Submit burn → Mint HEAT on Ethereum L1
```

### Flow 2: COLD Interest Lounge
```
User enters COLD address
        ↓
Click Connect Web3
        ↓
Connects to Ethereum (Infura/Alchemy/public)
        ↓
Fetches COLD balance
        ↓
Displays C0DL3 interest info
        ↓
Can start walletd for batch operations
        ↓
Track HEAT earnings
```

---

## 📦 Dependencies Added

```yaml
dependencies:
  web3dart: ^2.7.2           # Ethereum Web3 integration
  http: ^1.2.0               # API calls
  logging: ^1.2.0            # Service logs
  flutter_screenutil: ^5.9.0 # Responsive UI
  flutter_svg: ^2.0.10       # Icons
  path: ^1.8.3               # Binary paths
  path_provider: ^2.1.2      # App directories
  shared_preferences: ^2.2.2 # Config cache
```

## 📋 Required Binaries

### 1. xfg-stark-cli (Required for burns)
Already handled by `scripts/ensure-binaries.sh`
- `xfg-stark-cli-linux`
- `xfg-stark-cli-macos`
- `xfg-stark-cli-windows.exe`

### 2. fuego-walletd (For integrated mode)
**Must be built or downloaded:**
```bash
# Download pre-built (if available)
./scripts/get_walletd_binary.sh download

# OR build from source
./scripts/get_walletd_binary.sh build
```

**Platform binaries:**
- `fuego-walletd-linux-x86_64` (or arm64)
- `fuego-walletd-macos-x86_64` / `fuego-walletd-macos-arm64`
- `fuego-walletd-windows.exe`

---

## 🔥 Using the Wallet

### Start Walletd from GUI
1. Navigate to Banking → Ξthereal Mint or COLD
2. Toggle walletd integration ON
3. Wait for green status indicator
4. Use optimizer controls
5. View real-time logs

### Connect Web3 (COLD)
1. Navigate to Banking → COLD tab
2. Enter COLD address (0x...)
3. Click "Connect Web3"
4. View balance and interest
5. Uses public RPC endpoints (demo keys)

### Burn XFG → Mint HEAT
1. Go to Banking → Ξternal Flame
2. Select burn amount (Standard or Large)
3. Toggle walletd if available
4. Click "Burn XFG & Mint HEAT"
5. Follow Burn Deposits screen
6. Get STARK proof
7. HEAT minted on Ethereum L1

---

## 🎯 Service Status Indicators

| Service | 🟢 Running | ⚪ Stopped | ⚫ Not Available |
|---------|-----------|-----------|-----------------|
| walletd | Integrated mode active | Ready to start | Binary missing |
| optimizer | Auto-optimizing | Available | Try walletd integrated |
| xfg-stark-cli | Ready for burns | CLI fallback | Download binaries |
| Web3 (COLD) | Ethereum connected | Disconnected | No internet? |

---

## 🛠️ Troubleshooting

### "walletd binary not found"
```bash
./scripts/get_walletd_binary.sh build
# OR download if available
```

### "Web3 connection failed"
- Check internet connection
- Verify COLD address format (0x...)
- Try refresh or different RPC
- Public endpoints may be rate-limited

### "Optimizer won't start"
- Start walletd first
- Check port 8070 availability
- Review UI logs for specific errors

### "No COLD balance"
- Verify address has COLD tokens on Ethereum
- Wait for RPC response (may be slow)
- Check Web3 activity log
- Confirm tokens exist at address

### Mobile build issues
- Services may not run in background
- Desktop is primary target
- Web3 works on mobile for balance checks


## 🤝 Contributing

See `CONTRIBUTING.md` for development guidelines.

---

## 📄 License

MIT License - Free to use and modify for the Fuego ecosystem.

---

## 📞 Support

- GitHub Issues: For bugs and features
- Documentation: Check files in `/docs`
- Community: Join Fuego channels

---

**Built with ❤️‍🔥 for the Fuego ecosystem**  
