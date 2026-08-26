# BTC-Chain SPV Review and Plan

> Scope: BTC, LTC, BCH, KMD, DCR (BTC-family). Sources: `xfgo/src/SwapDaemon` as primary, `fuego-flutter-wallet/lib` and `rust-fuego-wallet/fuego-sdk` as UI/SDK exposure layer. All claims cite `file:line`.

Date: 2026-08-26
Baseline: OKOC + YES.md governance, evidence-first, no speculation.

---

## 1. What Exists Today — Truth Table

### 1.1 Chain transport

| Chain | Config keys | SPV stack | Header sync | Lock | Verify | Claim / Refund (SPV path) | Notes |
|-------|-------------|-----------|-------------|------|--------|---------------------------|-------|
| BTC | `btc_mode=spv`, `btc_spv_server_*`, `btcSpvMinServers`, `btcSpvCheckpointHeight/Hash`, `btcWif` — `ChainClientConfig.cpp:365-372`, `SwapDaemon.cpp:368-386` | `ElectrumSpvClient` (`ElectrumSpvClient.h:28`, `.cpp:21-803`) + `SpvHeaderStore` (`SpvHeaderStore.h:25`) + `SpvMerkle` (`SpvMerkle.h:38`) | `syncHeaders` batch 2000 from `blockchain.block.headers` `ElectrumSpvClient.cpp:98-152`, tip via `blockchain.headers.subscribe` `ElectrumSpvClient.cpp:59` | Blocked `BtcChainClient.cpp:103` `fail(SPV mode does not support lock)` — correct. BTC side in protocol is always the counterparty-lock that the *other* party creates, so SPV peer only needs to *verify* not *fund*. | `verifyLockSpv` `BtcChainClient.cpp:701-851` scans raw tx for `P2WSH 00 20 <32>` `BtcChainClient.cpp:816`, binds `sha256(redeem)==hash` `BtcChainClient.cpp:819`, then `verifyTxInclusion` `BtcChainClient.cpp:840` with `depth` `BtcChainClient.cpp:849`. PTLC P2TR path `verifyPtlcLock` `BtcChainClient.cpp:209-277` scans `51 20 <xonly>` `BtcChainClient.cpp:254`. `getTransactionDetails` `BtcChainClient.cpp:649` returns `confirmed/spvVerified/confirmations=tip-height+1` `BtcChainClient.cpp:670` | Local signing from `WIF` `BtcChainClient.cpp:379`, `signInput` + `buildRawSegWitTx`, `m_spvClient->broadcastTx` `BtcChainClient.cpp:317` (claim) and `nLocktime=ctrTimeoutBlock`, `nSequence=0xFFFFFFFE` `BchChainClient.cpp:345/358` pattern shared. Refund uses same path. | **Full SPV. Most complete BTC path.** |
| LTC | `ltc_mode`, `ltc_spv_server_*`, `ltcWif` — `ChainClientConfig` analogous | Same Electrum stack — `LtcChainClient.h:14` | Same | Blocked `LtcChainClient.cpp:149` | `LtcChainClient.cpp:486-578`, `P2WSH 00 20` `LtcChainClient.cpp:548`, `sha256` fail-closed `LtcChainClient.cpp:550`, `verifyTxInclusion` `LtcChainClient.cpp:568`, `verifyPtlcLock` `LtcChainClient.cpp:386` (`ltc1p`) | Same local sign + `broadcastTx` `LtcChainClient.cpp:589` | **Full SPV, mirrors BTC.** |
| BCH | `bch_mode`, `bch_spv_server_*`, `bchSpvMinServers`, `bchSpvCheckpointHeight/Hash`, `bchWif` — `ChainClientConfig.cpp:180-190` | Electrum — `BchChainClient.h:17` `BchChainClient(std::shared_ptr<ISpvClient>)` | Same | Blocked `BchChainClient.cpp:34` | `BchChainClient.cpp:113-277`, `P2SH A9 14 ..87` `BchChainClient.cpp:237`, `hash160(redeem)` must match `chainState` fail-closed `BchChainClient.cpp:252-260` `"redeem script required"`. `SpvTxInclusion` `BchChainClient.cpp:263`, `getTransactionDetails` `BchChainClient.cpp:432` with `tipHeight` + `verifyTxInclusion` `BchChainClient.cpp:442`. | Local `WIF` `BchChainClient.cpp:285`, `signInput`, fee 1000 sat `BchChainClient.cpp:297`, `broadcastTx` `BchChainClient.cpp:317`, refund `BchChainClient.cpp:337` | **Strict SPV. Binding correct.** |
| KMD | `kmd_mode`, `kmd_spv_server_*`, `kmdWif` — `ChainClientConfig` analogous | Electrum — `KmdChainClient.h:42` | Same | Blocked `KmdChainClient.cpp:47` | `KmdChainClient.cpp:119-250`, `P2SH` `KmdChainClient.cpp:216`, `hash160` fail-closed `KmdChainClient.cpp:219`, `verifyTxInclusion` `KmdChainClient.cpp:240`, `getTransactionDetails` `KmdChainClient.cpp:405` | `WIF` `KmdChainClient.cpp:258`, `broadcastTx` | **Full SPV, mirrors BCH.** |
| DCR | `dcr_mode=spv`, `dcr_spv_server_*`, `dcrWif` — `ChainClientConfig` + `SwapDaemon.cpp:336-353` | **Neutrino** — `NeutrinoSpvClient.h:33`, `.cpp:21-845` via `SpvHeaderStore` `SwapDaemon.cpp:343` (`setMaxHeightDelta 2000`), `GcsFilterParams` | Single-server, no `syncHeaders` eclipse check — `NeutrinoSpvClient.cpp:319-408` uses `m_connections[0]` only `NeutrinoSpvClient.cpp:430,581` | Blocked but ctor **requires RPC** `DcrChainClient.h:28-30` (`spvClient+rpc`), `lock` `DcrChainClient.cpp:35` `fail(RPC not available)` — SPV is read-only. `SwapDaemon.cpp:349` wires `NeutrinoSpvClient + DcrRpcClient` | `DcrChainClient.cpp:192-327`, `P2SH A9 14` `DcrChainClient.cpp:289`, **weak**: `foundP2sh=true` on `value>=amount` `DcrChainClient.cpp:291` alone, hash check only `if(haveExpectedHash)` `DcrChainClient.cpp:305` — **no fail-closed**. Uses `NeutrinoSpvClient::verifyTxInclusion` `DcrChainClient.cpp:314` | **RPC-only spends** — `claim` `DcrChainClient.cpp:332` and `refund` `DcrChainClient.cpp:353` `fail` if `!m_rpc` — no `broadcastTx` path. SPV cannot claim/refund. | **Verify-only, hash binding bug, no spend.** `NeutrinoSpvClient::broadcastTx` stub `false` `NeutrinoSpvClient.cpp:836`. |

### 1.2 SPV primitives (shared)

- **ISpvClient** `Spv/ISpvClient.h:23-39`: `syncHeaders`, `getTipHeight`, `verifyTxInclusion(txid)->SpvTxInclusion{included, blockHeight, depth, merkleVerified}`, `findSpend(txid,vout)`, `getRawTx`, `broadcastTx`.
- **Header store** `SpvHeaderStore.h:25`, `.cpp:34-385`: 80B parse `SpvHeader.cpp:51`, PoW `meetsPoW` `SpvHeader.cpp:141` + `nBitsToTargetBE` `SpvHeader.cpp:107`, `prevHash` link `SpvHeaderStore.cpp:78-90`, checkpoint `anchor` `SpvHeaderStore.cpp:41` enforced `SpvHeaderStore.cpp:93-101`, cumulative work `work()=2^256/(target+1)` `SpvHeader.cpp:157` tracked `SpvHeaderStore.cpp:110`, best-tip `updateBestTip` picks max height then max work `SpvHeaderStore.cpp:332`, `isOnBestChain` walks prev `SpvHeaderStore.cpp:303`, prune `tip-2000` `SpvHeaderStore.cpp:363` (keeps checkpoint `SpvHeaderStore.cpp:372`).
- **Merkle** `SpvMerkle.h:38`, `.cpp:27-52`: `cur=rev(txid); for(bh){ b=rev(branch); cur=dsha256(pos&1?b+cur:cur+b); pos>>=1; }` — Electrum `pos` convention correct.
- **Electrum** `ElectrumSpvClient.cpp:371-803`: `verifyTxInclusion` `get_merkle` `ElectrumSpvClient.cpp:381`, `merkleRootAt` `ElectrumSpvClient.cpp:407`, `computeRootHexDisplay` compare; `crossCheckHeader` majority `n/2+1` `ElectrumSpvClient.cpp:208`; `crossCheckTxVerify` `ElectrumSpvClient.cpp:212` recomputes on peers `ElectrumSpvClient.cpp:253`; `getRawTx` validates 64-hex `ElectrumSpvClient.cpp:604`; `findSpend` derives `scripthash=rev(sha256(scriptPubKey))` `ElectrumSpvClient.cpp:588` then `scripthash.get_history` `ElectrumSpvClient.cpp:666`.
- **Electrum connection** `ElectrumConnection.cpp:65-271`: `MSG_NOSIGNAL` `ElectrumConnection.cpp:211`, `MAX_RESPONSE 1MB` `ElectrumConnection.cpp:219`, TLS off by default `ElectrumConnection.h:27`, `SSL_VERIFY_NONE` `ElectrumConnection.cpp:38` if enabled, newline-delim JSON `ElectrumConnection.cpp:238`.

### 1.3 Swap lifecycle / SPV states (xfgo source of truth)

- `SwapState` `SwapTypes.h:39-62`: active adaptor `ADAPTOR_KEYS_EXCHANGED(10)` -> `ADAPTOR_ESCROW_FUNDED(11)` -> `ADAPTOR_PRESIGS_READY(12)` -> `ADAPTOR_CTR_LOCKED(13)` -> then `ADAPTOR_WAITING_SPV(17)` / `ADAPTOR_SECRET_CONFIRMED_SPV(18)` (`SwapTypes.cpp:149-151`), `ADAPTOR_SECRET_REVEALED(14)`, `ADAPTOR_XFG_SPENT(15)`, `ADAPTOR_REFUNDED(16)`. AFK `AFK_OFFER_LOCKED(100)->AFK_OFFER_ACCEPTED(101)->AFK_CLAIMED(102)->AFK_REFUNDED(103)`.
- Transitions `SwapStateMachine.cpp:145-160`: `CTR_LOCKED->WAITING_SPV->SECRET_CONFIRMED_SPV->XFG_SPENT`.
- Required confirmations `SwapParams.requiredConfirmations=6` `SwapTypes.h:187`; enforced only in `handleWaitingSpv` `SwapDaemon.cpp:2173` via `getTransactionDetails(ctrLockTxId)` `SwapDaemon.cpp:2212`, `fatal->FAILED` `SwapDaemon.cpp:2215`, `!success->retry` `SwapDaemon.cpp:2222`, `confirmed && confirmations>=required -> SECRET_CONFIRMED_SPV` `SwapDaemon.cpp:2226`, else retry `SwapDaemon.cpp:2234`. `tickLoop` `SwapDaemon.cpp:2495-2503` dispatches `handleWaitingSpv` / `handleSecretConfirmedSpv` (`finalizeEscrowSpend` `SwapDaemon.cpp:1972`). `checkTimeouts` refunds SPV states with `escrowTxHash` `SwapDaemon.cpp:1118`; `refund()` `SwapDaemon.cpp:2667` refunds CTR HTLC `SwapDaemon.cpp:2974` + XFG `broadcastEscrowRefundDirect` `SwapDaemon.cpp:2982` when `height>=xfgTimeoutHeight` `SwapDaemon.cpp:2710`. Timelock safety `timelockOrderingOk` `SwapDaemon.cpp:768`, height via `getCurrentHeight` (`getTipHeight` or `getBlockCount`) fail-closed `SwapDaemon.cpp:761`.
- `ChainClientResult` `ChainClientResult.h:14-18`: `confirmed`, `spvVerified`, `blockHeight`, `confirmations` — populated in all SPV paths.
- Fee check absent: `verifyLockSpv` only `value>=amount` `BtcChainClient.cpp:817`.

### 1.4 What Flutter users see today

- **Orderbook/Trades (fuegod)** — `DexCubit.loadActiveSwaps` `dex_cubit.dart:441` -> `POST /getactiveswaps` -> `SwapStatusSdk` `swap_models.dart:107` (7 states open/matched/.../cancelled). No SPV fields. `dex_screen.dart:93-118` shows only `lastResult`/`error`. **BTC-family identical to others — no SPV distinction.**
- **Cross-chain (xfg-swapd)** — `DexCubit.loadSpvSwaps` `dex_cubit.dart:1097` -> `swap_daemon_client.dart:124` `list_swaps` -> `SwapInfo` `swap_daemon_client.dart:149-178` (`fromJson` `swap_daemon_client.dart:180-234` parses only `swapId, state, pair, xfgAmount, ctrAmount, peerEndpoint, createdAt, updatedAt, timeoutHeight, lockType*`). `peer_swap_screen.dart:50` splits `!isTerminal` vs terminal `swap_daemon_client.dart:285` (`ADAPTOR_XFG_SPENT`, `ADAPTOR_REFUNDED`, `FAILED`). `_activeSection` `peer_swap_screen.dart:275-368` renders `Text(swap.state)` `peer_swap_screen.dart:320` raw (e.g. `ADAPTOR_CTR_LOCKED`) + amount + short id, buttons Accept/Refund. `_historySection` `peer_swap_screen.dart:371-421` generic check vs replay icon `peer_swap_screen.dart:384`. **No confirmations counter, no blockHeight, no spvVerified, no stepper, no distinction between `ADAPTOR_CTR_LOCKED` vs `ADAPTOR_WAITING_SPV(17)` vs `ADAPTOR_SECRET_CONFIRMED_SPV(18)` — `grep ADAPTOR_WAITING` hits only `swap_daemon_client.dart:277-278` map, zero hits in `dex_cubit.dart`/`peer_swap_screen.dart`.**
- **Manual proof** — `DexCubit.verifyPayment` `dex_cubit.dart:1016` -> `/verify_payment` `wallet.rs:275` / `server.rs:633` -> `PaymentProofSdk` `swap_models.dart:386` (`confirmations:392`, `blockHeight:393`, `verified:399`) but **detached** — user pastes txHash, not bound to swap, not auto-polled.
- **Chain metadata** — `chain_info.dart:51-117` labels BTC/LTC/BCH/KMD/DCR as `connect: Electrum SPV` / Neutrino, `swapableChains` `chain_info.dart:227` includes all, but **display only**.
- **Event bus** — `daemon_event_bus.dart:19` declares `eventSpv='spv_status'` but `_pollSwapd` `daemon_event_bus.dart:238` emits only `eventSwap`+`eventHealth`; poll interval 5s documented not implemented; `health` `daemon_event_bus.dart:351` has no SPV confirmations fields. `grep spvVerified|requiredConfirmations|blockHeight` in `lib/` returns only `PaymentProofSdk` orphaned fields.
- **Reserve proof** — `ChainTypeSdk.isBtcFamily` `swap_models.dart:93` used only for proof branch `dex_cubit.dart:638` (`BitcoinReserveProof`), not for SPV UI.

**Verdict:** The daemon already tracks `commit -> land -> fail` with confirmations, but the UI collapses all of it into a single state string. Users cannot answer "Did the counterparty commit? How many confirmations? Is it safe to proceed? Did it fail due to reorg/timeout?"

---

## 2. Gaps and Risk Register

### 2.1 User-visible gaps (highest user impact)

| # | Gap | Evidence | Impact |
|---|-----|----------|--------|
| V1 | `SwapInfo` drops SPV fields | `swap_daemon_client.dart:180-234` missing `confirmations, requiredConfirmations, blockHeight, spvVerified, ctrLockTxId` parsing; daemon does send `ChainClientResult.confirmations` but client discards | Commit seen vs landing unknown |
| V2 | `ADAPTOR_WAITING_SPV` / `ADAPTOR_SECRET_CONFIRMED_SPV` undistinguished in UI | Map exists `swap_daemon_client.dart:277-278`, zero branching in `peer_swap_screen.dart` | User sees same label for 0/6 vs 6/6 |
| V3 | No live progress | `DaemonEventBus._pollSwapd` never emits `eventSpv`, `swap_daemon_client.dart:131` `swapStatus()` never called, only bulk `listSwaps` | Requires manual refresh to see confirmation growth |
| V4 | Commit vs land vs fail collapsed | `isTerminal` + generic icons `peer_swap_screen.dart:384`, no stepper `HEAT_SWAP_UI.md:57` | Cannot tell refund due to timeout vs SPV failure vs user cancel |
| V5 | SPV read-only failure mode hidden | Docs `AGENTS.md:46` + `BtcChainClient.cpp:103` block `lock` in SPV mode but Dart refunds show generic `Refund failed: $e` `dex_cubit.dart:1196` | Operator confusion when claim/refund needs RPC |
| V6 | `verify_payment` not swap-bound | `dex_cubit.dart:1016` manual paste | BTC-family automation absent |

### 2.2 SPV transport / verification gaps

| # | Gap | Evidence | Severity |
|---|-----|----------|----------|
| S1 | Default single-server trust | `bchSpvMinServers=1` `SwapDaemon.h:62`, `crossCheckHeader` short-circuit `ElectrumSpvClient.cpp:168`, `crossCheckTxVerify` passthrough `ElectrumSpvClient.cpp:214`, `getTipHeight` single never cross-checks `ElectrumSpvClient.cpp:289` | High |
| S2 | `syncHeaders` not eclipse-checked | Batch fetch from `m_conns[0]` only `ElectrumSpvClient.cpp:98`, never `crossCheckHeader` per batch; tip from `subscribe` on conn0 `ElectrumSpvClient.cpp:59` before cross-check | High |
| S3 | `getTipHeight` uses `maxTip` | `ElectrumSpvClient.cpp:344` `max(h)` attacker can push high tip; `merkleRootAt(maxTip)` `ElectrumSpvClient.cpp:354` fails if pruned -> DoS | Medium |
| S4 | No diff retarget / bits continuity / timestamp checks | Only `meetsPoW` `SpvHeaderStore.cpp:61/105`; `bits` can drift, `time` never validated `SpvHeader.cpp:62` | Medium |
| S5 | Checkpoint optional + stale | `checkpointHeight=0` default `SwapDaemon.h:64` -> none unless JSON provides; no staleness warning `SwapDaemon.cpp:369` | Medium |
| S6 | Restricted fork growth + reorg window | `addHeader` rejects parent not on best chain `SpvHeaderStore.cpp:86`; `updateBestTip` scans only max height `SpvHeaderStore.cpp:340`; prune `tip-2000` `SpvHeaderStore.cpp:363` (~14d BTC) then `merkleRootAt` false `ElectrumSpvClient.cpp:408` -> `verifyTxInclusion` fails | Medium |
| S7 | DCR hash not enforced | `DcrChainClient.cpp:291` `foundP2sh=true` on `value>=amount`, hash check only `if(haveExpectedHash)` `DcrChainClient.cpp:305` -> any P2SH passes without `chainState` | High |
| S8 | DCR spend requires RPC, verify-only SPV | `DcrChainClient.cpp:332/353` `fail` if `!m_rpc`, `NeutrinoSpvClient::broadcastTx` stub `false` `NeutrinoSpvClient.cpp:836`, Neutrino single-server `NeutrinoSpvClient.cpp:430` no eclipse mitigation | Medium |
| S9 | TLS off / verify none | `useTls=false` `ElectrumConnection.h:27`, `SSL_VERIFY_NONE` `ElectrumConnection.cpp:38`, plaintext `MSG_NOSIGNAL` `ElectrumConnection.cpp:211` | Medium |
| S10 | No fee check on lock | `value>=amount` only `BtcChainClient.cpp:817` | Low |
| S11 | Reorg race: `SECRET_CONFIRMED_SPV` -> `finalizeEscrowSpend` broadcasts XFG `SwapDaemon.cpp:1976/2012` without re-verify; depth gate only in `WAITING_SPV` `SwapDaemon.cpp:2226`; no re-verify before broadcast; `VERIFY->CLAIM` TOCTOU `BtcChainClient.cpp:702` `getRawTx` then `verifyTxInclusion` then later `claim` at separate tip | High |
| S12 | `generateSpvConfig` checkpoint hash placeholder | `main.cpp` `generateSpvConfig` prints `0000..a9b` placeholder — operator must replace; no validation that height/hash match network | Low |
| S13 | Neutrino no cross-check at all | `NeutrinoSpvClient.cpp:410` `getTipHeight` store only, `syncHeaders` single, no `crossCheckHeader` | Medium |
| S14 | No chain-appropriate dust/fee sanity | No `ctrAmount` dust limit vs chain min beyond `value>=amount` | Low |

---

## 3. Phased Plan — From Current State to User-Visible, Safe SPV

Design constraints respected: every line does its real job, no stubs, lexical ban enforced, YES.md gates, OKOC chain.

### Plan overview

```
Phase 0 — Wire SPV fields through the stack (commit->land signal)
Phase 1 — Surface commit/land/fail in Flutter with live progress
Phase 2 — Harden SPV transport (multi-server, checkpoint, TLS, sync cross-check)
Phase 3 — Reorg / TOCTOU / fee safety
Phase 4 — Verify with real-data gates
```

Each phase states: goal, repo:file edits, verification command, rollback.

---

### Phase 0 — Wire SPV fields through the stack

**Goal:** Daemon already knows `confirmations/tip/verify`; Flutter must receive it. No behavior change, just plumbing.

**Why first:** All UI work depends on this. Without wire, Phase 1 has nothing to render. Minimal blast radius — additive JSON fields.

**Edits:**

1. `xfgo/src/SwapDaemon/RpcServer.cpp` — `list_swaps` handler: for each `SwapParams` with `ctrLockTxId` non-empty, call `client->getTransactionDetails(ctrLockTxId, r)` and include in response:
   ```json
   {"swapId":"...","state":17,"stateName":"ADAPTOR_WAITING_SPV",
    "pair":"BTC","pairName":"BTC",
    "xfgAmount":1000000000,"ctrAmount":50000,
    "ctrLockTxId":"<txid>","chainState":"...","confirmations":3,
    "requiredConfirmations":6,"blockHeight":842110,"spvVerified":true,
    "commitSeen":true,"timedOut":false}
   ```
   Reuse `SwapDaemon.cpp:2162` `getTransactionDetails` pattern. On `!success` return `confirmations:0, spvVerified:false` with `error` string for UI to show retry.

2. `xfgo/src/SwapDaemon/RpcServer.cpp` — `swap_status` handler: extend single-swap detail to include same fields (fixes `swap_daemon_client.dart:131` dead path).

3. `fuego-flutter-wallet/lib/services/swap_daemon_client.dart` — `SwapInfo` (`:149`):
   - Add fields `final String? ctrLockTxId; final int confirmations; final int requiredConfirmations; final int blockHeight; final bool spvVerified; final String? spvError;`
   - `fromJson` (`:180`) parse `ctrLockTxId`, `confirmations`, `requiredConfirmations`, `blockHeight`, `spvVerified`, `commitSeen`, `timedOut`. Backwards-compatible: `j['confirmations'] ?? 0`. Keep `stateName` map (`:259`) — add `commitSeen` helper `bool get isCommitSeen => ctrLockTxId != null && ctrLockTxId!.isNotEmpty; bool get isLanded => spvVerified && confirmations >= requiredConfirmations;`
   - `isTerminal` unchanged; add `isFailedCommit => state.contains('FAILED') || state.contains('REFUNDED')` helpers for landing vs fail distinction.

4. `rust-fuego-wallet/fuego-sdk/fuego-sdk/src/chain/mod.rs` — no change needed for Flutter contract, but ensure `PaymentProof` not confused with `SwapInfo` (keep separate).

**Verification (must pass before merge):**

```bash
# C++ lint when link broken
clang++ -fsyntax-only -I src -I build_presig/src/CMakeFiles/Rpc.dir/flags.make src/SwapDaemon/RpcServer.cpp
# Flutter analyze zero errors
flutter analyze lib/services/swap_daemon_client.dart lib/models/swap_models.dart
# Runtime: start xfg-swapd with --swap-config btc_spv example, create a BTC swap, curl
curl -s http://127.0.0.1:18902 -d '{"method":"list_swaps","params":{}}' | jq '.result[0] | {state, confirmations, spvVerified, ctrLockTxId}'
# Expect numeric confirmations present after lock
```

**Rollback:** Revert `RpcServer.cpp` + `swap_daemon_client.dart`; fields were additive, old client ignores them.

**Time:** 1–2 days. **Confidence:** high. **Risk:** low — additive, behind `ctrLockTxId` guard.

---

### Phase 1 — Surface commit/land/fail in Flutter with live progress

**Goal:** Users see, without manual paste, when BTC-family counterparty has committed (lock broadcast / mempool seen), when it has landed (SPV confirmations met), and when it has failed.

**Edits:**

1. `fuego-flutter-wallet/lib/bloc/dex/dex_cubit.dart`
   - `loadSpvSwaps` already polls `list_swaps`; keep but ensure `emit` carries new SPV fields (no new RPC).
   - Add `pollingMs`: reuse `DaemonEventBus` 5s cadence — no new timer, just ensure `DexCubit` is notified via `eventSwap` (already wired `daemon_event_bus.dart:238`). Alternatively wire `eventSpv` properly if Phase 2 adds it.

2. `fuego-flutter-wallet/lib/screens/dex/peer_swap_screen.dart`
   - `_activeSection` (`:275`): replace `Text(swap.state)` `peer_swap_screen.dart:320` with branch:
     ```
     if (swap.state == ADAPTOR_CTR_LOCKED) -> "Commit seen — awaiting SPV (0/6)"
     if (swap.state == ADAPTOR_WAITING_SPV) -> "Lock seen — ${swap.confirmations}/${swap.requiredConfirmations} confirmations" + LinearProgressIndicator(value: confirmations/required)
     if (swap.state == ADAPTOR_SECRET_CONFIRMED_SPV) -> "Confirmed — claiming XFG…"
     if (swap.state == ADAPTOR_SECRET_REVEALED) -> "Secret revealed — spending escrow"
     else -> swap.state
     ```
     Show `ctrLockTxId` as tappable monospace (copy / explorer link via `chain_info.dart` explorer template; add if missing).
     Show `spvError` when `!spvVerified && error!=null` as amber warning, not terminal.
   - `_historySection` (`:371`): replace generic icons `peer_swap_screen.dart:384` with tri-state: `ADAPTOR_XFG_SPENT` green "Landed — XFG claimed", `ADAPTOR_REFUNDED/CTR_REFUNDED` amber "Failed — refunded (timeout/SPV)", `FAILED` red with `spvError`.
   - **Stepper widget** extracted to `lib/widgets/swap_progress_stepper.dart` (4 steps: Commit broadcast -> SPV seen -> Confirmations met -> XFG spent) driven by `swap.state` + `confirmations`.

3. `fuego-flutter-wallet/lib/services/daemon_event_bus.dart`
   - Fix `eventSpv` dead code (`:19`). In `_pollSwapd` (`:238`), after `eventSwap` emit, if any swap has `ctrLockTxId` non-empty, emit `eventSpv` with `{swapId, confirmations, requiredConfirmations, spvVerified}`. This enables widgets that listen only to SPV progress to avoid full list rebuild.

4. `fuego-flutter-wallet/lib/models/chain_info.dart`
   - Ensure BTC-family entries include explorer URL template (e.g. `https://mempool.space/tx/{txid}`) used by the tappable txid. Already has `connect: Electrum SPV` (`:51`), add `explorerTx` helper.

**UX copy (BTC-family aware):**

- Commit: "Counterparty committed {ctrAmount} {pair} — tx {shortId} seen in mempool. Waiting for chain confirmation."
- Landing: "Counterparty lock landed — {confirmations}/{required} confirmations, SPV verified. You can now claim."
- Failed: "Counterparty lock not confirmed within timeout — refund available." / "SPV verification failed: {reason} — will retry."

**Verification:**

```bash
flutter analyze lib/screens/dex/peer_swap_screen.dart lib/bloc/dex/dex_cubit.dart lib/services/daemon_event_bus.dart
flutter test test/dex_cubit_test.dart   # add unit tests for SwapInfo parsing with 0/3/6 conf
# Manual: run against regtest Electrum (or xfgo/tests BTC harness), observe 0->6 progress without refresh
```

**Rollback:** Revert screen/cubit/bus; daemon fields remain harmless.

**Time:** 3–5 days including widget tests. **Confidence:** high. **Risk:** medium — UI only, no chain logic.

---

### Phase 2 — Harden SPV transport

**Goal:** Close S1–S6, S9, S13 without breaking existing single-server users. Defaults stay single but become safe and observable.

**Edits (xfgo/src/SwapDaemon):**

1. **DCR fail-closed** — `Decred/DcrChainClient.cpp:305` (`DcrChainClient.h`): change
   ```cpp
   if (!haveExpectedHash) return fail("DCR verifyLock SPV: chainState redeem script required");
   ```
   and `if (hash != expected) return fail(...)` — mirror `BchChainClient.cpp:252-260`. Add test `Decred/tests/test_dcr_chain_client.cpp` matching `BchChainClient/tests`.

2. **Ship per-chain checkpoints** — `chains-staging/` or `src/SwapDaemon/Spv/checkpoints.h`: add generated `kBtcCheckpoints[] = {{800000, "0000..."}, {810000, "..."}}`, `kLtc...`, `kBch...`, `kKmd...`. `ChainClientConfig.cpp` — after JSON parse, if `checkpointHeight==0` load built-in nearest <= `tipHeight-6` and log `WARN "using built-in checkpoint at %u, age %u blocks"`. `SwapDaemon.cpp` log warning if built-in age > 2016 blocks (~2 weeks BTC). No hard fail — warn.

3. **Multi-server defaults + observability** — `ChainClientConfig.cpp:365` change `bchSpvMinServers`/`btcSpvMinServers` default from `1` to `2` for mainnet template generated by `--generate-spv-config` `main.cpp:generateSpvConfig`. Keep JSON `1` backward-compat but log `WARN "single Electrum server — SPV not cross-checked (eclipse risk) Set *_spv_server_1"` when `size==1` (remove silent trust `ElectrumSpvClient.cpp:168` silent return).

4. **syncHeaders cross-check** — `Spv/ElectrumSpvClient.cpp:98-152`: after each `BATCH` `addHeader` loop, call `crossCheckHeader(batchTipHeight, merkleRoot)` on a random 1 header per batch (or per 500) when `m_conns.size()>1`. On failure, log `ERROR` and return `false` to retry next tick — matches `handleWaitingSpv` retry pattern.

5. **getTipHeight median not max** — `ElectrumSpvClient.cpp:344`: replace `maxTip` with `medianTip` of heights that pass `crossCheckHeader`. Require `agreeCount >= required` for tip itself; otherwise return `false` (caller retries). Preserves eclipse resistance, removes high-tip injection.

6. **TLS opt-in** — `ElectrumConnection.h:27` add `useTls` plumbed from `ChainClientConfig` `bchSpvUseTls` / `btcSpvUseTls` (default false, doc `electroncash.org:50002` is TLS). When true, require `SSL_VERIFY_PEER` not `SSL_VERIFY_NONE` `ElectrumConnection.cpp:38`. Add `bch_spv_use_tls` JSON key (default false) — operator opts in. Document self-signed risk.

7. **Neutrino single-server acknowledgement** — `Spv/Neutrino/NeutrinoSpvClient.h:65` add comment/log `WARN "Neutrino SPV — single peer, no eclipse cross-check; DCR verify-only"`. No code fix beyond DCR hash gate; DCR remain verify-only until RPC spend path is productized (tracked separately).

**Verification:**

```bash
# C++ unit
cmake -DUSE_VENDORED_SECP256K1=OFF -DBUILD_TESTS=ON && make -j$(nproc) && ctest -R "spv|bch|ltd|dcr"
# Specific
./build/src/test_daemons/test_bch_chain_client --gtest_filter="*verifyLockSpv*"
./build/src/test_daemons/test_neutrino --gtest_filter="*verifyTxInclusion*"
# Network: run ElectrumSpvClient against 2 real servers, kill one, confirm still verifies; kill both -> fail closed
# Dart unchanged — no flutter analyze needed for this phase
```

**Rollback:** Each numbered edit is independent commit; revert any failing one without touching Phase 0/1.

**Time:** 5–8 days (DCR fix 0.5d, checkpoints 1d, cross-check+median 2d, TLS plumbing 1d, tests 2d). **Confidence:** medium — consensus-adjacent changes need testnet bake.

---

### Phase 3 — Reorg / TOCTOU / fee safety

**Goal:** Close S11, S10, S14 — the subtle safety gaps that matter once users trust the landing indicator.

**Edits:**

1. **Re-verify before XFG spend** — `SwapDaemon.cpp:1972` `handleSecretConfirmedSpv` / `finalizeEscrowSpend`: before `broadcastEscrowClaimDirect` `SwapDaemon.cpp:2012`, call `client->getTransactionDetails(ctrLockTxId, r)` again and require `r.confirmed && r.confirmations >= required` and `r.spvVerified`. If not, transition back to `ADAPTOR_WAITING_SPV` and log `WARN "reorg detected — CTR lock lost confirmations, holding XFG"`. Mirrors `handleWaitingSpv:2212` logic.

2. **Detect spend reorg** — `SwapDaemon.cpp:2162` `handleWaitingSpv` after `tryExtractClaimedSecret`, also call `m_spvClient->findSpend(ctrLockTxId, 0)` to confirm spend not reorged away before advancing; if `findSpend` not found but previously found, treat as reorg and hold.

3. **Fee / dust sanity** — `BtcChainClient.cpp:816`, `LtcChainClient.cpp:548`, `BchChainClient.cpp:237`, `KmdChainClient.cpp:216`: after `value>=amount`, add `if (value > ctrAmount + 100000) log WARN "lock overpays by %lu sat"` and `if (feeRate < dustLimit) log` — not fail-closed (avoid rejecting valid high-fee user tx), but surface `spvError` warning to UI via Phase 0 error string.

4. **Prune awareness** — `SpvHeaderStore.cpp:363` already keeps checkpoint; `ElectrumSpvClient.cpp:408` `merkleRootAt` false -> `verifyTxInclusion` fail. Surface as `spvError="header pruned — resync from checkpoint"` so UI shows amber not red, and `syncHeaders` auto-recovers.

**Verification:**

```bash
# Simulate reorg: regtest — mine lock at height H (6 conf), mine 7-block reorg dropping it, assert daemon holds XFG and re-enters WAITING_SPV
ctest -R "reorg"
# TOCTOU: unit mock ISpvClient that flips included->false between verify and claim, assert no broadcast
flutter analyze   # UI consumes new spvError strings
```

**Rollback:** Revert `SwapDaemon.cpp` re-verify gate; previous behavior resumes (less safe but functional).

**Time:** 3–4 days. **Confidence:** medium. **Risk:** medium — touches escrow-spend path; needs regtest coverage.

---

### Phase 4 — Verify with real-data gates (YES.md Rule 3)

Every phase's gate is a real run, not "looks right":

| Gate | Command | Pass |
|------|---------|------|
| C++ syntax | `clang++ -fsyntax-only -I src src/SwapDaemon/RpcServer.cpp src/SwapDaemon/Bitcoin/BtcChainClient.cpp` | zero errors |
| C++ tests | `cmake ... && ctest -R "spv\|Bch\|Ltc\|Kmd\|Dcr"` | all pass |
| Flutter | `flutter analyze lib/` | 0 errors |
| Dart unit | `flutter test test/swap_daemon_client_test.dart` (new) | `fromJson` 0/3/6 conf parsed |
| Integration | `python -m pytest tests/test_swap_spv.py -k btc` (xfgo) | lock->WAITING_SPV->SECRET_CONFIRMED_SPV->XFG_SPENT |
| Eclipse | run with 3 Electrum servers, kill 2, verify still cross-checks; kill all 3 -> fail closed | confirmed |
| Reorg | regtest reorg 6->0 | holds XFG, re-enters WAITING_SPV |

Blast radius per phase: Phase 0/1 UI-only; Phase 2 header store + Electrum; Phase 3 daemon state machine. Each phase ships behind existing flags — no flag day.

---

## 4. What Operators and Users Get After This Plan

- **Before:** User initiates BTC swap, sees `ADAPTOR_CTR_LOCKED` forever, no clue if counterparty tx exists, manual paste to `verify_payment`, refund reason opaque.
- **After Phase 0+1:** Same flow shows `Commit seen — tx abc… in mempool`, then `Lock seen — 3/6 confirmations (SPV verified)` with progress bar, then `Landed — 6/6 confirmed — claiming XFG`, then `Completed` or `Failed — SPV: {reason}` with explorer link. Live updates every 5s via `eventSpv`.
- **After Phase 2+3:** Defense against single-server eclipse, stale checkpoint, header-prune loss, DCR hash bypass, and reorg double-spend of the landing signal. Operators get warnings in logs and can opt into TLS + 2-server cross-check.

---

## 5. Explicit Non-Goals and Harsh Truths

- DCR remain verify-only until full-node RPC is connected — Neutrino `broadcastTx` is stubbed `false` `NeutrinoSpvClient.cpp:836`. Users cannot claim/refund DCR from pure SPV; the UI must state this rather than pretend.
- BTC/LTC/BCH/KMD lock is still not funded from SPV — `lock()` `BtcChainClient.cpp:103` intentional. SPV peer is a verifier + spender, not a funder. This matches protocol (Alice locks CTR, Bob funds XFG) but operators expecting pure light-client funding will be disappointed.
- Header PoW alone without retarget checks is not full consensus — Phase 2 adds cross-check but not full `bits` continuity; a long low-diff forgery near a stale checkpoint could still waste time until work catches up. Mitigate with fresh checkpoints and multi-server majority, not by claiming SPV is full-node security.
- This plan does not add new chains, does not change `SWAP_FEE` or consensus, and does not make `fuego_walletd` a wallet — it stays a proxy `rust-fuego-wallet/docs/TRANSACTION_BUILDER_PLAN.md`.

---

## 6. Rollback Summary

| Phase | Revert cost |
|-------|-------------|
| 0 | `git revert` 2 files, no data migration |
| 1 | `git revert` 3 Dart files |
| 2 | per-edit reverts, header store on disk prunes auto; checkpoint file revert safe |
| 3 | `git revert` daemon re-verify gate, swaps resume prior less-safe landing |

---

## 7. Open Questions for Operator Decision

1. `btc_spv_use_tls` default — keep `false` for compat or flip to `true` once public servers document certs?
2. `minServers=2` default — enforce cross-check by default or warn only to avoid breaking single-server testnets?
3. Checkpoint update cadence — bake into release or fetch via `https://fuego.foundation/checkpoints.json` at startup?

---

*Evidence base: `xfgo/src/SwapDaemon/Spv/*`, `Bitcoin/*`, `BitcoinCash/*`, `Litecoin/*`, `Komodo/*`, `Decred/*`, `SwapDaemon.cpp:2162-2237`, `SwapTypes.h:187`, `ChainClientResult.h:14`, `ChainClientConfig.cpp:180-372`, `fuego-flutter-wallet/lib/services/swap_daemon_client.dart:149-298`, `lib/screens/dex/peer_swap_screen.dart:50-421`, `lib/bloc/dex/dex_cubit.dart:441-1200`, `lib/services/daemon_event_bus.dart:19-390`, `lib/models/swap_models.dart:107-452`.*
