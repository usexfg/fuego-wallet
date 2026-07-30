import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:http/http.dart' as http;
import '../../models/swap_models.dart';
import '../../services/swap_daemon_client.dart';
import '../../services/web3_multi_chain_service.dart';

export '../../models/swap_models.dart' show SwapPairSdk, ChainTypeSdk;

enum OrderType { market, limit }

class DexState {
  final bool isLoading;
  final String? error;
  final SwapPairSdk selectedPair;
  final ChainTypeSdk selectedChain;
  final List<SwapOfferSdk> offers;
  final List<SwapTradeSdk> recentTrades;
  final SwapPriceSdk? price;
  final OrderBookStateSdk? orderbook;
  final List<SwapStatusSdk> activeSwaps;
  final PaymentProofSdk? lastProof;
  final String? lastResult;
  final bool isConnected;

  // SPV swap state (xfg-swapd)
  final bool isSwapDaemonConnected;
  final List<SwapInfo> spvSwaps;
  final bool isSwapInitiating;

  // Web3 / EVM / Solana state
  final double evmBalance;
  final double solBalance;
  final bool isBalanceLoading;
  final String? htlcTxHash;
  final String selectedSpvChain;

  const DexState({
    this.isLoading = false,
    this.error,
    this.selectedPair = SwapPairSdk.eth,
    this.selectedChain = ChainTypeSdk.ethereum,
    this.offers = const [],
    this.recentTrades = const [],
    this.price,
    this.orderbook,
    this.activeSwaps = const [],
    this.lastProof,
    this.lastResult,
    this.isConnected = false,
    this.isSwapDaemonConnected = false,
    this.spvSwaps = const [],
    this.isSwapInitiating = false,
    this.evmBalance = 0.0,
    this.solBalance = 0.0,
    this.isBalanceLoading = false,
    this.htlcTxHash,
    this.selectedSpvChain = 'BTC',
  });

  DexState copyWith({
    bool? isLoading,
    String? error,
    SwapPairSdk? selectedPair,
    ChainTypeSdk? selectedChain,
    List<SwapOfferSdk>? offers,
    List<SwapTradeSdk>? recentTrades,
    SwapPriceSdk? price,
    OrderBookStateSdk? orderbook,
    List<SwapStatusSdk>? activeSwaps,
    PaymentProofSdk? lastProof,
    String? lastResult,
    bool? isConnected,
    bool? isSwapDaemonConnected,
    List<SwapInfo>? spvSwaps,
    bool? isSwapInitiating,
    double? evmBalance,
    double? solBalance,
    bool? isBalanceLoading,
    String? htlcTxHash,
    String? selectedSpvChain,
  }) =>
      DexState(
        isLoading: isLoading ?? this.isLoading,
        error: error,
        selectedPair: selectedPair ?? this.selectedPair,
        selectedChain: selectedChain ?? this.selectedChain,
        offers: offers ?? this.offers,
        recentTrades: recentTrades ?? this.recentTrades,
        price: price ?? this.price,
        orderbook: orderbook ?? this.orderbook,
        activeSwaps: activeSwaps ?? this.activeSwaps,
        lastProof: lastProof ?? this.lastProof,
        lastResult: lastResult,
        isConnected: isConnected ?? this.isConnected,
        isSwapDaemonConnected: isSwapDaemonConnected ?? this.isSwapDaemonConnected,
        spvSwaps: spvSwaps ?? this.spvSwaps,
        isSwapInitiating: isSwapInitiating ?? this.isSwapInitiating,
        evmBalance: evmBalance ?? this.evmBalance,
        solBalance: solBalance ?? this.solBalance,
        isBalanceLoading: isBalanceLoading ?? this.isBalanceLoading,
        htlcTxHash: htlcTxHash ?? this.htlcTxHash,
        selectedSpvChain: selectedSpvChain ?? this.selectedSpvChain,
      );
}

class DexCubit extends Cubit<DexState> {
  final http.Client _http;
  String _baseUrl = '';
  SwapDaemonClient? _swapClient;
  Web3MultiChainService? _web3;
  String? _userAddress;

  DexCubit() : _http = http.Client(), super(const DexState());

  void configure(String host, {int port = 18098}) {
    _baseUrl = 'http://$host:$port';
  }

  void configureSwapDaemon({String host = '127.0.0.1', int port = 18902}) {
    _swapClient = SwapDaemonClient(host: host, port: port);
  }

  /// Initialize Web3 service for EVM/Solana chains.
  void configureWeb3({
    String ethRpcUrl = '',
    String solRpcUrl = '',
    String? userAddress,
  }) {
    _web3 = Web3MultiChainService(
      ethRpcUrl: ethRpcUrl,
      solRpcUrl: solRpcUrl,
    );
    if (userAddress != null) _userAddress = userAddress;
  }

  /// Reconfigure Web3 for a specific EVM chain (changes RPC endpoint).
  void switchEvmChain(String chain) {
    if (_web3 == null) return;
    switch (chain.toLowerCase()) {
      case 'arb':
        _web3!.setEthRpc(Web3MultiChainService.defaultArbRpc);
        break;
      case 'base':
        _web3!.setEthRpc(Web3MultiChainService.defaultBaseRpc);
        break;
      case 'bsc':
        _web3!.setEthRpc(Web3MultiChainService.defaultBscRpc);
        break;
      case 'eth':
      default:
        _web3!.setEthRpc(Web3MultiChainService.defaultEthRpc);
        break;
    }
  }

  Future<void> init({String host = '127.0.0.1', int port = 18098}) async {
    configure(host, port: port);
    configureSwapDaemon();
    configureWeb3();
    await _checkConnection();
    await _checkSwapDaemon();
  }

  Future<void> _checkConnection() async {
    if (_baseUrl.isEmpty) return;
    try {
      final resp = await _http
          .get(Uri.parse('$_baseUrl/getinfo'))
          .timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        emit(state.copyWith(isConnected: true, error: null));
        await loadOffers();
        await loadPrice();
        await loadOrderbook();
      }
    } catch (e) {
      emit(state.copyWith(error: 'Cannot connect to fuegod: $e'));
    }
  }

  Future<Map<String, dynamic>> _get(String path,
      {Map<String, String>? query}) async {
    final uri = _rest(path, query: query);
    final resp =
        await _http.get(uri).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(
      String path, Map<String, dynamic> body) async {
    final resp = await _http
        .post(_rest(path),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Uri _rest(String path, {Map<String, String>? query}) =>
      Uri(scheme: 'http', host: Uri.parse(_baseUrl).host, port: Uri.parse(_baseUrl).port, path: path, queryParameters: query);

  // ── Pair & Chain Selection ──────────────────────────────────────

  void selectPair(SwapPairSdk pair) {
    final chain = _chainForPair(pair);
    emit(state.copyWith(
        selectedPair: pair,
        selectedChain: chain,
        offers: [],
        recentTrades: [],
        isLoading: true));
    loadOffers();
    loadPrice();
    loadTrades();
  }

  void selectChain(ChainTypeSdk chain) {
    emit(state.copyWith(selectedChain: chain));
  }

  ChainTypeSdk _chainForPair(SwapPairSdk pair) {
    switch (pair) {
      case SwapPairSdk.sol:
        return ChainTypeSdk.solana;
      case SwapPairSdk.eth:
        return ChainTypeSdk.ethereum;
      case SwapPairSdk.xmr:
        return ChainTypeSdk.monero;
      case SwapPairSdk.bch:
        return ChainTypeSdk.bitcoinCash;
      case SwapPairSdk.arb:
        return ChainTypeSdk.arbitrum;
      case SwapPairSdk.base:
        return ChainTypeSdk.base;
    }
  }

  // ── Orderbook ───────────────────────────────────────────────────

  Future<void> loadOffers() async {
    if (_baseUrl.isEmpty) return;
    try {
      final r = await _get('/getswapoffers', query: {
        'pair': state.selectedPair.id.toString()
      });
      final offersList = (r['offers'] as List<dynamic>? ?? [])
          .map((o) => SwapOfferSdk.fromJson(o as Map<String, dynamic>))
          .toList();
      emit(state.copyWith(offers: offersList, error: null));
    } catch (e) {
      debugPrint('DexCubit: loadOffers failed: $e');
    }
  }

  Future<void> loadPrice() async {
    if (_baseUrl.isEmpty) return;
    try {
      final r = await _get('/getswapprice', query: {
        'pair': state.selectedPair.id.toString()
      });
      emit(state.copyWith(price: SwapPriceSdk.fromJson(r)));
    } catch (e) {
      debugPrint('DexCubit: loadPrice failed: $e');
    }
  }

  Future<void> loadTrades() async {
    if (_baseUrl.isEmpty) return;
    try {
      final r = await _get('/getswaptrades', query: {
        'pair': state.selectedPair.id.toString(),
        'limit': '50',
      });
      final trades = (r['trades'] as List<dynamic>? ?? [])
          .map((t) => SwapTradeSdk.fromJson(t as Map<String, dynamic>))
          .toList();
      emit(state.copyWith(recentTrades: trades));
    } catch (e) {
      debugPrint('DexCubit: loadTrades failed: $e');
    }
  }

  Future<void> loadOrderbook() async {
    if (_baseUrl.isEmpty) return;
    try {
      final r = await _get('/get_orderbook_state', query: {'depth': '20'});
      emit(state.copyWith(orderbook: OrderBookStateSdk.fromJson(r)));
    } catch (e) {
      debugPrint('DexCubit: loadOrderbook failed: $e');
    }
  }

  // ── Active Swaps ────────────────────────────────────────────────

  Future<void> loadActiveSwaps() async {
    if (_baseUrl.isEmpty) return;
    try {
      final r = await _post('/getactiveswaps', {});
      final swaps = (r['swaps'] as List<dynamic>? ?? [])
          .map((s) => SwapStatusSdk.fromJson(s as Map<String, dynamic>))
          .toList();
      emit(state.copyWith(activeSwaps: swaps));
    } catch (e) {
      debugPrint('DexCubit: loadActiveSwaps failed: $e');
    }
  }

  // ── Swap Operations ─────────────────────────────────────────────

  Future<void> submitOffer({
    required int xfgAmount,
    required int rateNum,
    required String makerPubKey,
    required String signature,
    int ttlBlocks = 1440,
  }) async {
    emit(state.copyWith(isLoading: true, lastResult: null, error: null));
    try {
      final r = await _post('/submitswap', {
        'offerId': DateTime.now().millisecondsSinceEpoch.toRadixString(16),
        'xfgAmount': xfgAmount,
        'rateNum': rateNum,
        'pair': state.selectedPair.id,
        'makerPubKey': makerPubKey,
        'signature': signature,
        'ttlBlocks': ttlBlocks,
      });
      final status = r['status'] ?? 'error';
      emit(state.copyWith(
          isLoading: false, lastResult: 'Offer submitted: $status'));
      await loadOffers();
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Submit failed: $e'));
    }
  }

  Future<void> cancelOffer({
    required String offerId,
    required String makerPubKey,
    required String signature,
  }) async {
    emit(state.copyWith(isLoading: true, lastResult: null, error: null));
    try {
      final r = await _post('/cancelswap', {
        'offerId': offerId,
        'makerPubKey': makerPubKey,
        'signature': signature,
      });
      final status = r['status'] ?? 'error';
      emit(state.copyWith(
          isLoading: false, lastResult: 'Offer cancelled: $status'));
      await loadOffers();
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Cancel failed: $e'));
    }
  }

  Future<void> requestSwap({
    required String offerId,
    required int amount,
    required String takerPubKey,
    required String proofOfFunds,
  }) async {
    emit(state.copyWith(isLoading: true, lastResult: null, error: null));
    try {
      final r = await _post('/requestswap', {
        'offerId': offerId,
        'amount': amount,
        'takerPubKey': takerPubKey,
        'proofOfFunds': proofOfFunds,
      });
      final status = r['status'] ?? 'error';
      emit(state.copyWith(
          isLoading: false, lastResult: 'Swap requested: $status'));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Swap failed: $e'));
    }
  }

  // ── SPV Verification ────────────────────────────────────────────

  Future<void> verifyPayment({
    required String txHash,
    required String fromAddress,
    required String toAddress,
    required int amount,
    int minConfirmations = 6,
  }) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final r = await _post('/verify_payment', {
        'chain': state.selectedChain.id,
        'tx_hash': txHash,
        'from_address': fromAddress,
        'to_address': toAddress,
        'amount': amount,
        'min_confirmations': minConfirmations,
      });
      final proof = PaymentProofSdk.fromJson(r);
      emit(state.copyWith(
        isLoading: false,
        lastProof: proof,
        lastResult: proof.verified
            ? 'Payment verified: ${proof.confirmations} confirmations'
            : 'Payment NOT verified',
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Verification failed: $e'));
    }
  }

  // ── HTLC ────────────────────────────────────────────────────────

  Future<HtlcHashLock?> createHtlcHashLock() async {
    try {
      final r = await _post('/htlc_create_hash_lock', {});
      return HtlcHashLock.fromJson(r);
    } catch (e) {
      emit(state.copyWith(error: 'HTLC hash lock failed: $e'));
      return null;
    }
  }

  Future<HtlcScript?> buildHtlcScript({
    required String hashLock,
    required String recipientPubkey,
    required String senderPubkey,
    required int timelock,
  }) async {
    try {
      final r = await _post('/htlc_build_script', {
        'hash_lock': hashLock,
        'recipient_pubkey': recipientPubkey,
        'sender_pubkey': senderPubkey,
        'timelock': timelock,
      });
      return HtlcScript.fromJson(r);
    } catch (e) {
      emit(state.copyWith(error: 'HTLC script build failed: $e'));
      return null;
    }
  }

  // ── Refresh ─────────────────────────────────────────────────────

  Future<void> refresh() async {
    await loadOffers();
    await loadPrice();
    await loadTrades();
    await loadOrderbook();
    await loadActiveSwaps();
    if (_swapClient != null) {
      await loadSpvSwaps();
    }
  }

  // ── SPV Swap Daemon (xfg-swapd) ──────────────────────────────────

  Future<void> _checkSwapDaemon() async {
    if (_swapClient == null) return;
    try {
      final available = await _swapClient!.isAvailable();
      emit(state.copyWith(isSwapDaemonConnected: available));
      if (available) {
        await loadSpvSwaps();
      }
    } catch (e) {
      emit(state.copyWith(isSwapDaemonConnected: false));
    }
  }

  Future<void> loadSpvSwaps() async {
    if (_swapClient == null) return;
    try {
      final swaps = await _swapClient!.listSwaps();
      emit(state.copyWith(spvSwaps: swaps, error: null));
    } catch (e) {
      debugPrint('DexCubit: loadSpvSwaps failed: $e');
    }
  }

  Future<void> initiateSpvSwap({
    required String pair,
    required int xfgAmount,
    required int ctrAmount,
    required String peer,
  }) async {
    if (_swapClient == null) {
      emit(state.copyWith(error: 'Swap daemon not connected'));
      return;
    }
    emit(state.copyWith(isSwapInitiating: true, error: null, lastResult: null));
    try {
      final swapId = await _swapClient!.initiateSwap(
        pair: pair,
        xfgAmount: xfgAmount,
        ctrAmount: ctrAmount,
        peer: peer,
      );
      emit(state.copyWith(
        isSwapInitiating: false,
        lastResult: 'Swap initiated: $swapId',
      ));
      await loadSpvSwaps();
    } catch (e) {
      emit(state.copyWith(
        isSwapInitiating: false,
        error: 'Failed to initiate swap: $e',
      ));
    }
  }

  Future<void> refundSpvSwap(String swapId) async {
    if (_swapClient == null) return;
    emit(state.copyWith(isLoading: true, error: null));
    try {
      await _swapClient!.refund(swapId);
      emit(state.copyWith(isLoading: false, lastResult: 'Refunded: $swapId'));
      await loadSpvSwaps();
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Refund failed: $e'));
    }
  }

  Future<void> checkSpvTimeouts() async {
    if (_swapClient == null) return;
    try {
      final result = await _swapClient!.checkTimeouts();
      if (result.refunded.isNotEmpty) {
        emit(state.copyWith(
          lastResult: 'Refunded ${result.refunded.length} timed-out swap(s)',
        ));
      }
      await loadSpvSwaps();
    } catch (e) {
      debugPrint('DexCubit: checkSpvTimeouts failed: $e');
    }
  }

  // ── Web3 / EVM / Solana Operations ──────────────────────────────

  /// Load balance for the current chain.
  Future<void> loadBalance({String? address}) async {
    final addr = address ?? _userAddress;
    if (addr == null || addr.isEmpty || _web3 == null) return;

    emit(state.copyWith(isBalanceLoading: true));
    try {
      final chain = state.selectedSpvChain.toLowerCase();
      final bal = await _web3!.getBalance(addr, chain);
      if (chain == 'sol') {
        emit(state.copyWith(solBalance: bal, isBalanceLoading: false));
      } else {
        emit(state.copyWith(evmBalance: bal, isBalanceLoading: false));
      }
    } catch (e) {
      emit(state.copyWith(isBalanceLoading: false, error: 'Balance fetch failed: $e'));
    }
  }

  /// Lock funds in an EVM HTLC (user initiates one side of the swap).
  Future<void> evmLockHtlc({
    required String privateKey,
    required String htlcAddress,
    required String hashlock,
    required int timelock,
    required double amount,
    String chain = 'eth',
  }) async {
    if (_web3 == null) {
      emit(state.copyWith(error: 'Web3 not configured'));
      return;
    }
    emit(state.copyWith(isLoading: true, error: null, lastResult: null));
    try {
      switchEvmChain(chain);
      final txHash = await _web3!.lockHtlc(
        privateKey: privateKey,
        htlcAddress: htlcAddress,
        hashlock: hashlock,
        timelock: timelock,
        amount: amount,
        chain: chain,
      );
      emit(state.copyWith(
        isLoading: false,
        htlcTxHash: txHash,
        lastResult: 'HTLC locked: $txHash',
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'HTLC lock failed: $e'));
    }
  }

  /// Claim funds from an EVM HTLC (reveal preimage).
  Future<void> evmClaimHtlc({
    required String privateKey,
    required String htlcAddress,
    required String preimage,
    String chain = 'eth',
  }) async {
    if (_web3 == null) return;
    emit(state.copyWith(isLoading: true, error: null));
    try {
      switchEvmChain(chain);
      final txHash = await _web3!.claimHtlc(
        privateKey: privateKey,
        htlcAddress: htlcAddress,
        preimage: preimage,
        chain: chain,
      );
      emit(state.copyWith(
        isLoading: false,
        lastResult: 'Claimed: $txHash',
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Claim failed: $e'));
    }
  }

  /// Refund an EVM HTLC (timelock expired).
  Future<void> evmRefundHtlc({
    required String privateKey,
    required String htlcAddress,
    String chain = 'eth',
  }) async {
    if (_web3 == null) return;
    emit(state.copyWith(isLoading: true, error: null));
    try {
      switchEvmChain(chain);
      final txHash = await _web3!.refundHtlc(
        privateKey: privateKey,
        htlcAddress: htlcAddress,
        chain: chain,
      );
      emit(state.copyWith(
        isLoading: false,
        lastResult: 'Refunded: $txHash',
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Refund failed: $e'));
    }
  }

  /// Send SOL (for funding HTLC or transfer).
  Future<void> sendSol({
    required String privateKeyBase58,
    required String toAddress,
    required double amountSol,
  }) async {
    if (_web3 == null) {
      emit(state.copyWith(error: 'Web3 not configured'));
      return;
    }
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final txHash = await _web3!.sendSol(privateKeyBase58, toAddress, amountSol);
      emit(state.copyWith(
        isLoading: false,
        lastResult: 'SOL sent: $txHash',
      ));
      await loadBalance();
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'SOL send failed: $e'));
    }
  }

  /// Send native EVM token (ETH/ARB/BASE/BSC).
  Future<void> sendEvm({
    required String privateKey,
    required String toAddress,
    required double amount,
    String chain = 'eth',
  }) async {
    if (_web3 == null) {
      emit(state.copyWith(error: 'Web3 not configured'));
      return;
    }
    emit(state.copyWith(isLoading: true, error: null));
    try {
      switchEvmChain(chain);
      final txHash = await _web3!.sendEth(privateKey, toAddress, amount, chain: chain);
      emit(state.copyWith(
        isLoading: false,
        lastResult: '$chain sent: $txHash',
      ));
      await loadBalance();
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: '$chain send failed: $e'));
    }
  }

  @override
  Future<void> close() {
    _http.close();
    _swapClient?.dispose();
    _web3?.dispose();
    return super.close();
  }
}
