#include "pool_manager.h"
#include <algorithm>
#include <cmath>
#include <cstring>

#ifdef __SIZEOF_INT128__
using uint128_t = unsigned __int128;
#else
#include <boost/multiprecision/cpp_int.hpp>
using uint128_t = boost::multiprecision::uint128_t;
#endif

namespace fuego {

PoolManager& PoolManager::instance() {
    static PoolManager instance;
    return instance;
}

FuegoError PoolManager::initialize(uint64_t xfg_initial, uint64_t heat_initial,
                                    uint64_t fee_bps) {
    std::lock_guard<std::mutex> lock(m_mutex);

    if (xfg_initial == 0 || heat_initial == 0) {
        return FUEGO_ERROR_INVALID_PARAM;
    }

    memset(&m_reserves, 0, sizeof(m_reserves));
    m_reserves.xfg_reserve = xfg_initial;
    m_reserves.heat_reserve = heat_initial;
    m_reserves.total_lp = static_cast<uint64_t>(
        std::sqrt(static_cast<long double>(xfg_initial) * heat_initial));
    m_reserves.fee_bps = fee_bps;
    m_reserves.k_last = xfg_initial * heat_initial;
    m_initialized = true;

    return FUEGO_OK;
}

FuegoError PoolManager::getReserves(PoolReserves* reserves) {
    std::lock_guard<std::mutex> lock(m_mutex);

    if (!m_initialized) return FUEGO_ERROR_NOT_INITIALIZED;
    if (!reserves) return FUEGO_ERROR_INVALID_PARAM;

    memcpy(reserves, &m_reserves, sizeof(PoolReserves));
    return FUEGO_OK;
}

FuegoError PoolManager::addLiquidity(uint64_t xfg_amount, uint64_t heat_amount,
                                      uint64_t min_lp, PoolLiquidityResult* result) {
    std::lock_guard<std::mutex> lock(m_mutex);

    if (!m_initialized) return FUEGO_ERROR_NOT_INITIALIZED;
    if (xfg_amount == 0 || heat_amount == 0 || !result) return FUEGO_ERROR_INVALID_PARAM;

    memset(result, 0, sizeof(PoolLiquidityResult));

    uint64_t lp_tokens;
    if (m_reserves.total_lp == 0) {
        lp_tokens = static_cast<uint64_t>(
            std::sqrt(static_cast<long double>(xfg_amount) * heat_amount));
    } else {
        uint64_t lp_xfg = (xfg_amount * m_reserves.total_lp) / m_reserves.xfg_reserve;
        uint64_t lp_heat = (heat_amount * m_reserves.total_lp) / m_reserves.heat_reserve;
        lp_tokens = std::min(lp_xfg, lp_heat);
    }

    if (lp_tokens < min_lp) return FUEGO_ERROR_INVALID_PARAM;

    m_reserves.xfg_reserve += xfg_amount;
    m_reserves.heat_reserve += heat_amount;
    m_reserves.total_lp += lp_tokens;
    m_reserves.k_last = m_reserves.xfg_reserve * m_reserves.heat_reserve;

    result->lp_tokens = lp_tokens;
    result->xfg_amount = xfg_amount;
    result->heat_amount = heat_amount;

    return FUEGO_OK;
}

FuegoError PoolManager::removeLiquidity(uint64_t lp_amount, uint64_t min_xfg,
                                         uint64_t min_heat, PoolLiquidityResult* result) {
    std::lock_guard<std::mutex> lock(m_mutex);

    if (!m_initialized) return FUEGO_ERROR_NOT_INITIALIZED;
    if (lp_amount == 0 || lp_amount > m_reserves.total_lp || !result) {
        return FUEGO_ERROR_INVALID_PARAM;
    }

    memset(result, 0, sizeof(PoolLiquidityResult));

    uint64_t xfg_out = (lp_amount * m_reserves.xfg_reserve) / m_reserves.total_lp;
    uint64_t heat_out = (lp_amount * m_reserves.heat_reserve) / m_reserves.total_lp;

    if (xfg_out < min_xfg || heat_out < min_heat) return FUEGO_ERROR_INVALID_PARAM;

    m_reserves.xfg_reserve -= xfg_out;
    m_reserves.heat_reserve -= heat_out;
    m_reserves.total_lp -= lp_amount;
    m_reserves.k_last = m_reserves.xfg_reserve * m_reserves.heat_reserve;

    result->lp_tokens = lp_amount;
    result->xfg_amount = xfg_out;
    result->heat_amount = heat_out;

    return FUEGO_OK;
}

uint64_t PoolManager::calculateSwapOutput(uint64_t reserve_in, uint64_t reserve_out,
                                           uint64_t amount_in, uint64_t fee_bps,
                                           uint64_t* fee_amount) const {
    if (reserve_in == 0 || reserve_out == 0 || amount_in == 0) return 0;

    uint64_t amount_in_with_fee = amount_in * (10000 - fee_bps) / 10000;

    if (fee_amount) {
        *fee_amount = amount_in - amount_in_with_fee;
    }

    uint128_t numerator = static_cast<uint128_t>(amount_in_with_fee) * reserve_out;
    uint128_t denominator = static_cast<uint128_t>(reserve_in) + amount_in_with_fee;

    return static_cast<uint64_t>(numerator / denominator);
}

FuegoError PoolManager::swap(const std::string& input_asset, uint64_t input_amount,
                              uint64_t min_output, PoolSwapResult* result) {
    std::lock_guard<std::mutex> lock(m_mutex);

    if (!m_initialized) return FUEGO_ERROR_NOT_INITIALIZED;
    if (input_amount == 0 || !result) return FUEGO_ERROR_INVALID_PARAM;

    memset(result, 0, sizeof(PoolSwapResult));

    bool is_xfg_input = (input_asset == "XFG");

    uint64_t reserve_in = is_xfg_input ? m_reserves.xfg_reserve : m_reserves.heat_reserve;
    uint64_t reserve_out = is_xfg_input ? m_reserves.heat_reserve : m_reserves.xfg_reserve;

    uint64_t fee_amount = 0;
    uint64_t output_amount = calculateSwapOutput(
        reserve_in, reserve_out, input_amount, m_reserves.fee_bps, &fee_amount);

    if (output_amount < min_output) return FUEGO_ERROR_INVALID_PARAM;
    if (output_amount >= reserve_out) return FUEGO_ERROR_INVALID_PARAM;

    if (is_xfg_input) {
        m_reserves.xfg_reserve += input_amount;
        m_reserves.heat_reserve -= output_amount;
    } else {
        m_reserves.heat_reserve += input_amount;
        m_reserves.xfg_reserve -= output_amount;
    }

    m_reserves.k_last = m_reserves.xfg_reserve * m_reserves.heat_reserve;

    long double old_price = static_cast<long double>(reserve_out) / reserve_in;
    long double new_price = static_cast<long double>(
        is_xfg_input ? m_reserves.heat_reserve : m_reserves.xfg_reserve) /
        (is_xfg_input ? m_reserves.xfg_reserve : m_reserves.heat_reserve);

    long double price_impact = (old_price - new_price) / old_price;
    if (price_impact < 0) price_impact = -price_impact;

    result->input_amount = input_amount;
    result->output_amount = output_amount;
    result->fee_amount = fee_amount;
    result->price_impact_bps = static_cast<uint64_t>(price_impact * 10000);

    return FUEGO_OK;
}

FuegoError PoolManager::getLPBalance(const std::string& address, uint64_t* balance) {
    std::lock_guard<std::mutex> lock(m_mutex);

    if (!m_initialized) return FUEGO_ERROR_NOT_INITIALIZED;
    if (!balance) return FUEGO_ERROR_INVALID_PARAM;

    auto it = m_lp_balances.find(address);
    *balance = (it != m_lp_balances.end()) ? it->second : 0;
    return FUEGO_OK;
}

FuegoError PoolManager::getEstimatedOutput(const std::string& input_asset,
                                            uint64_t input_amount, uint64_t* output_amount) {
    std::lock_guard<std::mutex> lock(m_mutex);

    if (!m_initialized) return FUEGO_ERROR_NOT_INITIALIZED;
    if (input_amount == 0 || !output_amount) return FUEGO_ERROR_INVALID_PARAM;

    bool is_xfg_input = (input_asset == "XFG");
    uint64_t reserve_in = is_xfg_input ? m_reserves.xfg_reserve : m_reserves.heat_reserve;
    uint64_t reserve_out = is_xfg_input ? m_reserves.heat_reserve : m_reserves.xfg_reserve;

    *output_amount = calculateSwapOutput(
        reserve_in, reserve_out, input_amount, m_reserves.fee_bps, nullptr);

    return output_amount ? FUEGO_OK : FUEGO_ERROR_INVALID_PARAM;
}

} // namespace fuego
