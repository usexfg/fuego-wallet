#ifndef FUEGO_WALLET_MANAGER_H
#define FUEGO_WALLET_MANAGER_H

#include "fuego_sdk.h"
#include <memory>
#include <string>
#include <vector>
#include <stdint.h>

// Forward declarations from fuego-core
namespace System { class Dispatcher; }
namespace CryptoNote { 
    class IWallet; 
    class INode; 
    class Currency; 
    struct Deposit;
}
namespace Logging { class ILogger; class LoggerManager; }

namespace fuego {

class WalletManager {
public:
    static WalletManager& instance();

    FuegoError openWallet(const char* path, const char* password);
    void closeWallet();
    bool isOpen() const;

    // Balances
    FuegoError getBalance(uint64_t* available, uint64_t* locked);
    FuegoError getHEATBalance(uint64_t* available, uint64_t* locked);

    // Transactions
    FuegoError getTransactionCount(size_t* count);
    FuegoError getTransaction(size_t index, char* hash, size_t hash_size,
                               uint64_t* amount, uint64_t* fee,
                               uint32_t* block_height, uint64_t* timestamp,
                               bool* is_outgoing);

    // Send
    FuegoError sendTransaction(const char* address, uint64_t amount,
                                const char* asset_id, uint64_t fee,
                                const char* payment_id, char* tx_hash,
                                size_t tx_hash_size);

    // CD / Deposits
    FuegoError createDeposit(uint64_t amount, uint64_t term,
                              const char* source_address,
                              const char* dest_address,
                              char* tx_hash, size_t tx_hash_size,
                              FuegoCDInfo* info);
    FuegoError redeemDeposit(size_t deposit_id, char* tx_hash, size_t tx_hash_size,
                              uint64_t* redeemed_amount);
    FuegoError getDeposit(size_t index, FuegoCDInfo* info);
    FuegoError getDepositCount(size_t* count);
    FuegoError findDepositIdByHash(const std::string& hash, size_t* depositId);

    // Access to underlying wallet for Advanced operations
    CryptoNote::IWallet* getWallet() { return m_wallet.get(); }

    // Get the wallet's primary address
    std::string getAddress() const;

private:
    WalletManager();
    ~WalletManager();
    WalletManager(const WalletManager&) = delete;
    WalletManager& operator=(const WalletManager&) = delete;

    std::unique_ptr<System::Dispatcher> m_dispatcher;
    std::unique_ptr<Logging::LoggerManager> m_logger;
    std::unique_ptr<CryptoNote::Currency> m_currency;
    std::unique_ptr<CryptoNote::IWallet> m_wallet;
    std::string m_path;
    std::string m_password;
    bool m_open = false;
};

} // namespace fuego

#endif
