#ifndef FUEGO_ATOMIC_SWAP_H
#define FUEGO_ATOMIC_SWAP_H

#include "fuego_sdk.h"
#include <string>
#include <vector>
#include <cstdint>
#include <memory>

namespace XfgSwap {
    class SwapDaemon; // Forward declaration
}

namespace fuego {

/*
 * Atomic Swap Protocol using Adaptor Signatures
 * ... (rest of documentation)
 */

struct AdaptorSwapInitParams {
    std::string counterparty_address;
    uint64_t xfg_amount;
    std::string counterparty_chain;  // "ETH", "SOL", "BCH", etc.
    uint64_t counterparty_amount;
    std::string wallet_file;
    std::string wallet_password;
};

struct AdaptorSwapInfo {
    char swap_id[65];              // Unique swap identifier
    FuegoSwapState state;          // Current swap state
    char escrow_pubkey[65];        // MuSig2 aggregated escrow key
    char adaptor_point[65];        // T = t*G (adaptor point)
    uint64_t xfg_amount;           // XFG amount
    uint64_t counterparty_amount;  // Counterparty chain amount
    char counterparty_chain[32];   // Counterparty chain name
    char tx_hash[65];              // On-chain transaction hash
    uint64_t created_at;           // Timestamp
    uint64_t expires_at;           // Expiry timestamp
};

class AtomicSwap {
public:
    static FuegoError initiate(const AdaptorSwapInitParams& params,
                                AdaptorSwapInfo* swap_info);

    static FuegoError join(const std::string& swap_id,
                            const std::string& wallet_file,
                            const std::string& wallet_password,
                            AdaptorSwapInfo* swap_info);

    static FuegoError lockFunds(const std::string& swap_id,
                                 const std::string& wallet_file,
                                 const std::string& wallet_password);

    static FuegoError lockCounterpartyFunds(const std::string& swap_id,
                                             const std::string& counterparty_tx_hash);

    static FuegoError complete(const std::string& swap_id,
                                const std::string& wallet_file,
                                const std::string& wallet_password);

    static FuegoError refund(const std::string& swap_id,
                              const std::string& wallet_file,
                              const std::string& wallet_password);

    static FuegoError getInfo(const std::string& swap_id,
                               AdaptorSwapInfo* swap_info);

    static FuegoError extractAdaptorSecret(const std::string& swap_id,
                                            const std::vector<uint8_t>& pre_signature,
                                            const std::vector<uint8_t>& final_signature,
                                            std::vector<uint8_t>& adaptor_secret);

private:
    static XfgSwap::SwapDaemon* getDaemon();
};

} // namespace fuego

#endif // FUEGO_ATOMIC_SWAP_H
