#include "fuego_sdk.h"
#include "node/node_manager.h"
#include "mining/miner.h"
#include "cd/deposit.h"
#include "swap/atomic_swap.h"
#include "heat/heat_proof.h"
#include "alias/alias_service.h"

#include <string>
#include <cstring>
#include <memory>
#include <vector>

namespace {
    std::string g_data_dir;
    bool g_testnet = false;
    bool g_initialized = false;
}

extern "C" {

FUEGO_API FuegoError fuego_sdk_init(const char* data_dir, bool testnet) {
    if (!data_dir) return FUEGO_ERROR_INVALID_PARAM;
    if (g_initialized) return FUEGO_ERROR_INTERNAL;
    try {
        g_data_dir = data_dir;
        g_testnet = testnet;
        g_initialized = true;
        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_INTERNAL;
    }
}

FUEGO_API void fuego_sdk_cleanup(void) {
    fuego_node_stop();
    fuego_mining_stop();
    g_initialized = false;
}

FUEGO_API const char* fuego_sdk_version(void) {
    return "1.0.0";
}

/* ============================================================================
   Node Management
   ============================================================================ */
FUEGO_API FuegoError fuego_node_start(FuegoNodeMode mode, const char* remote_host, uint16_t remote_port) {
    if (!g_initialized) return FUEGO_ERROR_NOT_INITIALIZED;
    try {
        if (mode == FUEGO_NODE_EMBEDDED) {
            return fuego::NodeManager::instance().startEmbedded(g_data_dir, g_testnet);
        } else {
            if (!remote_host) return FUEGO_ERROR_INVALID_PARAM;
            return fuego::NodeManager::instance().startRemote(remote_host, remote_port);
        }
    } catch (...) {
        return FUEGO_ERROR_NODE;
    }
}

FUEGO_API FuegoError fuego_node_stop(void) {
    try {
        fuego::NodeManager::instance().stop();
        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_NODE;
    }
}

FUEGO_API bool fuego_node_is_running(void) {
    return fuego::NodeManager::instance().isRunning();
}

FUEGO_API FuegoError fuego_node_get_peer_count(uint32_t* count) {
    if (!count) return FUEGO_ERROR_INVALID_PARAM;
    try {
        *count = fuego::NodeManager::instance().getPeerCount();
        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_NODE;
    }
}

FUEGO_API FuegoError fuego_node_get_block_height(uint32_t* height) {
    if (!height) return FUEGO_ERROR_INVALID_PARAM;
    try {
        *height = fuego::NodeManager::instance().getBlockHeight();
        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_NODE;
    }
}

FUEGO_API FuegoError fuego_node_get_sync_status(bool* synchronized) {
    if (!synchronized) return FUEGO_ERROR_INVALID_PARAM;
    try {
        *synchronized = fuego::NodeManager::instance().isSynchronized();
        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_NODE;
    }
}

/* ============================================================================
   Mining
   ============================================================================ */
FUEGO_API FuegoError fuego_mining_start(const char* wallet_address) {
    if (!g_initialized || !wallet_address) return FUEGO_ERROR_INVALID_PARAM;
    try {
        return fuego::Miner::instance().start(wallet_address);
    } catch (...) {
        return FUEGO_ERROR_MINING;
    }
}

FUEGO_API FuegoError fuego_mining_stop(void) {
    try {
        fuego::Miner::instance().stop();
        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_MINING;
    }
}

FUEGO_API bool fuego_mining_is_running(void) {
    return fuego::Miner::instance().isRunning();
}

FUEGO_API FuegoError fuego_mining_get_hashrate(double* hashrate) {
    if (!hashrate) return FUEGO_ERROR_INVALID_PARAM;
    try {
        *hashrate = fuego::Miner::instance().getHashrate();
        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_MINING;
    }
}

/* ============================================================================
   CD
   ============================================================================ */
FUEGO_API FuegoError fuego_cd_create(uint64_t amount, uint64_t lock_time, const char* wallet_file, const char* wallet_password, FuegoCDInfo* cd_info) {
    if (!g_initialized || !wallet_file || !wallet_password || !cd_info) return FUEGO_ERROR_INVALID_PARAM;
    try {
        return fuego::DepositManager::createDeposit(amount, lock_time, wallet_file, wallet_password, cd_info);
    } catch (...) {
        return FUEGO_ERROR_CD;
    }
}

FUEGO_API FuegoError fuego_cd_redeem(const char* tx_hash, const char* wallet_file, const char* wallet_password, uint64_t* redeemed_amount) {
    if (!g_initialized || !tx_hash || !wallet_file || !wallet_password || !redeemed_amount) return FUEGO_ERROR_INVALID_PARAM;
    try {
        return fuego::DepositManager::redeemDeposit(tx_hash, wallet_file, wallet_password, redeemed_amount);
    } catch (...) {
        return FUEGO_ERROR_CD;
    }
}

FUEGO_API FuegoError fuego_cd_get_info(const char* tx_hash, FuegoCDInfo* cd_info) {
    if (!tx_hash || !cd_info) return FUEGO_ERROR_INVALID_PARAM;
    try {
        return fuego::DepositManager::getDepositInfo(tx_hash, cd_info);
    } catch (...) {
        return FUEGO_ERROR_CD;
    }
}

/* ============================================================================
   Atomic Swaps
   ============================================================================ */
FUEGO_API FuegoError fuego_swap_initiate(const char* counterparty_address, uint64_t xfg_amount, uint64_t counterparty_amount, const char* counterparty_chain, const char* wallet_file, const char* wallet_password, FuegoSwapInfo* swap_info) {
    if (!g_initialized || !counterparty_address || !counterparty_chain || !wallet_file || !wallet_password || !swap_info) return FUEGO_ERROR_INVALID_PARAM;
    try {
        fuego::AdaptorSwapInitParams params;
        params.counterparty_address = counterparty_address;
        params.xfg_amount = xfg_amount;
        params.counterparty_chain = counterparty_chain;
        params.counterparty_amount = counterparty_amount;
        params.wallet_file = wallet_file;
        params.wallet_password = wallet_password;
        return fuego::AtomicSwap::initiate(params, reinterpret_cast<fuego::AdaptorSwapInfo*>(swap_info));
    } catch (...) {
        return FUEGO_ERROR_SWAP;
    }
}

FUEGO_API FuegoError fuego_swap_join(const char* swap_id, const char* wallet_file, const char* wallet_password, FuegoSwapInfo* swap_info) {
    if (!g_initialized || !swap_id || !wallet_file || !wallet_password || !swap_info) return FUEGO_ERROR_INVALID_PARAM;
    try {
        return fuego::AtomicSwap::join(swap_id, wallet_file, wallet_password, reinterpret_cast<fuego::AdaptorSwapInfo*>(swap_info));
    } catch (...) {
        return FUEGO_ERROR_SWAP;
    }
}

FUEGO_API FuegoError fuego_swap_lock_funds(const char* swap_id, const char* wallet_file, const char* wallet_password) {
    if (!g_initialized || !swap_id || !wallet_file || !wallet_password) return FUEGO_ERROR_INVALID_PARAM;
    try {
        return fuego::AtomicSwap::lockFunds(swap_id, wallet_file, wallet_password);
    } catch (...) {
        return FUEGO_ERROR_SWAP;
    }
}

FUEGO_API FuegoError fuego_swap_lock_counterparty_funds(const char* swap_id, const char* counterparty_tx_hash) {
    if (!g_initialized || !swap_id || !counterparty_tx_hash) return FUEGO_ERROR_INVALID_PARAM;
    try {
        return fuego::AtomicSwap::lockCounterpartyFunds(swap_id, counterparty_tx_hash);
    } catch (...) {
        return FUEGO_ERROR_SWAP;
    }
}

FUEGO_API FuegoError fuego_swap_complete(const char* swap_id, const char* wallet_file, const char* wallet_password) {
    if (!g_initialized || !swap_id || !wallet_file || !wallet_password) return FUEGO_ERROR_INVALID_PARAM;
    try {
        return fuego::AtomicSwap::complete(swap_id, wallet_file, wallet_password);
    } catch (...) {
        return FUEGO_ERROR_SWAP;
    }
}

FUEGO_API FuegoError fuego_swap_refund(const char* swap_id, const char* wallet_file, const char* wallet_password) {
    if (!g_initialized || !swap_id || !wallet_file || !wallet_password) return FUEGO_ERROR_INVALID_PARAM;
    try {
        return fuego::AtomicSwap::refund(swap_id, wallet_file, wallet_password);
    } catch (...) {
        return FUEGO_ERROR_SWAP;
    }
}

FUEGO_API FuegoError fuego_swap_get_info(const char* swap_id, FuegoSwapInfo* swap_info) {
    if (!swap_id || !swap_info) return FUEGO_ERROR_INVALID_PARAM;
    try {
        return fuego::AtomicSwap::getInfo(swap_id, reinterpret_cast<fuego::AdaptorSwapInfo*>(swap_info));
    } catch (...) {
        return FUEGO_ERROR_SWAP;
    }
}

FUEGO_API FuegoError fuego_swap_extract_secret(const char* swap_id, const uint8_t* pre_signature, const uint8_t* final_signature, uint8_t* adaptor_secret) {
    if (!g_initialized || !swap_id || !pre_signature || !final_signature || !adaptor_secret) return FUEGO_ERROR_INVALID_PARAM;
    try {
        std::vector<uint8_t> pre_sig_vec(pre_signature, pre_signature + 64);
        std::vector<uint8_t> final_sig_vec(final_signature, final_signature + 64);
        std::vector<uint8_t> secret_vec;
        FuegoError err = fuego::AtomicSwap::extractAdaptorSecret(swap_id, pre_sig_vec, final_sig_vec, secret_vec);
        if (err == FUEGO_OK && secret_vec.size() == 32) {
            memcpy(adaptor_secret, secret_vec.data(), 32);
        }
        return err;
    } catch (...) {
        return FUEGO_ERROR_SWAP;
    }
}

/* ============================================================================
   HEAT
   ============================================================================ */
FUEGO_API FuegoError fuego_heat_generate_proof(uint32_t block_start, uint32_t block_end, const char* wallet_file, const char* wallet_password, FuegoHEATProof* proof) {
    if (!g_initialized || !wallet_file || !wallet_password || !proof) return FUEGO_ERROR_INVALID_PARAM;
    try {
        return fuego::HEATProver::generateProof(block_start, block_end, wallet_file, wallet_password, proof);
    } catch (...) {
        return FUEGO_ERROR_HEAT;
    }
}

FUEGO_API FuegoError fuego_heat_verify_proof(const FuegoHEATProof* proof, bool* valid) {
    if (!proof || !valid) return FUEGO_ERROR_INVALID_PARAM;
    try {
        return fuego::HEATProver::verifyProof(proof, valid);
    } catch (...) {
        return FUEGO_ERROR_HEAT;
    }
}

/* ============================================================================
   Alias
   ============================================================================ */
FUEGO_API FuegoError fuego_alias_register(const char* alias, const char* wallet_address, const char* wallet_file, const char* wallet_password, char* tx_hash, size_t tx_hash_size) {
    if (!g_initialized || !alias || !wallet_address || !wallet_file || !wallet_password || !tx_hash) return FUEGO_ERROR_INVALID_PARAM;
    try {
        return fuego::AliasService::registerAlias(alias, wallet_address, wallet_file, wallet_password, tx_hash, tx_hash_size);
    } catch (...) {
        return FUEGO_ERROR_ALIAS;
    }
}

FUEGO_API FuegoError fuego_alias_resolve(const char* alias, char* wallet_address, size_t address_size) {
    if (!alias || !wallet_address) return FUEGO_ERROR_INVALID_PARAM;
    try {
        return fuego::AliasService::resolveAlias(alias, wallet_address, address_size);
    } catch (...) {
        return FUEGO_ERROR_ALIAS;
    }
}

FUEGO_API FuegoError fuego_alias_get_owned(const char* wallet_address, char** aliases, size_t* count) {
    if (!wallet_address || !aliases || !count) return FUEGO_ERROR_INVALID_PARAM;
    try {
        return fuego::AliasService::getOwnedAliases(wallet_address, aliases, count);
    } catch (...) {
        return FUEGO_ERROR_ALIAS;
    }
}

FUEGO_API void fuego_free_string(char* str) {
    if (str) free(str);
}

FUEGO_API void fuego_free_pointer_array(char** ptrs, size_t count) {
    if (ptrs) {
        for (size_t i = 0; i < count; ++i) if (ptrs[i]) free(ptrs[i]);
        free(ptrs);
    }
}

} /* extern "C" */
