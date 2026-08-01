# Plan: Unified Daemon Bundle

## Goal
Bundle fuegod + walletd + xfg-swapd into a single binary, exposing JSON-RPC on port 18189 for the Flutter app.

## Key Discovery
- walletd's `--local` flag **already starts fuegod in-process**
- fuegod **already embeds SwapDaemon** in-process
- So `walletd --local` already runs all 3 daemons — we just need to add the missing endpoints

## What's Missing
1. SwapDaemon's RpcServer (port 18902) and StatusServer (port 18900) are not started in walletd's `runInProcess()`
2. Health check endpoint (`GET /health`)
3. CORS headers for Flutter app

## Implementation Steps

### Step 1: Add SwapDaemon startup to walletd's runInProcess()
**File:** `/Users/aejt/xfgo/src/PaymentGateService/PaymentGateService.cpp`

In `runInProcess()`, after `rpcServer.start()` and before `runWalletService()`:
- Start SwapDaemon (already created by fuegod)
- Start SwapDaemon RpcServer on port 18902
- Start SwapDaemon StatusServer on port 18900
- Wire SwapDaemon to fuegod's SwapRelay and SwapDatabase

### Step 2: Add Health Check Endpoint
**File:** `/Users/aejt/xfgo/src/PaymentGateService/PaymentServiceJsonRpcServer.cpp`

Add a `GET /health` endpoint that returns:
- fuegod status (height, peer count, syncing)
- walletd status (balance, address, sync progress)
- swapd status (active swaps)

### Step 3: Add CORS Headers
**File:** `/Users/aejt/xfgo/src/HttpServer/HttpServer.cpp` (or wherever the HTTP server is)

Add `Access-Control-Allow-Origin: *` header to all responses.

### Step 4: Update CMakeLists.txt
**File:** `/Users/aejt/xfgo/src/CMakeLists.txt`

Add SwapDaemonLib, OpenSSL, secp256k1 to PaymentGateService's link libraries.

### Step 5: Update Dart Client
**File:** `/Users/aejt/DEXFG/fuego-flutter-wallet/lib/services/fuego_rpc_service.dart`

Update to use the unified daemon's API:
- Add health check polling
- Adjust any method name differences (if needed)
- Remove the separate process management for fuegod/xfg-swapd

### Step 6: Update DaemonManager
**File:** `/Users/aejt/DEXFG/fuego-flutter-wallet/lib/services/daemon_manager.dart`

Simplify to only manage one binary (the unified daemon) instead of 3 separate processes.

### Step 7: Cross-Compile for All Platforms
Build the unified binary for:
- macOS arm64 (Apple Silicon)
- macOS x86_64 (Intel)
- Linux x86_64
- Windows x86_64
- Android arm64 (for mobile)
- iOS arm64 (for mobile)

### Step 8: Update CI
**Files:** `.github/workflows/fuego-wallet-ci.yml`, `.github/workflows/fuego-wallet-mobile-ci.yml`

- Build the unified C++ binary
- Bundle with Flutter app
- Update release process

## Expected Outcome
- Single binary (~30-40MB) that runs all 3 daemons
- JSON-RPC on port 18189 (same as current Rust proxy)
- Health checks on GET /health
- CORS support for Flutter app
- No Rust dependency for the daemon layer
