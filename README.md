# Fuego's 🔥WinterFire❄️ Wallet   
## Fuego XFG wallet with support for HEAT + C0LD assets


![](https://github.com/ColinRitman/xfg_wallet/blob/a3cc073a4ef9ab3961dde35d5ca3616a36181be3/assets/images/xfgwalletdesktopsplash.gif)


## ⚡ Quick Start (2 Minutes)

```bash
# 1. Get the repository
git clone https://github.com/usexfg/fuego-wallet.git
cd fuego-wallet

# 2. Install Flutter dependencies
flutter pub get

# 3. Download required binaries
./scripts/ensure-binaries.sh

# 4. Build walletd 
./scripts/get_walletd_binary.sh build

# 5. Run the wallet
flutter run -d linux  # or macos, windows, android, ios
```

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
