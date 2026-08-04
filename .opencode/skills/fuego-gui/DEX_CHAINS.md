# DEX Chain Selection Reference

## Supported Chains (12)

| Ticker | Name | Type | HTLC | Connection |
|--------|------|------|------|------------|
| BTC | Bitcoin | UTXO | P2WSH SegWit | Electrum SPV |
| LTC | Litecoin | UTXO | P2WSH SegWit | Electrum SPV |
| KMD | Komodo | UTXO | P2SH | Electrum SPV |
| BCH | Bitcoin Cash | UTXO | P2SH | Electrum SPV |
| ETH | Ethereum | EVM | HashedTimelock.sol | JSON-RPC |
| ARB | Arbitrum | EVM L2 | HashedTimelock.sol | JSON-RPC |
| BASE | Base | EVM L2 | HashedTimelock.sol | JSON-RPC |
| BNB | BNB Chain | EVM | HashedTimelock.sol | JSON-RPC |
| SOL | Solana | Non-EVM | On-chain HTLC | JSON-RPC |
| POLY | Polygon | EVM | HashedTimelock.sol | JSON-RPC |
| DCR | Decred | UTXO | P2SH | Neutrino SPV |
| XMR | Monero | CryptoNote | Ring sigs | monerod RPC |

## Chain Metadata Maps (in `_DexScreenState`)

### _chainNames
```dart
static const Map<String, String> _chainNames = {
  'BTC': 'Bitcoin', 'LTC': 'Litecoin', 'KMD': 'Komodo', 'BCH': 'Bitcoin Cash',
  'ETH': 'Ethereum', 'ARB': 'Arbitrum', 'BASE': 'Base', 'BNB': 'BNB Chain',
  'SOL': 'Solana', 'POLY': 'Polygon', 'DCR': 'Decred', 'XMR': 'Monero',
};
```

### _chainDesc
```dart
static const Map<String, String> _chainDesc = {
  'BTC': 'Digital gold — the original UTXO chain with deepest liquidity.',
  'LTC': 'Fast, lightweight Bitcoin fork with low fees and mature SPV.',
  'KMD': 'Komodo — delayed PoW with built-in atomic swap support.',
  'BCH': 'Bitcoin Cash — high-throughput UTXO chain for everyday payments.',
  'ETH': 'Smart contract platform — largest DeFi ecosystem.',
  'ARB': 'Arbitrum — Ethereum L2 with fast finality and low gas.',
  'BASE': 'Base — Coinbase L2 on the OP Stack, fast and cheap.',
  'BNB': 'BNB Chain — EVM-compatible, high throughput, low fees.',
  'POLY': 'Polygon — Ethereum sidechain with fast 2s blocks.',
  'SOL': 'Solana — high-performance non-EVM chain with sub-second slots.',
  'DCR': 'Decred — hybrid PoW/PoS with built-in governance and Neutrino SPV.',
  'XMR': 'Monero — privacy coin using ring signatures and stealth addresses.',
};
```

### _chainInfo
```dart
static const Map<String, Map<String, String>> _chainInfo = {
  'BTC': {'type': 'UTXO', 'connect': 'Electrum SPV (public servers)', 'user': 'No setup needed.', 'htlc': 'P2WSH SegWit'},
  'ETH': {'type': 'EVM', 'connect': 'Ethereum JSON-RPC (Infura/Alchemy)', 'user': 'No setup needed.', 'htlc': 'HashedTimelock.sol'},
  // ... etc for all 12
};
```

### _chainColors
```dart
static const Map<String, Color> _chainColors = {
  'BTC': Color(0xFFF7931A), 'LTC': Color(0xFFBFBBBB), 'KMD': Color(0xFF2B6DE9),
  'BCH': Color(0xFF8DC351), 'ETH': Color(0xFF627EEA), 'ARB': Color(0xFF28A0F0),
  'BASE': Color(0xFF0052FF), 'BNB': Color(0xFFF0B90B), 'POLY': Color(0xFF8247E5),
  'SOL': Color(0xFF9945FF), 'DCR': Color(0xFF2970FF), 'XMR': Color(0xFFFF6600),
};
```

### _chainIcons
```dart
static const Map<String, String> _chainIcons = {
  'BTC': 'assets/coin icons/btc.png',
  'LTC': 'assets/coin icons/ltc.png',
  // ... etc
  'POLY': 'assets/coin icons/matic.png', // Polygon rebrand
  'XMR': 'assets/coin icons/monero-xmr-logo.png',
};
```

## Pair Bar Layout

```
[Fuego Logo] XFG / [Chain Selector] [Type Badge] ... [Info] [Status] [Refresh]
```

- Fuego logo: `assets/coin icons/fuego.png` (20x20)
- Chain selector: icon + ticker + dropdown arrow
- Type badge: UTXO/EVM/Non-EVM label
- Status: green (connected) or red (disconnected)

## Adding a New Chain

1. Add entry to all 6 maps in `_DexScreenState`
2. Add icon asset to `assets/coin icons/`
3. Update `_chainInfo` with connection details
4. Add color to `_chainColors`
5. Test selector and info dialogs

---

**Reference Status:** COMPLETE
**Last Updated:** 2026-08-03
