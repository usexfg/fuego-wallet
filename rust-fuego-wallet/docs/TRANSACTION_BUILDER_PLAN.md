# Fuego Rust Transaction Builder — Plan & Implementation Guide

Status: plan. Owner: TBD. Blocks: XFG send, balance, history, CDs, HEARTH swaps, GUI order-making.

## 1. Verified current state

**Chain is plain CryptoNote today.** Correcting the earlier assumption: there are **no
Pedersen commitments in consensus**. `amountCommitment` appears nowhere in
`CryptoNoteTools.cpp` / `Blockchain.cpp` / `Core.cpp` — outputs carry **visible
amounts** and standard key images. The commitment machinery that exists
(`mlsag.h` two-layer MLSAG, `DepositCommitment`, `deriveCommitmentKeys`,
`TX_EXTRA_YIELD_COMMITMENT`) is dormant or CD-specific. Therefore the Rust builder
targets **standard MLSAG ring signatures over visible amounts** — no RingCT layer
in scope until the chain activates it.

**What Rust already has:**

| Component | Location | State |
|-----------|----------|-------|
| Ed25519 keys, derivation, one-time keys, key image, addresses, base58 | `fuego-sdk/fuego-crypto/src/lib.rs` | ✅ real |
| Block/tx/UTXO structs | `fuego-sdk/fuego-sdk/src/types.rs` | ✅ real |
| Block scanning + wallet state | `fuego-sdk/fuego-sdk/src/scanner.rs` | ⚠️ `scan_block` real, `build_transaction` is a stub (no signatures, `// TODO: Derive recipient pubkey`) |
| Persistence | `fuego-sdk/fuego-sdk/src/store/sled.rs` | ✅ real |
| Daemon client | `core/src/daemon.rs` | ⚠️ `get_info/get_height/get_block_hash/send_raw_tx` only |
| walletd handlers | `core/src/wallet.rs` | ❌ `send_transaction` errors, `get_balance` hardcodes 0, `get_transactions` empty |

**fuegod RPC surface (verified):** `/queryblocks.bin`, `/queryblockslite.bin`
(scanning), `/getrandom_outs.bin` + `/getrandom_outs_json` (decoys),
`/sendrawtransaction` (submit). `is_key_image_spent` is used in-process; **no
dedicated RPC endpoint found — add `/is_key_image_spent` in Phase 1.**

**C++ reference for decoy selection:** bucket-based picker in
`src/WalletLegacy/WalletTransactionSender.cpp:1592+` (base10 bucket separation +
shuffle). Port this exactly; decoy distribution is a privacy property.

**C++ ring signature to port:** `generate_ring_signature` / `check_ring_signature`
(`src/crypto/crypto-ops.c`, exposed via `src/crypto/crypto.h:262`), key image via
`hash_to_ec` (`H_p`). Rust already has `hash_to_ec`-equivalent
(`fuego_crypto::generate_key_image`).

## 2. Goal & unlock list

Ship one `send_transaction` that fuegod accepts. This single function unblocks:

1. **Send XFG** (walletd `sendTransaction` + Flutter send screen)
2. **Real balance** (UTXO sum instead of hardcoded 0)
3. **Transaction history** (scan results instead of empty)
4. **CD create/claim** (deposit tx + withdrawal are the same builder + extra tags)
5. **HEARTH swap / mint_heat** (same builder + HEAT extra tags)
6. **GUI order-making** (`create_afk_lock` = self-transfer with unlock time)

## 3. Architecture

```
fuegod RPC (queryblocks/getrandom_outs/sendrawtransaction/is_key_image_spent)
        ▲                        ▲
        │ blocks                 │ decoys + submit
┌───────┴─────────┐      ┌───────┴──────────────┐
│  SyncEngine     │      │  TransactionBuilder  │
│  (scanner.rs)   │─────▶│  (new: builder.rs)   │
│  view-key scan  │ utxos│  MLSAG + decoys +    │
│  → UtxoScanner  │      │  binary serialization│
└───────┬─────────┘      └───────┬──────────────┘
        │ sled store             │ tx hex
        ▼                        ▼
      walletd handlers (core/src/wallet.rs) ──▶ Flutter send screen
```

New files: `fuego-sdk/fuego-sdk/src/ring_signature.rs`,
`fuego-sdk/fuego-sdk/src/transaction_builder.rs`,
`fuego-sdk/fuego-sdk/src/serialization.rs`. Modified: `scanner.rs`, `network/rpc.rs`,
`core/src/daemon.rs`, `core/src/wallet.rs`, `core/src/wallet_service.rs`.

## 4. Phases

Each phase ends with a runnable acceptance check. No phase starts before its
predecessor's check passes.

### Phase 1 — RPC plumbing (0.5–1 day)
- Add `/is_key_image_spent` JSON endpoint to fuegod `src/Rpc/RpcServer.cpp`
  (mirror the reserve-proof style; validate 64-hex input).
- Rust `DaemonClient`: `query_blocks(from, count)`, `get_random_outs(amounts, count)`,
  `is_key_image_spent(image_hex)`.
- **Gate:** `get_random_outs` returns decoys matching the C++ wallet's request for
  the same amounts; `is_key_image_spent` round-trips on a known-spent image.

### Phase 2 — Sync engine (1–2 days)
- Feed real blocks to the existing `UtxoScanner::scan_block` from a background
  loop: start at stored height, pull `/queryblocks.bin`, advance, persist to sled
  (state: height, utxos, key images, history).
- Output discovery rule (standard CryptoNote): for each output key `P` and tx
  public key `R`: `P == H_s(a·R || index)·G + B` → ours (a = view secret, B =
  spend pub). Rust primitives exist (`generate_key_derivation`, `derive_public_key`).
- Track our key images (`generate_key_image`), mark spent via RPC.
- **Gate:** wallet with a funded testnet account shows the exact balance and
  history the C++ `fire_wallet` shows for the same keys.

### Phase 3 — MLSAG ring signature (2–3 days, the crypto core)
Port `generate_ring_signature` + `check_ring_signature` to Rust, following
`crypto-ops.c` exactly:
- Key image: `I = x · H_p(P)` (have `hash_to_ec`).
- Ring: pubs[ring], real index `s`; responses `r[i]` random scalars for i≠s;
  challenges chained: `L_i = r_i·G + c_i·P_i`, `R_i = r_i·H_p(P_i) + c_i·I`;
  `c_{i+1} = H_s(prefix_hash || L_i || R_i)`; close the ring at `c_s`.
- Signature = `c_0 ‖ r[0..ring]`; verify inverts the chain.
- **Cross-language gate (mandatory):** Rust-signed ring verifies under
  `Crypto::check_ring_signature` in a C++ test harness (same pattern as the
  reserve-proof verification). Roundtrip both directions. Also port the
  generation → self-verify roundtrip as a unit test with deterministic RNG.

### Phase 4 — Transaction assembly (1–2 days)
In `transaction_builder.rs`:
- Recipient address → spend pubkey (parse 98-char address; validate prefix).
- One-time output keys: fresh `r` per output, `R = r·G` in txout, `P = H_s(r·B')·G
  + B'` where B' = recipient spend pubkey (delegate key derivation via the daemon
  if the recipient uses an integrated address — else standard key).
- Change output back to a fresh wallet subaddress key (reuse vault derivation).
- Fee: `minimumFee` from daemon info; dust handling: fold dust into fee.
- Decoy selection: port the bucket picker from
  `WalletTransactionSender.cpp:1592+` over `/getrandom_outs`; real input placed
  per the C++ shuffle.
- Coin selection: greedy-largest-first matching `scanner.rs` (existing), with the
  C++ two-output fallback rule if change would be dust.
- **Gate:** built tx (pre-signature) byte-matches a C++-wallet-built tx for the
  same inputs/outputs modulo decoys (compare with a fixed RNG seed on both sides).

### Phase 5 — Binary serialization + submit (1–2 days)
- Port `Transaction` wire layout from `CryptoNoteSerialization.cpp` exactly:
  `version, unlock_time, inputs (KeyInput: amount, offsets, keyImage), outputs
  (amount, target.key), extra, signatures[c0 ‖ r[]]`. Varint-encode offsets as
  global-index differences like C++.
- `send_raw_tx` submit; parse status ("OK"/fail reasons) into walletd errors.
- **Gate:** a C++ `parse_and_validate` harness deserializes the Rust tx and
  `check_ring_signature` passes; a signed tx submitted to a testnet daemon lands
  in the mempool (`/get_transaction_pool` shows it).

### Phase 6 — walletd + Flutter wiring (0.5–1 day)
- Replace the stubs in `core/src/wallet.rs`/`wallet_service.rs`: `send_transaction`
  (unlock check → builder → submit), `get_balance` (scanner state), `get_transactions`
  (scanner history). Persist-before-broadcast ordering (crash safety).
- Wire the Flutter send screen result/error paths (already calls `sendTransaction`).
- **Gate:** GUI send on testnet moves funds; balance/history update after the
  block lands.

### Phase 7 — Downstream unblocks (2–4 days, after Phase 6 ships)
Same builder, new command bodies:
- `create_cd` / `claim_cd`: deposit/withdrawal extras (`TX_EXTRA_YIELD_COMMITMENT`
  tags, `deriveCommitmentKeys` port) per `WalletLegacy::createDeposit` flow.
- `create_afk_lock`: self-transfer with `unlockTimestamp` + AFK key data (port
  `WalletLegacy::create_afk_lock`, reuse the persisted AFK secret storage already
  shipped) → unblocks GUI order-making.
- HEARTH `swap`/`mint_heat`: heat extras per the v11 wallet commands.
- **Gate:** CD mint→claim roundtrip and an AFK lock/claim on testnet.

### Phase 8 — Testnet gates (ship criteria)
1. Send 1 XFG to a fresh address from GUI; balance/history correct.
2. CD create → interest claim → withdrawal.
3. AFK order: GUI posts offer (maker), CLI taker fills end-to-end.
4. Forced restart mid-send: no double-spend, funds safe.
5. Cross-check ring signatures against `check_ring_signature` in CI.

## 5. Risks & mitigations

| Risk | Class | Mitigation |
|------|-------|-----------|
| Ring signature bug | fund loss | Phase 3 cross-language gates both directions; CI runs C++ verify on Rust-built rings |
| Serialization byte drift | rejected txs | golden vectors generated by C++ wallet; varint layout unit-tested |
| Decoy distribution bias | privacy | port the C++ bucket picker verbatim; never invent a new picker |
| Crash mid-broadcast | double state | persist tx before submit; re-query mempool on restart before re-submitting |
| Scanned-state divergence | wrong balance | reconcile against `check_reserve_proof`-style daemon balance RPC in tests |

## 6. Effort

Phases 1–6 (the core builder, which is what the user asked for): **~8–12 focused
days**. Phase 7 (CDs/HEARTH/order-making) adds 2–4. Phase 8 is validation, not
build time.

---

## Session handoff notes (for whoever picks this up)

- **Source of truth for the C++ daemon code: `/Users/aejt/xfgo`** (fuego-suite @
  origin/master, pushed). NOT `/Users/aejt/fuego`, NOT the DEXFG copies.
- **Another agent is actively working both repos.** Expect working-tree churn in
  `lib/screens/dex/*` (Flutter) and `src/CryptoNoteCore/*`, `src/Rpc/*` (C++).
  Commit only your own hunks — filter with `git diff` + `git apply --cached`
  (see git history for the pattern). Never fix their WIP.
- The fuego-suite working tree has been link-broken by the other session's digm
  work (`BancorCurve.cpp` reference, `Blockchain.cpp` digm symbols). For C++
  verification of your files, use `clang++ -fsyntax-only` with the flags in
  `build_presig/src/CMakeFiles/Rpc.dir/flags.make` instead of full builds until
  their work lands. `build_presig/` is the tests-enabled build dir.
- C++ build: `cmake -DUSE_VENDORED_SECP256K1=OFF -DBUILD_TESTS=ON`; swap tests run
  from `build_presig/src/test_daemons/`.
- Flutter verify: `flutter analyze <files>`; the repo lints at info-level noise
  but must stay at 0 **errors**.
- Cross-language verification pattern already proven in this session: Dart/REPL
  output → C++ scratch harness using the production classes (`Secp256k1Signer`,
  `Base58Std`, `keccak.c`) → compare. Reuse it for ring-signature gates (Phase 3).
- Keys to grep when porting: `generate_ring_signature`, `check_ring_signature`
  (crypto-ops.c), bucket picker (`WalletTransactionSender.cpp:1592+`),
  tx serialization (`CryptoNoteSerialization.cpp`), `createDeposit` flow
  (WalletLegacy.cpp).
