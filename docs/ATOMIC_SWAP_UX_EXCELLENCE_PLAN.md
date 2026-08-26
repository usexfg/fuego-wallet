# Atomic Swap UX — From Opaque State String to Extravagant, Transparent Theatre

> Goal: every stage of the atomic swap must be visible, explainable, and delightful — not just the BTC SPV confirmation. Users should always know **what happened, what is happening now, what will happen next, and what they can do**. This plan extends `BTC_SPV_REVIEW_AND_PLAN.md` (wire + hardening) into a full-fidelity, product-level UX.

Source of truth for protocol: `xfgo/src/SwapDaemon/SwapTypes.h:39-62`, `SwapStateMachine.cpp:145`, `SwapDaemon.cpp:2162-2237`, `ChainClientResult.h:14`, `ChainClientConfig.cpp:365`. Flutter truth: `lib/services/swap_daemon_client.dart:149-298`, `lib/screens/dex/peer_swap_screen.dart:1-421`, `lib/bloc/dex/dex_cubit.dart:39-1200`, `lib/models/chain_info.dart:51-117`, `lib/utils/theme.dart:1-200`.

---

## 1. Current UX — What a User Sees Today

### The two swap worlds (confusingly separate)

| World | Data source | Screen | Current render |
|-------|-------------|--------|----------------|
| Fuegod orderbook | `DexCubit.activeSwaps` via `POST /getactiveswaps` `dex_cubit.dart:441` -> `SwapStatusSdk` `swap_models.dart:107` (7 strings open/matched/…/cancelled) | `dex_screen.dart` Orderbook/Accept/History tabs `dex_screen.dart:101` | `lastResult`/`error` single-line text `dex_screen.dart:93-118`. No per-swap card, no confirmations, no txid. |
| xfg-swapd (cross-chain, BTC-family included) | `DexCubit.spvSwaps` via `SwapDaemonClient.listSwaps` `swap_daemon_client.dart:124` -> `SwapInfo` `swap_daemon_client.dart:149` (fields: `swapId, state, pair, xfgAmount, ctrAmount, peerEndpoint, timeoutHeight, lockType*` — no `confirmations/blockHeight/spvVerified/ctrLockTxId` parsed `swap_daemon_client.dart:180-234`) | `peer_swap_screen.dart` Direct tab `peer_swap_screen.dart:50` splits `!isTerminal` vs terminal `swap_daemon_client.dart:285` | `_activeSection` `peer_swap_screen.dart:275` = `Container(cardColor)` with `pairName` chip + raw `swap.state` text `peer_swap_screen.dart:320` (e.g. `ADAPTOR_CTR_LOCKED`) + `xfgAmount -> ctrAmount` + short id, buttons `Accept` if `INITIATED` else `Refund`. `_historySection` `peer_swap_screen.dart:371` = icon `check_circle` vs `replay` based on `contains(REFUND\|FAILED)` `peer_swap_screen.dart:385` + `state` text `peer_swap_screen.dart:413`. No stepper, no progress, no explorer link, no fee, no timelock, no PTLC/SPV badge beyond `chain_info.dart:51`. |

Result: **a single state string where a theatre should be**. `ADAPTOR_KEYS_EXCHANGED(10)`, `ADAPTOR_ESCROW_FUNDED(11)`, `ADAPTOR_PRESIGS_READY(12)`, `ADAPTOR_CTR_LOCKED(13)`, `ADAPTOR_WAITING_SPV(17)`, `ADAPTOR_SECRET_CONFIRMED_SPV(18)`, `ADAPTOR_SECRET_REVEALED(14)`, `ADAPTOR_XFG_SPENT(15)`, `ADAPTOR_REFUNDED(16)`, `AFK_OFFER_LOCKED(100)->AFK_OFFER_ACCEPTED(101)->AFK_CLAIMED(102)->AFK_REFUNDED(103)` all look identical. EVM confirmations (12 blocks ETH) and SOL slots have no UI either, not just BTC.

Manual escape hatch `DexCubit.verifyPayment` `dex_cubit.dart:1016` -> `/verify_payment` needs pasted `txHash`, detached from swaps, never auto-polled.

### What users actually ask (and cannot answer today)

- "Did the counterparty commit?" — is `ctrLockTxId` in mempool or not? (no txid shown)
- "Did it land?" — how many confirmations, SPV verified? (no count)
- "Can I claim yet?" — is `requiredConfirmations` met? (threshold hidden)
- "When can I refund?" — dual timelocks `xfgTimeoutHeight` vs `ctrTimeoutBlock` invisible, no countdown
- "What did I pay?" — `xfgAmount` shown, but `ctrAmount` uses same divisor `1e7` for all chains (wrong for 18-dec ETH), no fee breakdown, no `protocolFee` 1% display
- "What lock is this?" — `lockTypeLabel` exists (`swap_daemon_client.dart:236`) but never rendered; PTLC point `ptlcPoint` never shown; no DLEQ verified tick
- "Is this safe?" — `spvVerified`/`crossCheckHeader` majority never surfaced; single-server warning invisible
- "What failed and why?" — `Refund failed: $e` `dex_cubit.dart:1196` generic; no distinction between peer offline, SPV reorg, insufficient funds, timelock not yet expired

---

## 2. Design Principles — Extravagant Means Every Stage Has a Story

1. **Timeline first, cards second.** A horizontal stepper is the primary navigation for a swap, not a list of cards. List is an index; timeline is the experience.
2. **Live, not polled-in-mind.** Confirmations animate as they arrive (`eventSpv` 2-5s). Blocks are orbs that fill; timelock is a wilting hourglass.
3. **Chain-native.** BTC shows block heights, ETH shows block numbers, SOL shows slots — sourced from `msPerBlock()` per pair (add to `SwapTypes.h` / `PriceOracle.cpp` — POLYGON fix already noted in `AGENTS.md`). Each links to its explorer (`mempool.space/tx/{txid}`, `etherscan.io/tx/{txid}`, `solscan.io/tx/{txid}`).
4. **Explain the crypto without dumbing it down.** PTLC point `T=t*G`, `DLEQ Q`, `H(t)` are inspectable in a contract sheet — copyable, verifiable tick, not hidden.
5. **Two timelocks, one truth.** Show *both* heights (XFG refundability and CTR refundability) with `timelockOrderingOk` `SwapDaemon.cpp:768` guarantee visualized as a gap.
6. **Failure is a first-class state.** Failed/lost/reorged states get a dedicated error theatre with cause, retry, refund CTA with countdown, and receipt.
7. **No hidden fees.** Every swap card breaks down `send amount + protocol fee (69/11/20 split link) + network fee`.
8. **AFK is a mode, not a footnote.** AFK pre-lock `AFK_OFFER_LOCKED` has its own entry flow with maker/taker role tint.

Color + motion respect `AppTheme` (`theme.dart:7`): `primaryColor 0xFFD84315` (Fuego), `successColor 0xFF4CAF50`, `warningColor 0xFFFF9800`, `errorColor 0xFFF44336`, `cardColor 0xFF252B33`, `surfaceColor 0xFF1A1F26`, `backgroundColor 0xFF0A0E14`. Dark theatre; warm fire accents.

---

## 3. The New Swap Theatre — Information Architecture

### 3.1 Swap list — elevated from dump to gallery

**Before:** `peer_swap_screen.dart:51` two flat lists.

**After:**

- Top filter bar: `All | Active | Landed | History` + chain filter `Chip` row reusing `ChainInfo.colors/icons` `chain_info.dart:200-241` + search by `swapId` prefix. `All` shows unified view of *both* fuegod `activeSwaps` and `spvSwaps` via adapter (same card shape).
- Each row is `SwapCard` (not raw Container `cardColor`): left chain icon (`ChainInfo.icons`), pair badge (`XFG/BTC`), lockType badge (`PTLC` green `0xFF2E7D32` / `BRIDGE` orange `0xFFEF6C00` / `HTLC` gray — already in `dex_screen.dart:330` but move to shared widget), amount with correct decimals per chain (fix `ctrAmountDecimal /1e7` `swap_daemon_client.dart:298` — ETH 18, SOL 9, BTC 8), primary status line derived from state+confirmations, secondary `ID: abc… • 2m ago` with `createdAt`.
- Card tap -> `SwapDetailScreen(swapId)` (new route), not inline expansion — preserves list scroll, enables shareable deep link `fuego://swap/{swapId}`.

### 3.2 Swap detail — the stepper theatre (the core of excellence)

A single `SwapTimelineStepper` drives the experience. 7 milestones for adaptor (collapsible to 4 on narrow screens), 4 for AFK.

```
[Keys] — [Escrow] — [Presig] — [Commit] — [Confirm] — [Secret] — [Claim]
  10        11        12         13          17/18        14        15
```

- **Horizontal stepper** (desktop) / **vertical stepper** (mobile <600px, `MediaQuery`). Each milestone:
  - Icon: `vpn_key` (keys), `lock` (escrow), `draw` (presig), `anchor` (commit), `verified` (confirm), `key` (secret), `check_circle` (claim) — all from `Icons` already in use.
  - Connector line: gray `surfaceColor` -> animates to `primaryColor` with `AnimatedContainer` 400ms as step completes; current step pulses (`TweenAnimationBuilder` scale 1.0->1.08).
  - Label + timestamp: `updatedAt` per step not yet stored — derive from daemon `updatedAt` delta (Phase 0 adds `stateUpdatedAt` per transition; interim use newest `updatedAt` for current head).
  - Confetti `Lottie` on `ADAPTOR_XFG_SPENT` / `AFK_CLAIMED` (asset `assets/lottie/confetti.json` added).

Milestone copy (replacing raw enum):

| State | Title | Subtitle (live) |
|-------|-------|-----------------|
| `ADAPTOR_KEYS_EXCHANGED(10)` | Keys exchanged | MuSig2 joint key `escrowPubKey` truncated — tap to inspect |
| `ADAPTOR_ESCROW_FUNDED(11)` | XFG escrow funded | `xfgAmount` locked at `escrowTxHash` (link `fuego explorer/tx/{hash}`), awaiting presigs |
| `ADAPTOR_PRESIGS_READY(12)` | Presignatures ready | Nonces exchanged, partial sigs verified — ready for counterparty lock |
| `ADAPTOR_CTR_LOCKED(13)` | Counterparty committed | `ctrLockTxId` seen (mempool) — awaiting confirmations |
| `ADAPTOR_WAITING_SPV(17)` | Confirming on {chain} | `ConfirmationCluster` — `{confirmations}/{requiredConfirmations}` orbs filling, `spvVerified` tick, `blockHeight` + explorer link |
| `ADAPTOR_SECRET_CONFIRMED_SPV(18)` | Confirmed — secret ready | `{confirmations}/{required}` met, SPV verified, secret `t` extractable |
| `ADAPTOR_SECRET_REVEALED(14)` | Secret revealed | `t = s' - s` shown truncated, `DLEQ(Q)` verified tick |
| `ADAPTOR_XFG_SPENT(15)` terminal success | Claimed — complete | Escrow spent, `escrowClaimSigHex` link, receipt available |
| `ADAPTOR_REFUNDED(16)` / `FAILED(7)` terminal fail | Refunded / Failed | Cause card + refund txid + next action |
| `AFK_OFFER_LOCKED(100)` | Offer pre-locked (AFK) | Maker role, pre-lock `chainState` |
| `AFK_OFFER_ACCEPTED(101)` | Offer accepted | Taker CTR lock `ctrLockTxId` |
| `AFK_CLAIMED(102)` | AFK completed | Both sides claimed |
| `AFK_REFUNDED(103)` | AFK refunded | Timeout refund |

### 3.3 Confirmation cluster — the landing theatre

**Widget: `ConfirmationCluster(chain, confirmations, required, spvVerified, blockHeight, txid)`**

- **Orb row:** `required` dots (6 BTC, 12 ETH, 31 SOL — sourced from `requiredConfirmations` `SwapTypes.h:187` per chain). Each dot fills with `primaryColor` as confirmations grow; current confirming dot pulses; verified dots get `check` micro-icon. BTC 6 orbs, LTC 6, BCH 6, KMD 6, DCR 2? — drive from daemon `requiredConfirmations`.
- **Text:** `Landed 3/6 — SPV verified at block 842,110` vs `Seen in mempool — 0/6` vs `Failed to verify — retrying (header pruned)` (wire via `spvError` Phase 0). `blockHeight` tappable -> `get_header` sheet.
- **Live updates:** `DaemonEventBus.eventSpv` (`daemon_event_bus.dart:19` — fix dead code `peer_swap_screen.dart:50` never listened). Flutter listens via `StreamBuilder` on `eventSpv` + `eventSwap`, no manual refresh. Poll 3s while `!isTerminal`.

### 3.4 Timelock hourglass — dual countdown

**Widget: `TimelockCountdown(xfgTimeoutHeight, ctrTimeoutBlock, currentHeightXfg, currentHeightCtr)`**

- Dual bar: upper `XFG refundable in H blocks` (from `timeoutHeight` `SwapInfo:fromJson` `swap_daemon_client.dart:180`), lower `CTR refundable in N blocks`. Heights sourced from daemon `getCurrentHeight` per chain (`BtcChainClient.cpp:639`, etc.) exposed via `SwapInfo.currentHeightCtr/currentHeightXfg` (Phase 0 addition).
- Colors: `warningColor` when <10 blocks, `errorColor` when refundable, `successColor` when safe gap (`timelockOrderingOk` visualized as `CTR timeout < XFG timeout - margin` green gap).
- Tap -> sheet explains "If your counterparty vanishes before secret reveal, you can refund XFG after height H; they can refund CTR after CTR height N."

### 3.5 Contract inspector — HTLC/PTLC transparency

**Bottom sheet: `ContractInspectorSheet(swap)`**

Triggered by tapping any timeline milestone or `chainState` badge.

- Lock type badge + description `ChainInfo.ptlc[ticker]` `chain_info.dart:150` (e.g. `P2WSH point commitment (Taproot Phase2)`).
- `chainState`: for `p2tr:<tweaked> |ptlc:<T>` (`BtcChainClient.cpp:540`) parse and show tweaked pubkey, `T`, truncated; bridge `redeemHex|ptlc:<T>` show HTLC hash `H(t)` plus `T` plus `DLEQ Q` verified tick (`adaptorDleqProof` `SwapTypes.h:118`).
- `hashLock`, `ptlcPoint`, `adaptorPoint`, `adaptorDleqQ` copyable monospace with `Icons.copy` (already in `dex_screen.dart` pattern).
- Explorer: `View on {explorer}` button — URL template from `ChainInfo.info[ticker].explorer` (add field: `mempool.space/tx/{txid}`, `etherscan.io/tx/{txid}`, `blockchair.com/bitcoin-cash/transaction/{txid}`, etc.).

### 3.6 Amount & fee theatre

**Widget: `SwapAmountRow(swap)` replaces `swap_daemon_client.dart:298` naive `/1e7`.**

- Correct decimals: BTC/LTC/BCH/KMD/DCR 8, XMR 12, XFG 7, ETH/ARB/BASE/BNB/POLY 18, SOL 9 — map in `ChainInfo.decimals` (new).
- Display: `1,250.00 XFG  <->  0.0420 BTC` with `xfgAmountDecimal` fix.
- Subline: `Protocol fee 1% (12.50 XFG -> CD yield 69/11/20)` + `Network fee ~0.00012 BTC` (from `m_spvClient->broadcastTx` fee 1000 sat `BchChainClient.cpp:297` — expose `networkFee` via `ChainClientResult` addition). Tap `69/11/20` -> sheet explaining CD yield pool.

### 3.7 Peer & health theatre

- `peerEndpoint` `SwapInfo.peerEndpoint` `swap_daemon_client.dart:180` rendered as `peer@host:18901` with latency dot (ping `SwapP2P` via daemon health). AFK shows `maker vs taker` role tint.
- Health footer: `Daemons: fuegod ●  swapd ●  SPV ●` using `DaemonHealthSnapshot` `fuego-gui` pattern, but per-swap SPV row shows `tipHeight` + server count + `crossCheck` majority `n/2+1` count.

### 3.8 Failure theatre — dignity in failure

When `isTerminal && (state.contains(REFUND)||state==FAILED)` `peer_swap_screen.dart:385` currently generic icon.

New `FailureCard(swap)`:

- Cause enum mapped from `spvError` / `error`: `timeout`, `spv_reorg`, `spv_not_found`, `insufficient_confirmations`, `peer_offline`, `hash_mismatch`, `dust`, `DCR rpc required`.
- Icon `error_outline` + `errorColor` for fail, `warning_amber` + `warningColor` for refunded-by-timeout (not a bug, expected).
- Action: `Refund` button enabled only when `currentHeight >= timeoutHeight` (`SwapDaemon.cpp:2710` guard), else shows countdown; `Retry verify` when `spvError` transient; `Contact peer` copies endpoint.
- Receipt link preserved.

### 3.9 System touches — beyond the screen

- **In-app toast + banner** on `eventSpv` transition: "BTC lock confirmed 6/6 — you can claim" (use `DaemonEventBus` stream).
- **OS notification** (mobile) when `ADAPTOR_SECRET_CONFIRMED_SPV` / `AFK_CLAIMED` while app backgrounded — via `flutter_local_notifications`.
- **Sound + haptics**: soft `tick` per confirmation orb fill, `success` chord on `XFG_SPENT`, `HapticFeedback.mediumImpact` on terminal.
- **Receipt export**: `SwapReceipt` JSON + PDF with `swapId, pair, amounts, lockType, ptlcPoint, txids, confirmations, fees, timestamps` — share via `share_plus`.

---

## 4. File Map — Where It Lands in Flutter + Rust

### 4.1 New Flutter widgets (all under `lib/widgets/swap/`)

```
lib/widgets/swap/
  swap_timeline_stepper.dart      // SwapTimelineStepper (horizontal/vertical, animated connectors)
  confirmation_cluster.dart       // ConfirmationCluster (orbs, spvVerified tick)
  timelock_countdown.dart         // TimelockCountdown (dual bar, urgency colors)
  contract_inspector_sheet.dart   // ContractInspectorSheet (chainState parse, copy, explorer)
  swap_card.dart                  // SwapCard (list row, correct decimals, badges)
  swap_amount_row.dart            // SwapAmountRow (decimals, fee breakdown)
  failure_card.dart               // FailureCard (cause, actions)
  swap_receipt.dart               // SwapReceipt model + PDF export (reuse existing pdf pkg if present)
```

### 4.2 Modified Flutter files

| File | Change |
|------|--------|
| `lib/services/swap_daemon_client.dart:149-298` | **Phase 0 wire** — `SwapInfo` add `ctrLockTxId, confirmations, requiredConfirmations, blockHeight, spvVerified, spvError, currentHeightXfg/currentHeightCtr, networkFee, escrowTxHash/claimTxId`. `fromJson` `lib/services/swap_daemon_client.dart:180-234` parse with `??` defaults. Helpers `isCommitSeen, isLanded, isFailedCommit, shortTxid`. |
| `lib/models/chain_info.dart:51-241` | Add `decimals` map, `explorerTx` template per ticker, keep `ptlc` `chain_info.dart:150`, `supportsPtlc` `chain_info.dart:200`. |
| `lib/services/daemon_event_bus.dart:19-390` | Fix `eventSpv` dead code: `_pollSwapd` `daemon_event_bus.dart:238` emit `eventSpv` when swap has `ctrLockTxId`; health `daemon_event_bus.dart:351` include `spvHeights` map. |
| `lib/bloc/dex/dex_cubit.dart:39-1200` | `loadSpvSwaps` keep polling but no new RPC; add `selectSwap(swapId)` for detail route. Fix `ctrAmountDecimal` per-chain decimals (not `1e7` for ETH/SOL). |
| `lib/screens/dex/peer_swap_screen.dart:50-421` | Replace `_activeSection:275`/`_historySection:371` Container loops with `SwapCard` + filter bar + `SwapTimelineStepper` in card expansion; `swap.state` `peer_swap_screen.dart:320` replaced by copy table (Section 3.2). History uses `FailureCard`. |
| `lib/screens/dex/dex_screen.dart:101-600` | Share `ChainInfo.colors/icons` `chain_info.dart:200` into unified filter bar; reuse `SwapCard` for fuegod `activeSwaps` via adapter (`SwapStatusSdk` -> `SwapInfo` view model). Keep chart `FuegoChart` intact. |
| `lib/utils/theme.dart:7-200` | No new colors — reuse `primary/success/warning/error/card/surface/background`, add `SwapTheme.milestone` extension if needed. |

### 4.3 Rust / daemon (xfgo) — already detailed in `BTC_SPV_REVIEW_AND_PLAN.md` Phase 0

`RpcServer.cpp` `list_swaps` + `swap_status` emit new fields via `getTransactionDetails` (confirm path `SwapDaemon.cpp:2162`), no new endpoint. `SwapDaemon.cpp` re-verify gate (Phase 3) ensures landing signal not TOCTOU. No Flutter breaking change.

### 4.4 Assets

- `assets/lottie/confetti.json` (LottieFiles free) + `assets/lottie/tick.json` for orb fill.
- No new native deps; `flutter_local_notifications`, `share_plus`, `url_launcher` (already used `dex_screen.dart:4`).

---

## 5. Phased Build — Theatre in Acts

Each act ships behind existing flags, additive, revertible, verified per YES.md Rule 3.

### Act 0 — Wire & Correct (2-3 days) — *prereq for everything*

Goal: daemon -> Dart SPV fields flow, decimals corrected.

Edits: `SwapInfo` extension + `ChainInfo.decimals` + `RpcServer.cpp` JSON (as `BTC_SPV_REVIEW_AND_PLAN.md:Phase0`). Fix `ctrAmountDecimal` divisor.

Verify:
```bash
flutter analyze lib/services/swap_daemon_client.dart lib/models/chain_info.dart  # 0 errors
curl -s http://127.0.0.1:18902 -d '{"method":"list_swaps"}' | jq '.result[0]|{state,confirmations,spvVerified,ctrLockTxId}'
```

Rollback: revert 2 files, additive ignore.

### Act 1 — Timeline & Confirmation Cluster (5-7 days) — *the wow*

Goal: `SwapTimelineStepper` + `ConfirmationCluster` + `SwapCard` replace raw `Container` `peer_swap_screen.dart:275` loops. Filter bar, chain icon row.

Edits: new `lib/widgets/swap/*.dart` 4 files + modifications `peer_swap_screen.dart`, `dex_screen.dart`, `daemon_event_bus.dart`.

Verify: `flutter analyze lib/screens/dex/ lib/widgets/swap/` 0 errors; unit `SwapInfo.fromJson` 0/3/6 conf; widget golden test for stepper states 10-18; manual regtest 0->6 orb animation without refresh (listen `eventSpv`).

### Act 2 — Contract Inspector + Timelock + Amount/Fee Theatre (4-5 days)

Goal: bottom sheet inspect `chainState` (`p2tr:` `BtcChainClient.cpp:540` / bridge `redeem|ptlc:`), copy + explorer, `ptlcPoint` + `DLEQ` tick; `TimelockCountdown` dual bar; `SwapAmountRow` correct decimals + fee 1% breakdown 69/11/20.

Edits: `contract_inspector_sheet.dart`, `timelock_countdown.dart`, `swap_amount_row.dart`, `chain_info.dart` explorer templates.

Verify: `flutter test test/contract_inspector_test.dart` (parse `p2tr:` vs `redeem|ptlc:`), `flutter analyze`.

### Act 3 — Failure Theatre + Receipt + History (3-4 days)

Goal: `FailureCard` with cause mapping (`spvError` -> enum), actionable `Refund` countdown (`SwapDaemon.cpp:2710` guard), retry, contact peer; `SwapReceipt` PDF/JSON export; `History` filters + search.

Edits: `failure_card.dart`, `swap_receipt.dart`, `peer_swap_screen.dart:371` history wiring.

Verify: unit cause mapping, manual timeout -> refundable countdown -> refund success `dex_cubit.dart:1193`.

### Act 4 — System Polish — Notifications, Sound, Haptics, Motion (2-3 days)

Goal: `eventSpv` -> in-app banner + `flutter_local_notifications` when backgrounded, tick sound per orb, `HapticFeedback`, confetti on `ADAPTOR_XFG_SPENT(15)` / `AFK_CLAIMED(102)`.

Edits: `daemon_event_bus.dart` banner hook, notification service, lottie assets.

Verify: backgrounded app receives notification on `ADAPTOR_SECRET_CONFIRMED_SPV(18)`; `flutter analyze` + manual UX review on mobile + desktop.

### Act 5 — Hardening & Paranoia (from BTC_SPV_REVIEW_AND_PLAN.md Phases 2-3, interleaved)

DCR fail-closed `Decred/DcrChainClient.cpp:305`, checkpoints `Spv/checkpoints.h`, `minServers=2` warning, `syncHeaders` cross-check `ElectrumSpvClient.cpp:98`, `getTipHeight` median `ElectrumSpvClient.cpp:344`, TLS opt-in `ElectrumConnection.h:27`, re-verify before `broadcastEscrowClaimDirect` `SwapDaemon.cpp:2012`. Surfaced as warnings/badges in cluster, not as separate UX.

Total calendar: **~16-22 days** solo, **~10-14 days** with a second Flutter hand (Acts 1+2 in parallel). Confidence high for Acts 0-3 (UI), medium for Act 5 (consensus-adjacent).

---

## 6. Verification Gates (YES.md — every change gets verified)

| Gate | Command | Pass |
|------|---------|------|
| Dart | `flutter analyze lib/` | 0 errors, 0 warnings |
| Unit | `flutter test test/swap_*.dart` (`SwapInfo`, `ConfirmationCluster`, `ContractInspector`) | all pass |
| Widget | `flutter test test/widgets/swap_timeline_golden_test.dart` | goldens match |
| C++ syntax | `clang++ -fsyntax-only -I src src/SwapDaemon/RpcServer.cpp` | zero errors when link broken |
| C++ tests | `cmake -DBUILD_TESTS=ON && ctest -R "spv|Bch|Ltc|Dcr"` | all pass |
| Manual SPV | regtest lock -> observe `0/6 -> 6/6` orb fill, `spvVerified` tick, explorer link, no refresh needed | yes |
| Manual fail | kill counterparty before 13 -> `ADAPTOR_REFUNDED` card with cause, refund countdown accurate | yes |
| Manual AFK | `AFK_OFFER_LOCKED(100)->101->102` stepper, distinct tint | yes |
| Reorg | regtest reorg dropping lock 6->0 -> holds XFG, re-enters `WAITING_SPV` | verified |

---

## 7. Harsh Truths — What This Does Not Do

- DCR stays verify-only until full-node RPC is productized — `NeutrinoSpvClient::broadcastTx` stub `false` `NeutrinoSpvClient.cpp:836`; UI states it plainly.
- Header PoW alone without retarget checks is not full-node security — mitigated by majority cross-check + fresh checkpoints + work, not claimed as equivalent.
- BTC/LTC/BCH/KMD `lock()` from pure SPV is intentionally blocked `BtcChainClient.cpp:103`; SPV peer is verifier+spender, not funder — matches Alice-locks-CTR protocol.
- `fuego_walletd` stays proxy — not turned into a wallet (`TRANSACTION_BUILDER_PLAN.md`).
- No new chain added, no fee or consensus change, no flag day.

---

## 8. Why This Is Extravagant (Not Just Complete)

- **A swap is a story.** The stepper turns 9 states and 2 timeouts into a narrative you can follow on a phone in sunlight, not a state string you decode.
- **A block is a heartbeat.** Orbs pulse; the chain breathes. Confirmations are felt, not just counted.
- **A contract is inspectable.** Hash, point, script, txid — all copyable, all explorable, all verified ticks — trust but verify, visually.
- **A failure gets dignity.** Not `FAILED` in gray, but a cause, a countdown, and a clear next step — refund, retry, or contact.
- **A success gets celebration.** Confetti on `XFG_SPENT`, not a toast string.

Ship Acts 0-1 and users stop asking "did it land?" Ship 2-3 and they stop asking "what now?" Ship 4 and they *feel* the chain.

*Evidence base: `xfgo/src/SwapDaemon/{SwapTypes.h:39,SwapStateMachine.cpp:145,SwapDaemon.cpp:2162,ChainClientResult.h:14,Bitcoin/BtcChainClient.cpp:103/209/540/649,Spv/*,ChainClientConfig.cpp:365}`, `fuego-flutter-wallet/{lib/services/swap_daemon_client.dart:149,lib/screens/dex/peer_swap_screen.dart:50/275/320/371,lib/bloc/dex/dex_cubit.dart:441/1097,lib/models/chain_info.dart:51,lib/utils/theme.dart:7,lib/screens/dex/dex_screen.dart:101}`.*
