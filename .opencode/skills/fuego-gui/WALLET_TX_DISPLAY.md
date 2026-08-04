# Wallet & Transaction Display Reference

## Address Format

- **Prefix:** `fire` (base58 encoded)
- **Full format:** `fire<base58-encoded-data>`
- **Prefix value:** 1753191 in base58

## Key System

- **Spend key:** For signing transactions (sending funds)
- **View key:** For reading/auditing transactions
- **Dual-key model:** Enables view-only wallets without spend capability

## Balance Calculation

```
Total = outgoing - incoming commitments
Locked = unlocked_at_height - current_height
Spendable = Total - Locked
```

## Transaction Types

| Type | Code | Description |
|------|------|-------------|
| Regular | 0 | Standard transfer |
| Coinbase | 1 | Mining reward |
| Deposit | 2 | CD deposit |
| Swap | 3 | Atomic swap |

## Extra Tags (for transaction parsing)

| Tag | Purpose |
|-----|---------|
| 0x08 | HEAT commitment |
| 0xCD | COLD commitment |
| 0xD5 | Deposit secret (v10+) |
| 0xFA | Order place (v11+) |
| 0x0F | Order cancel |
| 0xFC | Market buy auth |
| 0xFD | Market sell auth |
| 0xF5 | HEAT mint auth (v12) |
| 0xF6 | AMM swap auth (v12) |
| 0xF7 | LP add auth (v12) |
| 0xF8 | LP remove auth (v12) |
| 0xF9 | HEAT send auth (v12) |

## Deposit Secret (v10+)

- **Tag:** 0xD5
- **Encryption:** chacha8 + ECDH
- **Purpose:** COLD withdrawal recovery
- **Format:** 56 bytes = secret[32] || le64(amount) || le32(network_id) || le32(chain_id) || le32(version) || le32(term)

## Wallet Commands

### Standard
- `get_balance`, `get_address`, `send_transaction`
- `get_payments`, `get_transfers`, `get_unconfirmed`

### HEAT/HEARTH (v11+)
- `mint_heat` — Mint HEAT from XFG
- `hearth_add` — Add liquidity
- `hearth_xfg` — Add XFG only
- `hearth_heat` — Add HEAT only
- `hearth_exit` — Remove liquidity
- `hearth_info` — Pool info

## UI Display Patterns

### Transaction Row
```
[Type Icon] [Amount] [Address/Block] [Time] [Status]
```

### Balance Display
```
Total: 1,234.56 XFG
Locked: 100.00 XFG (12 epochs)
Spendable: 1,134.56 XFG
```

### Address Display
```
fire1qxy2kgdygjrs...  [Copy] [QR]
```

---

**Reference Status:** COMPLETE
**Last Updated:** 2026-08-03
