# Fuego SDK

Universal Flutter-compatible SDK for Fuego blockchain with embedded node support, mining, Certificates of Deposit, atomic swaps, HEAT proofs, and alias registration.

## Features

- **Embedded Node**: Full node integration or remote node connection
- **Mining**: Start/stop mining with hashrate monitoring
- **Certificates of Deposit (CD)**: Create and redeem time-locked deposits with interest
- **Atomic Swaps**: Trustless cross-chain swaps with HTLC
- **HEAT Proofs**: XFG-STARK + zkSNARK proof bundles prove transaction details while preserving privacy.
- **Alias Service**: Register and resolve human-readable aliases

## Platform Support

- ✅ Android (ARM64)
- ✅ iOS (ARM64)
- ✅ macOS (x64/ARM64)
- ✅ Linux (x64)
- ✅ Windows (x64)

## Installation

### Add to pubspec.yaml

```yaml
dependencies:
  fuego_sdk:
    path: ../fuego-sdk/dart
    # Or from pub.dev (when published):
    # fuego_sdk: ^1.0.0
```

## Quick Start

```dart
import 'package:fuego_sdk/fuego_sdk.dart';

void main() async {
  // Initialize SDK
  final sdk = FuegoSDK.instance;
  await sdk.initialize(
    dataDir: '/path/to/data',
    testnet: true,
  );

  // Start node (embedded)
  await sdk.node.start(mode: FuegoNodeMode.embedded);
  
  // Or connect to remote node
  // await sdk.node.start(
  //   mode: FuegoNodeMode.remote,
  //   remoteHost: 'node.fuego.money',
  //   remotePort: 18180,
  // );

  // Check sync status
  final synced = await sdk.node.isSynchronized();
  print('Node synchronized: $synced');

  // Start mining
  await sdk.mining.start(walletAddress: 'fire8ab...');
  
  // Create a CD
  final cd = await sdk.cd.create(
    amount: 1000000000000, // in atomic units
    lockTime: 30 * 24 * 60 * 60, // 30 days in seconds
    walletFile: '/path/to/wallet',
    walletPassword: 'password',
  );
  print('CD created: ${cd.txHash}');

  // Initiate atomic swap
  final swap = await sdk.swap.initiate(
    counterpartyAddress: 'xfg...',
    amount: 500000000000,
    walletFile: '/path/to/wallet',
    walletPassword: 'password',
  );
  print('Swap initiated: ${swap.swapId}');

  // Generate HEAT proof
  final proof = await sdk.heat.generateProof(
    transactionData: 'tx_data_here',
    walletFile: '/path/to/wallet',
    walletPassword: 'password',
  );
  print('HEAT proof generated: ${proof.proofData.length} bytes');

  // Register alias
  final txHash = await sdk.alias.register(
    alias: 'myname',
    walletAddress: 'xfg...',
    walletFile: '/path/to/wallet',
    walletPassword: 'password',
  );
  print('Alias registered: $txHash');

  // Cleanup
  sdk.cleanup();
}
```

## API Reference

### Initialization

```dart
final sdk = FuegoSDK.instance;
await sdk.initialize(dataDir: '/path', testnet: false);
sdk.cleanup();
```

### Node Service

```dart
// Start embedded node
await sdk.node.start(mode: FuegoNodeMode.embedded);

// Start remote connection
await sdk.node.start(
  mode: FuegoNodeMode.remote,
  remoteHost: 'node.example.com',
  remotePort: 18180,
);

await sdk.node.stop();
bool running = sdk.node.isRunning();
int peers = await sdk.node.getPeerCount();
int height = await sdk.node.getBlockHeight();
bool synced = await sdk.node.isSynchronized();
```

### Mining Service

```dart
await sdk.mining.start(walletAddress: 'fire9p...');
await sdk.mining.stop();
bool mining = sdk.mining.isRunning();
double hashrate = await sdk.mining.getHashrate();
```

### CD Service

```dart
CDInfo cd = await sdk.cd.create(
  amount: 1000000000000,
  lockTime: 2592000, // 30 days
  walletFile: '/path/to/wallet',
  walletPassword: 'password',
);

int redeemed = await sdk.cd.redeem(
  txHash: cd.txHash,
  walletFile: '/path/to/wallet',
  walletPassword: 'password',
);

CDInfo info = await sdk.cd.getInfo(cd.txHash);
```

### Swap Service

```dart
SwapInfo swap = await sdk.swap.initiate(
  counterpartyAddress: 'fire8ap...',
  amount: 500000000000,
  walletFile: '/path/to/wallet',
  walletPassword: 'password',
);

await sdk.swap.join(
  swapId: swap.swapId,
  walletFile: '/path/to/wallet',
  walletPassword: 'password',
);

await sdk.swap.lockFunds(
  swapId: swap.swapId,
  walletFile: '/path/to/wallet',
  walletPassword: 'password',
);

await sdk.swap.complete(
  swapId: swap.swapId,
  walletFile: '/path/to/wallet',
  walletPassword: 'password',
);

await sdk.swap.refund(
  swapId: swap.swapId,
  walletFile: '/path/to/wallet',
  walletPassword: 'password',
);
```

### HEAT Service

```dart
HEATProof proof = await sdk.heat.generateProof(
  transactionData: 'tx_data',
  walletFile: '/path/to/wallet',
  walletPassword: 'password',
);

bool valid = await sdk.heat.verifyProof(proof);
```

### Alias Service

```dart
String txHash = await sdk.alias.register(
  alias: 'myname',
  walletAddress: 'fire8aw...',
  walletFile: '/path/to/wallet',
  walletPassword: 'password',
);

String address = await sdk.alias.resolve('myname');

List<String> aliases = await sdk.alias.getOwned('xfg...');
```

## Building from Source

### Prerequisites

- CMake 3.10+
- Boost 1.55+
- Qt 5.9+ (for some platform builds)
- Flutter 3.10+ (for Dart package)

### Build SDK Library

```bash
cd fuego-sdk
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
make install
```

### Build Dart Package

```bash
cd fuego-sdk/dart
flutter pub get
flutter pub run ffigen  # Regenerate FFI bindings if needed
flutter test
```

## Error Handling

All SDK methods return `FuegoError` enum values:

```dart
enum FuegoError {
  FUEGO_OK,                    // Success
  FUEGO_ERROR_INTERNAL,        // Internal error
  FUEGO_ERROR_INVALID_PARAM,   // Invalid parameter
  FUEGO_ERROR_NETWORK,         // Network error
  FUEGO_ERROR_WALLET,          // Wallet error
  FUEGO_ERROR_NODE,            // Node error
  FUEGO_ERROR_MINING,          // Mining error
  FUEGO_ERROR_CD,              // CD error
  FUEGO_ERROR_SWAP,            // Swap error
  FUEGO_ERROR_HEAT,            // HEAT proof error
  FUEGO_ERROR_ALIAS,           // Alias error
  FUEGO_ERROR_MEMORY,          // Memory allocation error
  FUEGO_ERROR_NOT_INITIALIZED, // SDK not initialized
}
```

## License

GPL-3.0 - See LICENSE file for details.

## Resources

- Website: https://usexfg.org
- GitHub: https://github.com/usexfg/fuego-wallet
- Discord: https://discord.usexfg.org
- 𝕏: https://x.com/usexfg
