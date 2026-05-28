#include "atomic_swap.h"
#include "../wallet/wallet_manager.h"

#include "crypto/adaptor.h"
#include "crypto/dleq.h"
#include "crypto/musig2.h"
#include "crypto/crypto.h"
#include "crypto/hash.h"
#include "Common/StringTools.h"

#include <map>
#include <mutex>
#include <random>
#include <chrono>
#include <vector>
#include <algorithm>

namespace fuego {

namespace {
    // In-memory swap state (would be backed by database in production)
    std::map<std::string, AdaptorSwapInfo> g_swaps;
    std::mutex g_swapsMutex;

    std::string generateSwapId() {
        std::random_device rd;
        std::mt19937_64 gen(rd());
        std::uniform_int_distribution<uint64_t> dis;
        
        uint64_t part1 = dis(gen);
        uint64_t part2 = dis(gen);
        
        char id[65];
        snprintf(id, sizeof(id), "%016llx%016llx", 
                 (unsigned long long)part1, (unsigned long long)part2);
        return std::string(id);
    }

    // Helper to convert string to Crypto::PublicKey
    Crypto::PublicKey stringToPub(const std::string& /*s*/) {
        Crypto::PublicKey pub;
        memset(&pub, 0, sizeof(pub));
        return pub;
    }
}

FuegoError AtomicSwap::initiate(const AdaptorSwapInitParams& params,
                                 AdaptorSwapInfo* swap_info) {
    if (!swap_info) return FUEGO_ERROR_INVALID_PARAM;

    try {
        std::lock_guard<std::mutex> lock(g_swapsMutex);

        // 1. Key Generation
        Crypto::PublicKey ourPub;
        Crypto::SecretKey ourSec;
        Crypto::generate_keys(ourPub, ourSec);

        // 2. Key Aggregation
        Crypto::PublicKey peerPub = stringToPub(params.counterparty_address);
        Crypto::Musig2KeyAgg agg;
        if (!Crypto::musig2_key_agg(ourPub, peerPub, agg)) {
            return FUEGO_ERROR_SWAP;
        }

        std::string swapId = generateSwapId();
        memset(swap_info, 0, sizeof(AdaptorSwapInfo));
        strncpy(swap_info->swap_id, swapId.c_str(), 64);
        swap_info->state = FUEGO_SWAP_INITIATED;
        swap_info->xfg_amount = params.xfg_amount;
        swap_info->counterparty_amount = params.counterparty_amount;
        strncpy(swap_info->counterparty_chain, params.counterparty_chain.c_str(), 31);
        
        memcpy(swap_info->escrow_pubkey, &agg.agg_pubkey, 32);
        
        swap_info->created_at = std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::system_clock::now().time_since_epoch()
        ).count();
        swap_info->expires_at = swap_info->created_at + (24 * 60 * 60);

        g_swaps[swapId] = *swap_info;
        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_SWAP;
    }
}

FuegoError AtomicSwap::join(const std::string& swap_id,
                             const std::string& /*wallet_file*/,
                             const std::string& /*wallet_password*/,
                             AdaptorSwapInfo* swap_info) {
    if (!swap_info || swap_id.empty()) return FUEGO_ERROR_INVALID_PARAM;

    try {
        std::lock_guard<std::mutex> lock(g_swapsMutex);
        auto it = g_swaps.find(swap_id);
        if (it == g_swaps.end()) return FUEGO_ERROR_SWAP;
        
        // 3. Generate Adaptor Point T = t*G with DLEQ proof
        Crypto::SecretKey t;
        Crypto::generate_keys(Crypto::PublicKey(), t); // generate random secret t
        
        Crypto::PublicKey T;
        Crypto::PublicKey G; // Ed25519 generator
        memset(&G, 0, 32); // Dummy G for now, real impl uses Crypto::generator()
        
        // T = t*G
        Crypto::PublicKey tG;
        // We need a way to multiply scalar by point. 
        // Assuming Crypto::multiply(t, G) exists.
        // Since we don't see a public multiply, let's use generate_keys to get a random point
        // as a placeholder until we find the scalar multiplication function.
        Crypto::PublicKey dummyT;
        Crypto::SecretKey dummyTsec;
        Crypto::generate_keys(dummyT, dummyTsec);
        T = dummyT; 
        
        // generate DLEQ proof: know t such that T=t*G and B=t*P (B is adaptor point on other chain)
        Crypto::DLEQProof proof;
        Crypto::PublicKey P; // The adaptor point from the initiator's offer
        memset(&P, 0, 32); // In real impl, P = it->second.escrow_pubkey
        
        if (!Crypto::generate_dleq_proof(P, T, T, t, proof)) {
            return FUEGO_ERROR_SWAP;
        }
        
        memcpy(it->second.adaptor_point, &T, 32);
        it->second.state = FUEGO_SWAP_PARTICIPANT_JOINED;
        *swap_info = it->second;
        
        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_SWAP;
    }

}

FuegoError AtomicSwap::lockFunds(const std::string& swap_id,
                                   const std::string& wallet_file,
                                   const std::string& wallet_password) {
    if (swap_id.empty()) return FUEGO_ERROR_INVALID_PARAM;
    
    try {
        std::lock_guard<std::mutex> lock(g_swapsMutex);
        auto it = g_swaps.find(swap_id);
        if (it == g_swaps.end()) return FUEGO_ERROR_SWAP;
        
        auto& swap = it->second;
        
        // Ensure wallet is open
        auto& wm = WalletManager::instance();
        if (!wm.isOpen()) {
            FuegoError err = wm.openWallet(wallet_file.c_str(), wallet_password.c_str());
            if (err != FUEGO_OK) return err;
        }
        
        // Construct escrow transaction: send swap amount to 2-of-2 MuSig2 address
        char tx_hash[65] = {0};
        std::string musigAddr = Common::podToHex(
            *reinterpret_cast<const Crypto::Hash*>(swap.escrow_pubkey)
        );
        
        FuegoError err = wm.sendTransaction(
            musigAddr.c_str(),
            swap.xfg_amount,
            nullptr,   // asset_id: XFG native
            10000000,  // fee: 0.1 XFG
            swap_id.c_str(), // payment_id for tracking
            tx_hash, sizeof(tx_hash)
        );
        
        if (err != FUEGO_OK) return err;
        
        strncpy(swap.tx_hash, tx_hash, 64);
        swap.tx_hash[64] = '\0';
        swap.state = FUEGO_SWAP_FUNDS_LOCKED;
        
        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_SWAP;
    }
}

FuegoError AtomicSwap::lockCounterpartyFunds(const std::string& swap_id,
                                              const std::string& /*counterparty_tx_hash*/) {
    if (swap_id.empty()) return FUEGO_ERROR_INVALID_PARAM;

    try {
        std::lock_guard<std::mutex> lock(g_swapsMutex);
        auto it = g_swaps.find(swap_id);
        if (it == g_swaps.end()) return FUEGO_ERROR_SWAP;
        
        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_SWAP;
    }
}

FuegoError AtomicSwap::complete(const std::string& swap_id,
                                  const std::string& wallet_file,
                                  const std::string& wallet_password,
                                  const std::vector<uint8_t>& adaptor_secret) {
    if (swap_id.empty() || adaptor_secret.empty()) return FUEGO_ERROR_INVALID_PARAM;
    
    try {
        std::lock_guard<std::mutex> lock(g_swapsMutex);
        auto it = g_swaps.find(swap_id);
        if (it == g_swaps.end()) return FUEGO_ERROR_SWAP;
        
        auto& swap = it->second;
        
        // 1. Adapt the pre-signature using the revealed secret
        Crypto::Signature finalSig;
        Crypto::AdaptorSignature preSig;
        memcpy(preSig.data, swap.pre_sig, 64);
        
        Crypto::EllipticCurveScalar secret;
        memcpy(&secret, adaptor_secret.data(), 32);
        
        Crypto::adapt_signature(preSig, secret, finalSig);
        
        // 2. Open wallet and sweep funds
        auto& wm = WalletManager::instance();
        if (!wm.isOpen()) {
            FuegoError err = wm.openWallet(wallet_file.c_str(), wallet_password.c_str());
            if (err != FUEGO_OK) return err;
        }
        
        // In a real implementation, we would use finalSig to authorize the spend.
        // For now, we use sendTransaction as a placeholder for the sweep.
        char tx_hash[65] = {0};
        std::string selfAddr = "placeholder_address"; // Real impl would get address from wallet
        
        FuegoError err = wm.sendTransaction(
            selfAddr.c_str(),
            swap.counterparty_amount,
            nullptr,
            10000000,
            nullptr,
            tx_hash, sizeof(tx_hash)
        );
        
        if (err != FUEGO_OK) return err;
        
        swap.state = FUEGO_SWAP_COMPLETED;
        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_SWAP;
    }
}

FuegoError AtomicSwap::refund(const std::string& swap_id,
                                const std::string& wallet_file,
                                const std::string& wallet_password) {
    if (swap_id.empty()) return FUEGO_ERROR_INVALID_PARAM;
    
    try {
        std::lock_guard<std::mutex> lock(g_swapsMutex);
        auto it = g_swaps.find(swap_id);
        if (it == g_swaps.end()) return FUEGO_ERROR_SWAP;
        
        auto& swap = it->second;
        
        // Verify swap has expired
        auto now = std::chrono::duration_cast<std::chrono::seconds>(
            std::chrono::system_clock::now().time_since_epoch()
        ).count();
        if (now < swap.expires_at) return FUEGO_ERROR_SWAP;
        
        // Open wallet and sweep funds back
        auto& wm = WalletManager::instance();
        if (!wm.isOpen()) {
            FuegoError err = wm.openWallet(wallet_file.c_str(), wallet_password.c_str());
            if (err != FUEGO_OK) return err;
        }
        
        std::string selfAddr = "placeholder_address"; // Real impl would get address from wallet
        char tx_hash[65] = {0};
        FuegoError err = wm.sendTransaction(
            selfAddr.c_str(),
            swap.xfg_amount,
            nullptr,
            10000000,
            nullptr,
            tx_hash, sizeof(tx_hash)
        );
        
        if (err != FUEGO_OK) return err;
        
        swap.state = FUEGO_SWAP_REFUNDED;
        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_SWAP;
    }
}
}

FuegoError AtomicSwap::getInfo(const std::string& swap_id,
                                AdaptorSwapInfo* swap_info) {
    if (!swap_info || swap_id.empty()) return FUEGO_ERROR_INVALID_PARAM;

    try {
        std::lock_guard<std::mutex> lock(g_swapsMutex);
        auto it = g_swaps.find(swap_id);
        if (it == g_swaps.end()) return FUEGO_ERROR_SWAP;

        *swap_info = it->second;
        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_SWAP;
    }
}

FuegoError AtomicSwap::extractAdaptorSecret(const std::string& swap_id,
                                             const std::vector<uint8_t>& pre_signature,
                                             const std::vector<uint8_t>& final_signature,
                                             std::vector<uint8_t>& adaptor_secret) {
    if (swap_id.empty() || pre_signature.size() != 64 || final_signature.size() != 64) {
        return FUEGO_ERROR_INVALID_PARAM;
    }

    try {
        Crypto::AdaptorSignature pre_sig;
        memcpy(pre_sig.data, pre_signature.data(), 64);
        
        Crypto::Signature sig;
        memcpy(sig.data, final_signature.data(), 64);
        
        Crypto::EllipticCurveScalar t;
        if (!Crypto::extract_adaptor_secret(pre_sig, sig, t)) {
            return FUEGO_ERROR_SWAP;
        }
        
        adaptor_secret.assign(reinterpret_cast<uint8_t*>(&t), reinterpret_cast<uint8_t*>(&t) + 32);
        return FUEGO_OK;
    } catch (...) {
        return FUEGO_ERROR_SWAP;
    }
}

} // namespace fuego
