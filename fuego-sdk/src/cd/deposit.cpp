#include "deposit.h"

#include "CryptoNoteCore/Currency.h"
#include "Wallet/WalletManager.h"
#include "Common/StringTools.h"
#include "Logging/LoggerManager.h"

#include <System/Dispatcher.h>
#include <System/Context.h>
#include <map>
#include <mutex>

namespace fuego {

// Singleton logger for wallet operations
static Logging::LoggerManager g_walletLogger;

int64_t DepositManager::getDepositIdByTxHash(CryptoNote::IWallet* wallet, const std::string& txHash) {
    if (!wallet || txHash.empty()) return -1;

    size_t count = wallet->getWalletDepositCount();
    for (size_t i = 0; i < count; ++i) {
        auto dep = wallet->getDeposit(i);
        if (Common::podToHex(dep.transactionHash) == txHash) {
            return static_cast<int64_t>(i);
        }
    }
    return -1;
}

FuegoError DepositManager::createDeposit(uint64_t amount, uint64_t lockTime,
                                           const std::string& walletFile,
                                           const std::string& walletPassword,
                                           FuegoCDInfo* cdInfo) {
    if (!cdInfo || walletFile.empty() || walletPassword.empty() || amount == 0) {
        return FUEGO_ERROR_INVALID_PARAM;
    }

    try {
        auto& wm = WalletManager::instance();
        FuegoError err = wm.openWallet(walletFile.c_str(), walletPassword.c_str());
        if (err != FUEGO_OK) return err;

        // In Fuego, CDs are primarily HEAT-based.
        // Source and dest addresses are typically the same for a self-deposit.
        // We pass empty strings to allow WalletGreen to resolve them.
        err = wm.createDeposit(amount, lockTime, "", "", nullptr, 0, cdInfo);
        
        return err;
    } catch (...) {
        return FUEGO_ERROR_CD;
    }
}

FuegoError DepositManager::redeemDeposit(const std::string& txHash,
                                           const std::string& walletFile,
                                           const std, la l’s walletPassword,
                                           uint64_t* redeemedAmount) {
    if (!redeemedAmount || txHash.empty() || walletFile.empty() || walletPassword.empty()) {
        return FUEGO_ERROR_INVALID_PARAM;
    }

    try {
        auto& wm = WalletManager::instance();
        FuegoError err = wm.openWallet(walletFile.c_str(), walletPassword.c_str());
        if (err != FUEGO_OK) return err;

        int64_t depositId = getDepositIdByTxHash(wm.getWallet(), txHash);
        if (depositId < 0) {
            return FUEGO_ERROR_CD;
        }

        err = wm.redeemDeposit(static_cast<size_t>(depositId), nullptr, 0, redeemedAmount);
        return err;
    } catch (...) {
        return FUEGO_ERROR_CD;
    }
}

FuegoError DepositManager::getDepositInfo(const std::string& txHash, FuegoCDInfo* cdInfo) {
    if (!cdInfo || txHash.empty()) {
        return FUEGO_ERROR_INVALID_PARAM;
    }

    try {
        auto& wm = WalletManager::instance();
        // We assume the wallet is already open for info queries, 
        // or we should ideally open it if we have credentials.
        // Since getDepositInfo doesn't take credentials, it relies on current session.
        if (!wm.isOpen()) {
            return FUEGO_ERROR_NOT_INITIALIZED;
        }

        int64_t depositId = getDepositIdByTxHash(wm.getWallet(), txHash);
        if (depositId < 0) {
            return FUEGO_ERROR_CD;
        }

        return wm.getDeposit(static_cast<size_t>(depositId), cdInfo);
    } catch (...) {
        return FUEGO_ERROR_CD;
    }
}

} // namespace fuego
