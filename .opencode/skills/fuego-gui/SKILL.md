---
name: fuego-gui
description: Fuego Wallet Flutter GUI development guide. Covers daemon management (unified/separate modes), network settings, DEX chain selection, HEAT/HEARTH minting, atomic swap UI, CD interest display, wallet addresses/keys, transaction display, mining status, settings screen, and UI branding. Use when working on any Flutter UI in the Fuego wallet app including screens, services, blocs, widgets, or theming.
---

# Fuego GUI Skill

## Purpose

Comprehensive reference for the Fuego Wallet Flutter GUI architecture. Covers all screens, services, daemon integration, and domain-specific UI patterns.

## When to Use

- Modifying daemon status bar or health monitoring
- Changing network connection settings (Local/Remote toggle)
- Updating DEX chain selection or pair bar
- Editing settings screen or about dialog
- Working on HEAT minting or HEARTH exchange UI
- Building swap progress or atomic swap screens
- Displaying CD interest, APY, or deposit info
- Showing wallet addresses, balances, or transaction history
- Changing wallet branding or naming
- Adding new screens or modifying existing ones

## When NOT to Use

- C++ daemon internals (use fuego-crypto, fuego-network)
- Mining algorithm changes (use fuego-miner)
- Smart contract development (use fuego-swaps for swap protocol)
- Backend SDK work (use fuego-wallet)

---

## Quick Reference

### Key Files

| File | Purpose |
|------|---------|
| `lib/main.dart` | App entry, daemon startup, global instances |
| `lib/screens/main/main_screen.dart` | Daemon status bar, bottom nav |
| `lib/screens/home/home_screen.dart` | Wallet balance, send/receive |
| `lib/screens/dex/dex_screen.dart` | DEX UI, chain selection, pair bar |
| `lib/screens/fuego/hearth/hearth_screen.dart` | HEAT minting, HEARTH exchange |
| `lib/screens/fuego/cd/cd_overview_screen.dart` | Certificates of Deposit |
| `lib/screens/settings/settings_screen.dart` | Settings, network, about |
| `lib/services/daemon_manager.dart` | Daemon lifecycle |
| `lib/services/daemon_event_bus.dart` | Health polling, events |
| `lib/services/fuego_rpc_service.dart` | RPC client |
| `lib/services/fuego_vault_service.dart` | Key management |
| `lib/bloc/dex/dex_cubit.dart` | DEX state management |
| `lib/bloc/wallet/wallet_cubit.dart` | Wallet state management |
| `lib/models/swap_models.dart` | Swap pair, offer, trade models |
| `lib/utils/theme.dart` | AppTheme color constants |

### Port Layout

| Port | Service |
|------|---------|
| 18180 | fuegod daemon RPC |
| 18189 | walletd HTTP proxy (Dart connects here) |
| 18902 | xfg-swapd JSON-RPC |
| 18900 | xfg-swapd status server |
| 18901 | xfg-swapd P2P |

### Daemon Modes

**Unified (preferred):** Single `unified` binary, `--local` flag, P2P disabled, health via JSON-RPC `getHealth` on port 18189.

**Separate (fallback):** Three independent processes when unified binary not found.

---

## Domain Knowledge

### Wallet Addresses & Keys

- **Address format:** `fire<base58>` (prefix "fire" = 1753191 in base58)
- **Dual-key system:** Spend key (signing) + View key (reading/audit)
- **Balance:** Total = outgoing - incoming commitments; Locked = unlocked at height - current; Spendable = Total - Locked
- **Deposit Secret (v10+):** Tag 0xD5, encrypted with chacha8 + ECDH for COLD recovery

### Transaction Display

| Type | Code | Display |
|------|------|---------|
| Regular | 0 | Standard transfer |
| Coinbase | 1 | Mining reward |
| Deposit | 2 | CD deposit |
| Swap | 3 | Atomic swap |

**Extra tags to parse:** 0x08 (HEAT), 0xCD (COLD), 0xD5 (deposit secret), 0xFA-0xFC (orderbook), 0xF5-0xF9 (v12 auth)

### HEAT & HEARTH

- **HEAT peg:** $1.58 USD (launch constant)
- **HEAT mint:** Burn XFG → 50% Eternal Flame + 50% Treasury → HEAT at live AMM rate
- **HEARTH fee:** 1.0% flat on fills (routes to CD yield pool)
- **LP fee:** 0.3% (goes to LP providers)
- **Pool state RPC:** `GET /heat_metrics` → `heat_supply`, `heat_on_deposit`, `xfg_heat_ratio`, `heat_peg_usd`, `xfg_spot_usd`
- **Commands:** `mint_heat`, `hearth_add`, `hearth_xfg`, `hearth_heat`, `hearth_exit`, `hearth_info`

### Atomic Swaps

**Supported pairs:** SOL(0), ETH(1), XMR(2), BCH(3), ARB(4), BASE(5), KMD(6), BNB(7), DCR(8), BTC(9), LTC(10), POLYGON(11)

**Swap states for progress UI:**
1. ADAPTOR_KEYS_EXCHANGED (10)
2. ADAPTOR_ESCROW_FUNDED (11)
3. ADAPTOR_PRESIGS_READY (12)
4. ADAPTOR_CTR_LOCKED (13)
5. ADAPTOR_SECRET_REVEALED (14)
6. ADAPTOR_XFG_SPENT (15)
7. ADAPTOR_REFUNDED (16)

**AFK v2 states (non-interactive):** AFK_OFFER_LOCKED(100), AFK_OFFER_ACCEPTED(101), AFK_CLAIMED(102), AFK_REFUNDED(103)

**Fee:** 1% swap fee (80% CD yield, 20% treasury)

### Certificates of Deposit

- **Constants:** COIN = 10,000,000; CD_MIN_EPOCHS = 6; CD_MAX_EPOCHS = 72
- **Tiers:** 6, 18, 36, 72 epochs
- **Interest:** `amount * sum(epoch_fee_rate[i] / total_locked_cd[i])`
- **APY estimate:** `(0.8 * epoch_swap_fees * 73) / total_cd_locked * 100%`
- **HEAT CDs:** Term length deposits in HEAT, same tiers as XFG

### Mining Status

- **Difficulty:** Zawy LWMA-1 (N=39), target 480s
- **Reward:** `(reward_base - already_generated) / 2^(height / 2^20)`
- **Hashrate:** `difficulty * 2^32 / block_time_seconds`

---

## UI Patterns

### Status Indicators

- Green dot = connected/running
- Red dot = disconnected/error
- Orange = testnet mode

### Color Theme

`AppTheme.primaryColor`, `.successColor`, `.errorColor`, `.warningColor`, `.textPrimary`, `.textSecondary`, `.surfaceColor`

### Widget Patterns

- `_buildSettingsTile()` — standard settings row
- `_buildSectionHeader()` — section title
- `_daemonDetail()` — daemon error row
- `_chainInfoRow()` — chain info label/value

### DaemonHealthSnapshot

Fields: `fuegodRunning`, `walletdRunning`, `swapdRunning`, `fuegodError`, `walletdError`, `swapdError`, `allHealthy`, `displayText`

### DaemonManager Getters

`unifiedRunning`, `fuegodRunning`, `walletdRunning`, `swapdRunning` — each true if unified or separate daemon active

---

## Branding Rules

**Correct:** Fuego Wallet
**Incorrect:** XF₲ Wallet, XFG Wallet, Fuego-Wallet

**Biometric:** "Enable biometric authentication for Fuego Wallet"
**About:** "A privacy-focused cryptocurrency wallet for Fuego (XFG)"

---

**Skill Status:** COMPLETE
**Last Updated:** 2026-08-03
**Version:** 2.0
