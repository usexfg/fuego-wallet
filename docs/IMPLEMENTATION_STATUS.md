# Implementation Status — Extravagant Swap Theatre (Acts 0-4)

Date: 2026-08-26
Branch: pending (no commit yet — see git status)
Governance: OKOC + YES.md, parallel agents, evidence-first

## What Shipped

### Flutter (fuego-flutter-wallet)

**Act 0 — Wire:**
- `lib/services/swap_daemon_client.dart:1-339` extended `SwapInfo` with `ctrLockTxId, confirmations, requiredConfirmations, blockHeight, spvVerified, confirmed, spvError, currentHeight` plus helpers `displayState, confirmationProgress, shortTxid, explorerUrl, isWaitingSpv, isLanded` (`swap_daemon_client.dart:187-319`). `fromJson` now parses live SPV block (`swap_daemon_client.dart:236-280`).
- `lib/models/chain_info.dart:197-237` already had `decimals, explorerTx, explorerTxUrl, amountToDecimal` (verified HEAD) — correct XFG 7, BTC 8, ETH 18, SOL 9.

**Act 1 — Timeline theatre:**
- `lib/widgets/swap/confirmation_cluster.dart:1-273` — orb row, pulse, explorer, progress bar
- `lib/widgets/swap/swap_timeline_stepper.dart:1-423` — 7-step adaptor + 4-step AFK, AnimatedContainer 400ms, LayoutBuilder h/v
- `lib/widgets/swap/swap_card.dart:1-379` — gallery card, badges PTLC 0xFF2E7D32/BRIDGE 0xFFEF6C00, correct decimals, mini bar
- `lib/screens/dex/peer_swap_screen.dart:1-1035` filter bar All/Active/Landed/History + chain Wrap, detail sheet timeline+cluster

**Act 2 — Inspector / timelock / amount:**
- `lib/widgets/swap/contract_inspector_sheet.dart:1-375` — showModalBottomSheet `0.85*h`, handle bar, ptlc desc, copy+explorer, DLEQ tick
- `lib/widgets/swap/timelock_countdown.dart:1-172` — hourglass, urgency colors <10 error <50 warning, LinearProgressIndicator, gap text
- `lib/widgets/swap/swap_amount_row.dart:1-277` — correct decimals, fee 69/11/20 sheet, network placeholder
- `lib/screens/dex/peer_swap_screen.dart:585` wired Amount+Timelock+Inspect in sheet

**Act 3 — Failure dignity / receipt / live bus:**
- `lib/widgets/swap/failure_card.dart:1-294` — FailureCause enum, gated Refund enabled `currentHeight>=timeoutHeight`
- `lib/widgets/swap/swap_receipt.dart:1-272` — Map 16 fields, Copy JSON + fallback Share
- `lib/services/daemon_event_bus.dart:1-686` — `_pollAndEmitSpv` now polls `list_swaps` via `DaemonEventBus` and emits `eventSpv='spv_status'` with `{swapId, confirmations, required, spvVerified, blockHeight, explorerUrl}`; `lib/services/swap_notification_service.dart:1-56` inits bus->SnackBar "Swap {shortId} landed — 6/6"

**Act 4 — Polish:**
- `lib/widgets/swap/success_confetti.dart:1-56` — OverlayEntry 6 dots TweenAnimationBuilder, no lottie dep
- `lib/services/swap_notification_service.dart:1-56` + `peer_swap_screen.dart:33` wiring via `didChangeDependencies` + `HapticFeedback.mediumImpact` on `ADAPTOR_XFG_SPENT`/`AFK_CLAIMED` (peer_swap_screen.dart:653) + `selectionClick` on chips/copy/explorer

All use `lib/utils/theme.dart:7` `primaryColor 0xFFD84315, successColor, warningColor, errorColor, cardColor 0xFF252B33, surfaceColor 0xFF1A1F26, backgroundColor 0xFF0A0E14` exactly.

### xfgo (fuego-suite, /Users/aejt/xfgo)

- `src/SwapDaemon/RpcServer.cpp:403-505` — `handleListSwaps`/`handleSwapStatus` now call `m_daemon.getChainClient(pair)->getTransactionDetails` + `getCurrentHeight` to emit SPV block; `src/SwapDaemon/SwapDaemon.h:421` added `getChainClient` accessor
- `src/SwapDaemon/Decred/DcrChainClient.cpp:305` — DCR fail-closed: `if (!haveExpectedHash) fail("chainState redeem script required")` mirrors BCH/KMD strict
- `src/SwapDaemon/Spv/ElectrumSpvClient.cpp:147-156` — syncHeaders now cross-checks batchTip `merkleRootDisplay` via `crossCheckHeader` when `m_conns.size()>1`
- `src/SwapDaemon/Spv/ElectrumSpvClient.cpp:325-364` — `getTipHeight` now median of tips (sorted `tips[tips.size()/2]`) not `maxTip`, with `crossCheckHeader(medianTip)` — resists high-tip injection
- `src/SwapDaemon/SwapDaemon.cpp:2008-2025` — `finalizeEscrowSpend` reorg/TOCTOU guard: when `logContext=="SPV confirmed"` and `ctrLockTxId` non-empty, re-verify `getTransactionDetails` still `confirmed && confirmations>=req && spvVerified` else `transition WAITING_SPV` and hold XFG

## Verification

- `flutter analyze lib/widgets/swap/` → No issues found! (0 errors, 0 warnings on theatre)
- `flutter analyze` full → 759 infos/warnings (pre-existing withOpacity etc), 0 new errors
- `flutter test` → 40 passed, 2 live daemon failures (WouldBlock sled, host lookup) — pre-existing, unrelated to theatre
- C++ syntax: `DcrChainClient.cpp`, `RpcServer.cpp`, `ElectrumSpvClient.cpp`, `SwapDaemon.cpp` edits additive, use existing `Common::JsonValue::Integer` + `IChainClient` API, no new includes

## Git State

- Modified: `lib/screens/dex/peer_swap_screen.dart:1`, `lib/services/daemon_event_bus.dart:1`, `lib/services/swap_daemon_client.dart:1` (flutter); `src/SwapDaemon/{RpcServer.cpp,Decred/DcrChainClient.cpp,Spv/ElectrumSpvClient.cpp,SwapDaemon.cpp,SwapDaemon.h}` + `graphify-out/*` (xfgo)
- Untracked new: `lib/widgets/swap/*:9` + `lib/services/swap_notification_service.dart:1` + `docs/{BTC_SPV_REVIEW_AND_PLAN.md,ATOMIC_SWAP_UX_EXCELLENCE_PLAN.md,IMPLEMENTATION_STATUS.md}`
- Backups removed, no commit yet — per OKOC do not push without permission. Run `git add lib/widgets/swap lib/services/swap_notification_service.dart lib/screens/dex/peer_swap_screen.dart lib/services/daemon_event_bus.dart lib/services/swap_daemon_client.dart docs/` then commit.

## Next

- Manual regtest: initiate BTC swap → observe `0/6 Seen in mempool` → `3/6` orbs fill live via eventSpv 5s → `6/6 Confirmed — claiming` → confetti + Haptic on `XFG_SPENT`; kill peer before 13 → `Refunded — timeout` FailureCard with `Refundable in N blocks` countdown.
- xfgo build gate: `cmake -DBUILD_TESTS=ON && ctest -R "spv|Bch|Ltc|Dcr"` plus regtest reorg `6->0` hold test (guard in finalizeEscrowSpend).
- Remaining hardening (checkpoint freshness warning, TLS opt-in) documented in `BTC_SPV_REVIEW_AND_PLAN.md:Phase2` — not yet wired, requires `ChainClientConfig` `bchSpvUseTls` etc.
