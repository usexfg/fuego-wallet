# XF₲ Wallet Integration Changes
## Walletd & Web3 COLD Token Integration

### 📋 Table of Contents
1. [Overview](#overview)
2. [Navigation Renaming](#navigation-renaming)
3. [Walletd Integration](#walletd-integration)
4. [Web3 COLD Service](#web3-cold-service)
5. [Updated Screens](#updated-screens)
6. [Quick Start](#quick-start)
7. [Technical Details](#technical-details)

---

### Overview

This document describes the integration of `walletd` and `fuego-optimizer` directly into the GUI wallet, along with the renaming of Burn2Mint and COLD Banking sections. This creates a self-contained wallet experience similar to how GUI wallets can compile these components.

**Key Changes:**
- ✅ Integrated walletd and optimizer into GUI (no separate services needed)
- ✅ Renamed "Burn2Mint" → "Ξternal Flame" (HEAT section)
- ✅ Renamed "COLD Banking" → "COLD Interest Lounge"
- ✅ Added Web3 connection for COLD token on Ethereum
- ✅ Real-time service monitoring and logs in UI
- ✅ Unified banking experience with integrated services

---

### Navigation Renaming

#### Before → After Mapping:

| Old Name | New Name | Purpose |
|----------|----------|---------|
| Burn2Mint | **Ξternal Flame** | Burn XFG to mint HEAT |
| COLD Banking | **COLD Interest Lounge** | COLD token + C0DL3 interest |

#### Updated Navigation Structure:
```
Home
Messages
Banking
  ├── Ξternal Flame [NEW]
  │   ├── Burn options (Standard: 0.8 XFG → 8M HEAT, Large: 800 XFG → 8B HEAT)
  │   ├── Walletd integration toggle
  │   └── Integrated optimizer controls
  └── COLD [NEW]
      ├── Web3 Ethereum connection
      ├── COLD balance display
      ├── C0DL3 interest tracking
      └── Service controls (walletd + optimizer)
Settings
Elderfiers
```

---

### Walletd Integration

#### New Service: `lib/services/walletd_service.dart`

**What it does:**
- Manages `fuego-walletd` (PaymentGateService) process
- Manages `fuego-optimizer` process (via walletd or standalone)
- Provides JSON-RPC interface on port 8070
- Real-time log streaming to UI
- Process monitoring and restart capabilities

**Integration Modes:**

1. **Integrated Mode** (GUI)
   ```dart
   await WalletdService.instance.startWalletd(
     enableRpc: true,
     daemonAddress: 'localhost:8081',
   );
   ```

2. **Optimizer via RPC** (Integrated into walletd)
   ```dart
   await WalletdService.instance.startOptimizer(
     autoOptimize: true,
     scanInterval: 300,
   );
   ```

3. **Standalone Fallback** (if separate binary exists)
   ```dart
   // Uses fuego-optimizer.exe if available
   await WalletdService.instance.startOptimizer(
     walletdIp: '127.0.0.1',
     walletdPort: 8070,
   );
   ```

**Key Features:**
- **Binary Management**: Automatically extracts platform-specific binaries
- **Status Tracking**: UI shows running/stopped status with indicators
- **Log Streaming**: Real-time output from both services
- **Process Control**: Start/stop with graceful shutdown
- **RPC Commands**: Optimize, check status, get version
- **Fallback Handling**: Gracefully degrades to CLI if binaries missing

**Platform Support:**
- Linux: `fuego-walletd-linux-x86_64` (or arm64)
- macOS: `fuego-walletd-macos-x86_64` / `fuego-walletd-macos-arm64`
- Windows: `fuego-walletd-windows.exe`

**Requirements:**
```bash
# Run this to ensure binaries are available
./scripts/ensure-binaries.sh
# OR build walletd from source
./scripts/get_walletd_binary.sh build
```

---

### Web3 COLD Service

#### New Service: `lib/services/web3_cold_service.dart`

**Purpose:**
- Connect to Ethereum Mainnet for COLD token
- View COLD balance and transactions
- Generate interest via C0DL3 rollup
- Transfer COLD tokens

**COLD Token Details:**
- **Contract**: `0x5aFe5e5C60940B5C6Ca0322dFe51c6D01d455755`
- **Network**: Ethereum Mainnet (L1)
- **Decimals**: 18
- **Symbol**: COLD
- **Interest**: Paid in HEAT via C0DL3 rollup

**Multi-RPC Support:**
```dart
// Auto-connect to best available RPC
await Web3COLDService.instance.connectAuto();

// Manual RPC selection
await Web3COLDService.instance.connect('https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY');

// Cached RPC preference
// Falls back if primary fails
```

**Available RPC Endpoints:**
1. Public Infura (rate-limited)
2. Public Alchemy (demo key)
3. Ethereum Public Node
4. Llama RPC

**Operations:**

1. **Balance Check:**
   ```dart
   final balance = await Web3COLDService.instance.getBalance('0xYourAddress');
   // Returns: {'balance': '1000.00', 'symbol': 'COLD', ...}
   ```

2. **Transfer COLD:**
   ```dart
   final tx = await Web3COLDService.instance.transfer(
     fromAddress: '0xYourAddress',
     toAddress: '0xRecipient',
     amount: '1000',
     privateKey: '0xYourPrivateKey', // Securely stored!
   );
   // Returns: {'transactionHash': '0x...', 'explorerUrl': 'https://etherscan.io/tx/...', ...}
   ```

3. **Gas Price:**
   ```dart
   final gas = await Web3COLDService.instance.getGasPrice();
   // Returns: '25.50 Gwei'
   ```

4. **Transaction Receipt:**
   ```dart
   final receipt = await Web3COLDService.instance.getTransactionReceipt('0xTxHash');
   ```

**Security:**
- Uses `web3dart` for secure key management
- No keys stored in code - always prompt user
- Address validation before transfers
- Transaction confirmation before sending

**C0DL3 Interest Integration:**
- Interest earned on COLD holdings
- Distributed in HEAT tokens
- Tracked in UI via Web3 connection
- Withdraw to any Ethereum address

---

### Updated Screens

#### 1. Banking Screen (`banking_screen.dart`)

**New Structure:**
```dart
TabBar = ['Ξternal Flame', 'COLD']

// Ξternal Flame Tab (Formerly Burn2Mint)
- Header: "Fuego Ξmbers (HEAT)"
- Burn Options: Standard (0.8 XFG → 8M HEAT), Large (800 XFG → 8B HEAT)
- Walletd Integration Panel: Toggle on/off
- Integrated Optimizer: Start/Stop with logs
- Burn Action: Navigate to Burn Deposits or integrated flow
- Info Card: Explanation of HEAT tokens and C0DL3 rollup

// COLD Tab (Formerly COLD Banking)
- Header: "COLD Interest Lounge"
- Web3 Connection Panel: Ethereum RPC, COLD address input
- Balance Display: Real-time COLD balance (if connected)
- Interest Info: C0DL3 interest generation details
- Service Integration: walletd + optimizer status
- Actions: Connect Web3, Set COLD address, Start services
- Logs: Web3 activity, service output
```

#### 2. Main Navigation (`main_screen.dart`)

**Updated Items:**
- Home (unchanged)
- Messages (unchanged)
- Banking (combines both modes)
- Settings (unchanged)
- Elderfiers (unchanged)
- (Burn Deposits removed from nav - now part of Banking screen)

**Visual indicator:**
- Banking nav shows fire icon + "HEAT" label
- Secondary indicators for active services

#### 3. Home Screen (`home_screen.dart`)

**Added:**
- Service availability status (walletd, optimizer, web3)
- Quick access cards for Ξternal Flame and COLD
- Service integration indicators
- Feature availability info

---

### Quick Start

#### Step 1: Install Dependencies
```bash
cd fuego-wallet
flutter pub get
```

#### Step 2: Ensure Binaries
```bash
# Download xfg-stark-cli (for burn proofs)
./scripts/ensure-binaries.sh

# Build/download walletd (for integration)
./scripts/get_walletd_binary.sh [build|download]
```

#### Step 3: Configure (Optional)
Create `wallet.conf` if needed:
```conf
daemon-address=localhost:8081
rpc-bind-port=8070
rpc-bind-ip=127.0.0.1
```

#### Step 4: Run
```bash
# Development
flutter run -d linux  # or macos, windows, android, ios

# Release build
flutter build linux --release
```

#### Step 5: Use Features

**Ξternal Flame (HEAT):**
1. Go to Banking → Ξternal Flame
2. Toggle walletd integration ON
3. Select burn amount (Standard/Large)
4. Start optimizer for auto-optimization
5. Click "Burn XFG & Mint HEAT"
6. Follow Burn Deposits screen
7. Get STARK proof
8. HEAT minted on Ethereum L1

**COLD Interest Lounge:**
1. Go to Banking → COLD
2. Enter COLD token address (0x...)
3. Click "Connect Web3"
4. View balance and interest
5. Start walletd for batch operations
6. Use optimizer for auto-deposits
7. Track earnings in HEAT tokens

---

### Technical Details

#### Binary Management

**Extraction Process:**
```dart
// From assets/bin/ to application support directory
getApplicationSupportDirectory() → bin/fuego-walletd-*
```

**Platform Detection:**
```dart
Platform.isWindows → .exe
Platform.isMacOS → -macos-arch
Platform.isLinux → -linux-arch
```

**Fallback:**
- If walletd binary missing: Use CLI service only
- If optimizer missing: Use walletd integrated optimizer
- If both missing: Show download instructions in UI

#### Process Communication

**walletd RPC:**
- POST http://127.0.0.1:8070/json_rpc
- JSON-RPC 2.0: get_status, optimize, get_version
- HTTP timeout: 10 seconds
- Retry: up to 3 times

**Web3:**
- HTTP/WebSocket connection to Ethereum
- Multiple RPC endpoints with failover
- transaction_count, get_gas_price, call, send_transaction

#### State Management

**Service States:**
```dart
_walletdProcess = Process?;      // Dart process handle
_optimizerProcess = Process?;     // Dart process handle
_isWalletdRunning = bool;         // Status indicator
_isOptimizerRunning = bool;       // Status indicator
_isWeb3Connected = bool;          // Web3 status
```

**UI Updates:**
```dart
// Callbacks for real-time updates
WalletdService.instance.onWalletdLog = (log) => setState(() {});
WalletdService.instance.onOptimizerStatusChanged = (status) => setState(() {});
Web3COLDService.instance.onBalanceUpdated = (balance) => setState(() {});
```

#### Error Handling

**Common Issues:**
1. **Binary missing**: Show instructions for `ensure-binaries.sh`
2. **Port in use**: Auto-increment to 8071, 8072, etc.
3. **RPC failure**: Try alternate endpoints
4. **Process crash**: Auto-restart with backoff
5. **Web3 disconnect**: Reconnect with exponential backoff

**User Feedback:**
- All operations show SnackBar notifications
- Logs stream in real-time to UI
- Status indicators for services
- Error dialogs with actionable steps

---

### Dependencies Added

```yaml
dependencies:
  web3dart: ^2.7.2           # Ethereum Web3 integration
  web3dart/contracts: ^2.7.2
  web3dart/json_rpc: ^2.7.2
  http: ^1.2.0               # API calls
  logging: ^1.2.0            # Service logging
  flutter_screenutil: ^5.9.0 # Responsive UI
  flutter_svg: ^2.0.10       # Icons
```

---

### File Changes Summary

**New Files:**
- `lib/services/walletd_service.dart` (3,272 lines)
- `lib/services/web3_cold_service.dart` (856 lines)
- `lib/screens/banking/banking_screen.dart` (updated)
- `lib/services/walletd_service.dart` (new)
- `lib/services/web3_cold_service.dart` (new)

**Modified Files:**
- `lib/screens/banking/banking_screen.dart` (tabs + integrated services)
- `lib/screens/main/main_screen.dart` (nav labels + icons)
- `lib/screens/home/home_screen.dart` (service status)
- `lib/utils/theme.dart` (new colors)
- `pubspec.yaml` (web3dart + assets)
- `INTEGRATION_CHANGES.md` (this document)

**No Changes:**
- `lib/screens/banking/burn_deposits_screen.dart` (works as before)
- `lib/services/cli_service.dart` (CLI fallback intact)
- Core wallet logic
- Existing providers and models

---

### Fallback Compatibility

If walletd/optimizer binaries are unavailable, the wallet falls back to:

1. **CLI Mode**: Use `xfg-stark-cli` for burn proofs (existing behavior)
2. **Remote Nodes**: Connect to external daemon (existing behavior)
3. **Manual Web3**: Use browser extension (Metamask) for COLD
4. **Download Instructions**: Show `ensure-binaries.sh` in UI

---

### Testing Checklist

- [ ] `flutter pub get` succeeds
- [ ] `scripts/ensure-binaries.sh` downloads CLI
- [ ] `scripts/get_walletd_binary.sh build` creates binary (or download)
- [ ] Navigation shows new names
- [ ] Banking screen has 2 tabs (Ξternal Flame + COLD)
- [ ] walletd starts and shows logs
- [ ] optimizer starts (integrated or standalone)
- [ ] Web3 connects to Ethereum
- [ ] COLD balance displays correctly
- [ ] Burn action works (CLI or integrated)
- [ ] All services stop cleanly
- [ ] Status indicators update in real-time
- [ ] UI responsive on mobile
- [ ] UI responsive on desktop

---

### Troubleshooting

**"walletd binary not found"**
```bash
./scripts/get_walletd_binary.sh download
# OR
./scripts/get_walletd_binary.sh build
```

**"Web3 connection failed"**
- Try alternate RPC endpoints
- Check internet connection
- Verify COLD address format (0x...)

**"Optimizer won't start"**
- Ensure walletd is running first
- Check port 8070 availability
- Check logs for specific errors

**"No COLD balance showing"**
- Verify correct Ethereum address
- Wait for RPC response (may be slow)
- Check Web3 logs in UI
- Confirm tokens exist at address

---

### Future Enhancements

- [ ] Multi-wallet support in walletd
- [ ] HEAT token trading interface
- [ ] C0DL3 rollup status viewer
- [ ] Batch COLD transactions
- [ ] Mobile background services
- [ ] Hardware wallet integration (Ledger/Trezor)
- [ ] Custom RPC endpoint management
- [ ] Transaction history view
- [ ] Interest calculator
- [ ] COLD/HEAT swap interface

---

### Support

For issues or questions:
1. Check this document first
2. Review terminal logs (flutter run)
3. Check UI service logs (integrated)
4. Run `./scripts/ensure-binaries.sh` for binary issues
5. Open GitHub issue with details

---

**Built with ❤️ for the Fuego ecosystem**