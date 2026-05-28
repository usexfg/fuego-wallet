#include "wallet_manager.h"
#include "../node/node_manager.h"

#include "IWallet.h"
#include "Wallet/WalletGreen.h"
#include "CryptoNoteCore/Currency.h"
#include "CryptoNoteCore/DepositCommitment.h"

#include "INode.h"
#include "Logging/LoggerManager.h"

#include <System/Dispatcher.h>
#include <Common/StringTools.h>
#include <cstring>

namespace fuego {

WalletManager::WalletManager() {
    m_dispatcher = std::make_unique<System::Dispatcher>();
    m_logger = std::make_unique<Logging::LoggerManager>();
}

WalletManager::~WalletManager() {
    closeWallet();
}

WalletManager& WalletManager::instance() {
    static WalletManager inst;
    return inst;
}

FuegoError WalletManager::openWallet(const char* path, const char* password) {
    if (!path || !password) return FUEGO_ERROR_INVALID_PARAM;
    if (m_open) closeWallet();

    try {
        auto* node = NodeManager::instance().getNode();
        if (!node || !NodeManager::instance().isRunning()) {
            return FUEGO_ERROR_NODE;
        }

        // Build currency from config
        CryptoNote::CurrencyBuilder currencyBuilder(*m_logger);
        m_currency = std::make_unique<CryptoNote::Currency>(currencyBuilder.currency());

        // Create WalletGreen with the embedded/remote node
        auto* wallet = new CryptoNote::WalletGreen(
            *m_dispatcher,
            *m_currency,
            *node,
            *m_logger
        );
        m_wallet.reset(wallet);

        std::string extra;
        m_wallet->load(path, password, extra);
        m_wallet->start(); // Start syncing

        m_path = path;
        m_password = password;
        m_open = true;
        return FUEGO_OK;
    } catch (const std::exception& e) {
        m_wallet.reset();
        return FUEGO_ERROR_WALLET;
    }
}

void WalletManager::closeWallet() {
    if (!m_open || !m_wallet) return;

    try {
        m_wallet->stop();
        m_wallet->save(CryptoNote::WalletSaveLevel::SAVE_ALL);
        m_wallet->shutdown();
    } catch (...) {}

    m_wallet.reset();
    m_open = false;
    m_path.clear();
    m_password.clear();
}

bool WalletManager::isOpen() const {
    return m_open && m_wallet != nullptr;
}

FuegoError WalletManager::getBalance(uint64_t* available, uint64_t* locked) {
    if (!isOpen()) return FUEGO_ERROR_NOT_INITIALIZED;
    if (!available || !locked) return FUEGO_ERROR_INVALID_PARAM;

    *available = m_wallet->getActualBalance();
    *locked = m_wallet->getPendingBalance();
    return FUEGO_OK;
}

FuegoError WalletManager::getHEATBalance(uint64_t* available, uint64_t* locked) {
    if (!isOpen()) return FUEGO_ERROR_NOT_INITIALIZED;
    if (!available || !locked) return FUEGO_ERROR_INVALID_PARAM;

    // HEAT is tracked as DEPOSIT balance (CDs locked in HEAT)
    *locked = m_wallet->getLockedDepositBalance();
    *available = m_wallet->getUnlockedDepositBalance();
    return FUEGO_OK;
}

FuegoError WalletManager::getTransactionCount(size_t* count) {
    if (!isOpen()) return FUEGO_ERROR_NOT_INITIALIZED;
    *count = m_wallet->getTransactionCount();
    return FUEGO_OK;
}

FuegoError WalletManager::getTransaction(size_t index, char* hash, size_t hash_size,
                                          uint64_t* amount, uint64_t* fee,
                                          uint32_t* block_height, uint64_t* timestamp,
                                          bool* is_outgoing) {
    if (!isOpen()) return FUEGO_ERROR_NOT_INITIALIZED;
    if (index >= m_wallet->getTransactionCount()) return FUEGO_ERROR_INVALID_PARAM;

    auto tx = m_wallet->getTransaction(index);
    if (hash && hash_size > 0) {
        std::string hashStr = Common::podToHex(tx.hash);
        strncpy(hash, hashStr.c_str(), hash_size - 1);
        hash[hash_size - 1] = '\0';
    }
    if (amount) *amount = static_cast<uint64_t>(tx.totalAmount < 0 ? -tx.totalAmount : tx.totalAmount);
    if (fee) *fee = tx.fee;
    if (block_height) *block_height = tx.blockHeight;
    if (timestamp) *timestamp = tx.timestamp;
    if (is_outgoing) *is_outgoing = (tx.totalAmount < 0);
    return FUEGO_OK;
}

FuegoError WalletManager::sendTransaction(const char* address, uint64_t amount,
                                           const char* asset_id, uint64_t fee,
                                           const char* payment_id, char* tx_hash,
                                           size_t tx_hash_size) {
    if (!isOpen()) return FUEGO_ERROR_NOT_INITIALIZED;
    if (!address) return FUEGO_ERROR_INVALID_PARAM;

    try {
        CryptoNote::TransactionParameters params;
        params.destinations = {{address, amount}};
        params.fee = fee > 0 ? fee : CryptoNote::parameters::MINIMUM_FEE;
        params.mixIn = CryptoNote::parameters::MIN_TX_MIXIN_SIZE;

        if (payment_id && strlen(payment_id) > 0) {
            params.extra = payment_id;
        }

        // For HEAT-colored transactions, embed assetID in tx_extra
        if (asset_id && strlen(asset_id) > 0) {
            params.extra += std::string("|asset:") + asset_id;
        }

        Crypto::SecretKey tx_sk;
        size_t txId = m_wallet->transfer(params, tx_sk);

        // Get transaction hash
        auto walletTx = m_wallet->getTransaction(txId);
        std::string hashStr = Common::podToHex(walletTx.hash);

        if (tx_hash && tx_hash_size > 0) {
            strncpy(tx_hash, hashStr.c_str(), tx_hash_size - 1);
            tx_hash[tx_hash_size - 1] = '\0';
        }

        return FUEGO_OK;
    } catch (const std::exception& e) {
        return FUEGO_ERROR_WALLET;
    }
}

FuegoError WalletManager::createDeposit(uint64_t amount, uint64_t term,
                                         const char* source_address,
                                         const char* dest_address,
                                         char* tx_hash, size_t tx_hash_size,
                                         FuegoCDInfo* info) {
    if (!isOpen()) return FUEGO_ERROR_NOT_INITIALIZED;
    if (!source_address || !dest_address) return FUEGO_ERROR_INVALID_PARAM;

    try {
        // Use HEAT deposit type
        CryptoNote::DepositCommitment commitment;
        commitment.type = CryptoNote::CommitmentType::HEAT;

        std::string txHash;
        m_wallet->createDeposit(amount, term,
                                 source_address, dest_address,
                                 txHash, commitment);

        if (tx_hash && tx_hash_size > 0) {
            strncpy(tx_hash, txHash.c_str(), tx_hash_size - 1);
            tx_hash[tx_hash_size - 1] = '\0';
        }

        if (info) {
            info->amount = amount;
            info->interest = 0; // Calculated at maturity
            info->unlock_time = static_cast<uint64_t>(term);
            if (tx_hash && tx_hash_size > 0) {
                strncpy(info->tx_hash, txHash.c_str(), 64);
                info->tx_hash[64] = '\0';
            }
        }

        return FUEGO_OK;
    } catch (const std::exception& e) {
        return FUEGO_ERROR_CD;
    }
}

FuegoError WalletManager::redeemDeposit(size_t deposit_id, char* tx_hash,
                                         size_t tx_hash_size,
                                         uint64_t* redeemed_amount) {
    if (!isOpen()) return FUEGO_ERROR_NOT_INITIALIZED;

    try {
        std::string txHash;
        m_wallet->withdrawDeposit(deposit_id, txHash);

        if (tx_hash && tx_hash_size > 0) {
            strncpy(tx_hash, txHash.c_str(), tx_hash_size - 1);
            tx_hash[tx_hash_size - 1] = '\0';
        }

        // Query the deposit to get the redeemed amount
        auto dep = m_wallet->getDeposit(deposit_id);
        if (redeemed_amount) {
            *redeemed_amount = dep.amount + dep.interest;
        }

        return FUEGO_OK;
    } catch (const std::exception& e) {
        return FUEGO_ERROR_CD;
    }
}

FuegoError WalletManager::getDeposit(size_t index, FuegoCDInfo* info) {
    if (!isOpen()) return FUEGO_ERROR_NOT_INITIALIZED;
    if (!info) return FUEGO_ERROR_INVALID_PARAM;

    try {
        auto dep = m_wallet->getDeposit(index);

        info->amount = dep.amount;
        info->interest = dep.interest;
        info->unlock_time = dep.unlockHeight;
        std::string hashStr = Common::podToHex(dep.transactionHash);
        strncpy(info->tx_hash, hashStr.c_str(), 64);
        info->tx_hash[64] = '\0';

        return FUEGO_OK;
    } catch (const std::exception& e) {
        return FUEGO_ERROR_CD;
    }
}

FuegoError WalletManager::getDepositCount(size_t* count) {
    if (!isOpen()) return FUEGO_ERROR_NOT_INITIALIZED;
    *count = m_wallet->getWalletDepositCount();
    return FUEGO_OK;
}

FuegoError WalletManager::findDepositIdByHash(const std::string& hash, size_t* depositId) {
    if (!isOpen()) return FUEGO_ERROR_NOT_INITIALIZED;
    if (!depositId) return FUEGO_ERROR_INVALID_PARAM;

    size_t count = m_wallet->getWalletDepositCount();
    for (size_t i = 0; i < count; ++i) {
        auto dep = m_wallet->getDeposit(i);
        if (Common::podToHex(dep.transactionHash) == hash) {
            *depositId = i;
            return FUEGO_OK;
        }
    }

    return FUEGO_ERROR_NOT_FOUND;
}

} // namespace fuego
