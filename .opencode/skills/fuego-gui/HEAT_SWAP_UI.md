# HEAT, HEARTH & Swap UI Reference

## HEAT Minting UI

### HEAT Basics
- **Peg:** $1.58 USD (launch constant)
- **Mint flow:** Burn XFG → 50% Eternal Flame + 50% Treasury → HEAT at live AMM rate
- **No burn_heat command** — HEAT is currently mint-only

### Pool State Display
RPC: `GET /heat_metrics`
```json
{
  "heat_supply": 1000000,
  "heat_on_deposit": 500000,
  "xfg_heat_ratio": 10.5,
  "heat_peg_usd": 1.58,
  "xfg_spot_usd": 0.15
}
```
**Circulating HEAT** = heat_supply - heat_on_deposit

### Mint Screen Elements
- Current mint rate (XFG per HEAT)
- Minimum mint amount
- Burn amount input
- Preview: XFG burned, HEAT received
- Confirm button

## HEARTH Exchange UI

### Fee Structure
- **HEARTH fee:** 1.0% flat on fills → CD yield pool (NOT to LPs)
- **LP fee:** 0.3% → LP providers as spread reward

### Liquidity Commands
- `hearth_add` — Add XFG + HEAT liquidity
- `hearth_xfg` — Add XFG only
- `hearth_heat` — Add HEAT only
- `hearth_exit` — Remove liquidity
- `hearth_info` — Pool info

### Swap Calculation
```
xfg_out = xfg_reserve - (k / (heat_reserve + heat_in * (1 - fee)))
```

### Pool Constants
- Bootstrap: 144 blocks (~24h AMM-only)
- MIN_DISTINCT_PARTIES: 2
- MAX_ORDERS_PER_BLOCK: 1000
- BASE_SPREAD_BPS: 30
- MAX_SPREAD_BPS: 300

## Atomic Swap UI

### Swap States for Progress Display
| State | Code | Description |
|-------|------|-------------|
| ADAPTOR_KEYS_EXCHANGED | 10 | Keys exchanged |
| ADAPTOR_ESCROW_FUNDED | 11 | Escrow funded |
| ADAPTOR_PRESIGS_READY | 12 | Pre-signatures ready |
| ADAPTOR_CTR_LOCKED | 13 | Counterpart locked |
| ADAPTOR_SECRET_REVEALED | 14 | Secret revealed |
| ADAPTOR_XFG_SPENT | 15 | XFG spent |
| ADAPTOR_REFUNDED | 16 | Refunded |

### AFK v2 States (Non-Interactive)
| State | Code |
|-------|------|
| AFK_OFFER_LOCKED | 100 |
| AFK_OFFER_ACCEPTED | 101 |
| AFK_CLAIMED | 102 |
| AFK_REFUNDED | 103 |

### Swap Fee
- 1% swap fee (SWAP_FEE_RATE_BPS = 100)
- 80% → CD yield pool
- 20% → treasury

### SPV Confirmation States (v1.1)
- ADAPTOR_WAITING_SPV (17)
- ADAPTOR_SECRET_CONFIRMED_SPV (18)

## CD Display

### Constants
- COIN = 10,000,000
- CD_MIN_EPOCHS = 6
- CD_MAX_EPOCHS = 72
- CD_ALLOWED_TIERS = [6, 18, 36, 72]
- LOYALTY_BONUS_PCT = 150

### Interest Formula
```
interest = amount * sum(epoch_fee_rate[i] / total_locked_cd[i])
```

### APY Estimate
```
APY = (0.8 * epoch_swap_fees * 73) / total_cd_locked * 100%
```

### Deposit Types
- **HEAT CDs:** Term length deposits in HEAT, same tiers as XFG
- **Legacy multisig deposits:** Leftover from legacy deposit system

---

**Reference Status:** COMPLETE
**Last Updated:** 2026-08-03
