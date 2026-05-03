# Fuego Flutter SDK Integration

## Overview

This document describes the integration of the Fuego SDK into the Flutter wallet application.

## Architecture

```
fuego-wallet/
├── fuego-sdk/              # Native C++ SDK + Dart FFI bindings
│   ├── include/            # C API headers
│   ├── src/                # C++ implementation
│   ├── dart/               # Dart package
│   └── flutter_plugin/     # Flutter plugin wrapper
├── lib/
│   ├── services/           # Existing services
│   │   ├── walletd_service.dart
│   │   ├── fuego_rpc_service.dart
│   │   └── ...
│   └── sdk/                # New SDK integration
│       └── fuego_sdk_service.dart  # SDK wrapper service
└── fuego/                  # Fuego core submodule
```

## Migration Path

### Phase 1: SDK Build Infrastructure (Current)
- ✅ C API headers (`fuego_sdk.h`)
- ✅ C++ implementation stubs
- ✅ Dart FFI bindings
- ✅ CI/CD workflows

### Phase 2: Core Implementation
- [ ] Node manager (embedded/remote)
- [ ] Mining integration
- [ ] CD operations
- [ ] Atomic swap engine
- [ ] HEAT proof generation
- [ ] Alias service

### Phase 3: Flutter Integration
- [ ] Replace `WalletDaemonService` with SDK
- [ ] Update UI to use SDK services
- [ ] Add new screens for CDs, Swaps, HEAT
- [ ] Update theme with Fuego orange

### Phase 4: Testing & Optimization
- [ ] Unit tests for Dart layer
- [ ] Integration tests with testnet
- [ ] Performance optimization
- [ ] Security audit

## API Mapping

| Old Service | New SDK Service |
|-------------|----------------|
| `WalletDaemonService` | `FuegoSDK.node` + `FuegoSDK.mining` |
| `FuegoRPCService` | `FuegoSDK.node` (embedded) |
| N/A | `FuegoSDK.cd` |
| N/A | `FuegoSDK.swap` |
| N/A | `FuegoSDK.heat` |
| N/A | `FuegoSDK.alias` |

## Build Commands

### Build SDK
```bash
cd fuego-sdk
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)
```

### Build Flutter App
```bash
flutter pub get
flutter run
```

### Run Tests
```bash
cd fuego-sdk/dart
flutter test
```

## Next Steps

1. Implement actual node integration using Fuego core
2. Complete CD create/redeem logic
3. Implement atomic swap HTLC logic
4. Integrate HEAT/zk-SNARK prover
5. Add alias registration to blockchain
