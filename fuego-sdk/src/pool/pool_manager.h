#ifndef FUEGO_POOL_MANAGER_H
#define FUEGO_POOL_MANAGER_H

#include "fuego_sdk.h"
#include <string>
#include <vector>
#include <map>
#include <cstdint>
#include <mutex>

namespace fuego {

struct PoolReserves {
    uint64_t xfg_reserve;   // XFG in pool (atomic units)
    uint64_t heat_reserve;  // HEAT in pool (atomic units)
    uint64_t total_lp;      // Total LP tokens outstanding
    uint64_t fee_bps;       // Fee in basis points (30 = 0.3%)
    uint64_t k_last;        // Last recorded k = xfg * heat
};

struct PoolSwapResult {
    uint64_t input_amount;   // Amount paid
    uint64_t output_amount;  // Amount received
    uint64_t fee_amount;     // Fee collected
    uint64_t price_impact_bps; // Price impact in basis points
};

struct PoolLiquidityResult {
    uint64_t lp_tokens;       // LP tokens minted/burned
    uint64_t xfg_amount;      // XFG added/removed
    uint64_t heat_amount;     // HEAT added/removed
};

class PoolManager {
public:
    static PoolManager& instance();

    FuegoError initialize(uint64_t xfg_initial, uint64_t heat_initial,
                          uint64_t fee_bps = 30);

    FuegoError getReserves(PoolReserves* reserves);

    FuegoError addLiquidity(uint64_t xfg_amount, uint64_t heat_amount,
                            uint64_t min_lp, PoolLiquidityResult* result);

    FuegoError removeLiquidity(uint64_t lp_amount, uint64_t min_xfg,
                               uint64_t min_heat, PoolLiquidityResult* result);

    FuegoError swap(const std::string& input_asset, uint64_t input_amount,
                    uint64_t min_output, PoolSwapResult* result);

    FuegoError getLPBalance(const std::string& address, uint64_t* balance);

    FuegoError getEstimatedOutput(const std::string& input_asset,
                                  uint64_t input_amount, uint64_t* output_amount);

private:
    PoolManager() = default;

    uint64_t calculateSwapOutput(uint64_t reserve_in, uint64_t reserve_out,
                                  uint64_t amount_in, uint64_t fee_bps,
                                  uint64_t* fee_amount) const;

    PoolReserves m_reserves;
    std::map<std::string, uint64_t> m_lp_balances;
    std::mutex m_mutex;
    bool m_initialized = false;
};

} // namespace fuego

#endif // FUEGO_POOL_MANAGER_H
