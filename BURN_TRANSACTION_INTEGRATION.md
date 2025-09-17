# Burn Transaction Integration in FuegoWallet

## Overview

The FuegoWallet now has **integrated burn transaction detection and STARK proof generation** directly built into the application. This eliminates the need for external Python scripts and provides a seamless user experience.

## Features

### 🔥 **Automatic Burn Detection**
- **Real-time detection** of burn transactions using `tx_extra` 0x08 tags
- **HEAT commitment parsing** from transaction extra data
- **Ethereum address extraction** from transaction metadata
- **Automatic logging** of burn transactions

### ⚡ **Integrated STARK Proof Generation**
- **Automatic STARK proof generation** for detected burn transactions
- **Background processing** - doesn't block the UI
- **Built-in STARK CLI integration** - finds and uses the CLI automatically
- **Error handling and logging** for failed proof generation

### 🎯 **Seamless Integration**
- **No external scripts required** - everything is built into the wallet
- **Automatic processing** - happens transparently when transactions are received
- **Configurable callbacks** - can be customized for different use cases
- **Thread-safe implementation** - doesn't interfere with wallet operations

## How It Works

### 1. **Transaction Processing**
When the wallet receives a transaction, it automatically:
1. **Checks `tx_extra`** for HEAT commitment (0x08 tag)
2. **Parses burn data** (commitment hash, amount, metadata)
3. **Extracts Ethereum address** from metadata
4. **Logs the detection** and notifies observers

### 2. **STARK Proof Generation**
If a burn transaction is detected and auto-generation is enabled:
1. **Creates proof package** with transaction data
2. **Calls STARK CLI** in background thread
3. **Generates proof** and saves to temporary directory
4. **Notifies completion** via callback

### 3. **Integration Points**
The burn detection is integrated into:
- **`WalletLegacy::onTransactionUpdated()`** - Main transaction processing
- **`BurnTransactionManager`** - Manages burn detection and proof generation
- **`BurnTransactionHandler`** - Handles the actual parsing and CLI calls

## Code Integration

### **Header Files**
- `cryptonote/include/BurnTransactionHandler.h` - Main interface
- `cryptonote/src/WalletLegacy/WalletLegacy.h` - Wallet integration

### **Implementation Files**
- `cryptonote/src/BurnTransactionHandler.cpp` - Core implementation
- `cryptonote/src/WalletLegacy/WalletLegacy.cpp` - Wallet integration

### **CMake Integration**
- Added `cryptonote/src/BurnTransactionHandler.cpp` to `CRYPTONOTE_SOURCES`

## Usage Examples

### **Basic Usage (Automatic)**
```cpp
// The wallet automatically detects burn transactions
// No additional code needed - it's built-in!
```

### **Manual Burn Detection**
```cpp
// Check if a transaction is a burn
std::vector<uint8_t> txExtra = getTransactionExtra();
if (wallet.isBurnTransaction(txExtra)) {
    auto burnData = wallet.parseBurnTransaction(txExtra);
    if (burnData.isValid) {
        std::cout << "Burn detected: " << burnData.amount 
                  << " XFG to " << burnData.ethAddress << std::endl;
    }
}
```

### **Manual STARK Proof Generation**
```cpp
// Generate STARK proof for a burn transaction
wallet.generateStarkProofForBurn(txHash, ethAddress, amount);
```

### **Custom Callbacks**
```cpp
// Set up custom callbacks (done automatically in WalletLegacy)
wallet.setBurnDetectedCallback([](const std::string& txHash, uint64_t amount, const std::string& ethAddress) {
    // Custom handling for burn detection
    std::cout << "Burn detected: " << txHash << std::endl;
});

wallet.setStarkProofGeneratedCallback([](const std::string& txHash, const std::string& proofData) {
    // Custom handling for proof generation
    std::cout << "Proof generated for: " << txHash << std::endl;
});
```

## Configuration

### **STARK CLI Path**
The system automatically searches for the STARK CLI in common locations:
- `./xfg-stark-cli`
- `../xfgwin/target/debug/xfg-stark-cli`
- `/usr/local/bin/xfg-stark-cli`
- `/opt/homebrew/bin/xfg-stark-cli`

### **Auto-Processing**
- **Enabled by default** - burn transactions are automatically processed
- **Can be disabled** if needed for custom handling
- **Configurable** via the `BurnTransactionManager`

## Benefits

### **🚀 Performance**
- **No external process spawning** - everything runs in-process
- **Background processing** - doesn't block the UI
- **Efficient parsing** - direct access to transaction data

### **🔒 Reliability**
- **No dependency on external scripts** - everything is self-contained
- **Proper error handling** - failures are logged and handled gracefully
- **Thread-safe** - multiple transactions can be processed simultaneously

### **🎨 User Experience**
- **Transparent operation** - users don't need to run separate scripts
- **Automatic detection** - burn transactions are processed automatically
- **Integrated logging** - all activity is logged through the wallet's logging system

### **🛠️ Developer Experience**
- **Clean API** - simple methods for burn detection and proof generation
- **Extensible** - easy to add custom callbacks and behavior
- **Well-documented** - clear interfaces and examples

## Migration from External Scripts

### **Before (External Scripts)**
```bash
# User had to run external scripts
python3 scripts/burn_transaction_detector.py tx_extra_data
./scripts/auto_stark_proof.sh tx_hash recipient amount
```

### **After (Integrated)**
```cpp
// Everything happens automatically in the wallet
// No external scripts needed!
```

## Future Enhancements

### **Potential Additions**
- **GUI integration** - Show burn transactions in the wallet UI
- **Proof storage** - Store generated proofs in the wallet database
- **Batch processing** - Process multiple burn transactions efficiently
- **Custom metadata** - Support for additional burn transaction metadata

### **API Extensions**
- **Observer pattern** - Notify UI components of burn events
- **Configuration options** - Allow users to configure burn detection behavior
- **Proof validation** - Validate generated proofs before storing

## Conclusion

The integrated burn transaction system provides a **seamless, reliable, and efficient** way to handle burn transactions directly within the FuegoWallet application. Users no longer need to run external scripts, and developers have a clean API for burn transaction handling.

This integration represents a **significant improvement** in the user experience and makes the burn-to-HEAT process much more accessible and reliable.
