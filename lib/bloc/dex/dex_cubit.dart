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

  final bool isSwapDaemonConnected;
  final List<SwapInfo> spvSwaps;
  final bool isSwapInitiating;

  final double evmBalance;
  final double solBalance;
  final bool isBalanceLoading;
  final String? htlcTxHash;

  const DexState({
    this.isLoading = false, this.error,
    this.selectedPair = SwapPairSdk.eth, this.selectedChain = ChainTypeSdk.ethereum,
    this.offers = const [], this.recentTrades = const [], this.price, this.orderbook,
    this.activeSwaps = const [], this.lastProof, this.lastResult, this.isConnected = false,
    this.isSwapDaemonConnected = false, this.spvSwaps = const [], this.isSwapInitiating = false,
    this.evmBalance = 0.0, this.solBalance = 0.0, this.isBalanceLoading = false, this.htlcTxHash,
  });

  DexState copyWith({
    bool? isLoading, String? error, SwapPairSdk? selectedPair, ChainTypeSdk? selectedChain,
    List<SwapOfferSdk>? offers, List<SwapTradeSdk>? recentTrades, SwapPriceSdk? price,
    OrderBookStateSdk? orderbook, List<SwapStatusSdk>? activeSwaps, PaymentProofSdk? lastProof,
    String? lastResult, bool? isConnected, bool? isSwapDaemonConnected, List<SwapInfo>? spvSwaps,
    bool? isSwapInitiating, double? evmBalance, double? solBalance, bool? isBalanceLoading,
    String? htlcTxHash,
  }) => DexState(
    isLoading: isLoading ?? this.isLoading, error: error,
    selectedPair: selectedPair ?? this.selectedPair, selectedChain: selectedChain ?? this.selectedChain,
    offers: offers ?? this.offers, recentTrades: recentTrades ?? this.recentTrades, price: price ?? this.price,
    orderbook: orderbook ?? this.orderbook, activeSwaps: activeSwaps ?? this.activeSwaps,
    lastProof: lastProof ?? this.lastProof, lastResult: lastResult, isConnected: isConnected ?? this.isConnected,
    isSwapDaemonConnected: isSwapDaemonConnected ?? this.isSwapDaemonConnected,
    spvSwaps: spvSwaps ?? this.spvSwaps, isSwapInitiating: isSwapInitiating ?? this.isSwapInitiating,
    evmBalance: evmBalance ?? this.evmBalance, solBalance: solBalance ?? this.solBalance,
    isBalanceLoading: isBalanceLoading ?? this.isBalanceLoading, htlcTxHash: htlcTxHash ?? this.htlcTxHash,
  );
}

class DexCubit extends Cubit<DexState> {
  final http.Client _http;
  String _baseUrl = '';
  SwapDaemonClient? _swapClient;
  Web3MultiChainService? _web3;
  String? _userAddress;

  DexCubit() : _http = http.Client(), super(const DexState());

  void configure(String host, {int port = 18189}) => _baseUrl = 'http://$host:$port';
  void configureSwapDaemon({String host = '127.0.0.1', int port = 18902}) => _swapClient = SwapDaemonClient(host: host, port: port);

  void configureWeb3({String ethRpcUrl = '', String solRpcUrl = '', String? userAddress}) {
    _web3 = Web3MultiChainService(ethRpcUrl: ethRpcUrl, solRpcUrl: solRpcUrl);
    if (userAddress != null) _userAddress = userAddress;
  }

  void switchEvmChain(String chain) {
    if (_web3 == null) return;
    switch (chain.toLowerCase()) {
      case 'arb': _web3!.setEthRpc(Web3MultiChainService.defaultArbRpc);
      case 'base': _web3!.setEthRpc(Web3MultiChainService.defaultBaseRpc);
      case 'bsc': _web3!.setEthRpc(Web3MultiChainService.defaultBscRpc);
      case 'poly': _web3!.setEthRpc(Web3MultiChainService.defaultPolyRpc);
      case 'eth': default: _web3!.setEthRpc(Web3MultiChainService.defaultEthRpc);
    }
  }

  Future<void> init({String host = '127.0.0.1', int port = 18189}) async {
    configure(host, port: port);
    configureSwapDaemon();
    configureWeb3();
    await _checkConnection();
    await _checkSwapDaemon();
  }

  Future<void> _checkConnection() async {
    if (_baseUrl.isEmpty) return;
    try {
      final resp = await _http.get(Uri.parse('$_baseUrl/getinfo')).timeout(const Duration(seconds: 5));
      if (resp.statusCode == 200) {
        emit(state.copyWith(isConnected: true, error: null));
        await loadOffers(); await loadPrice(); await loadOrderbook();
      }
    } catch (e) {
      emit(state.copyWith(error: 'Cannot connect to fuegod: $e'));
    }
  }

  Future<Map<String, dynamic>> _get(String path, {Map<String, String>? query}) async {
    final resp = await _http.get(_rest(path, query: query)).timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final resp = await _http.post(_rest(path), headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(const Duration(seconds: 10));
    if (resp.statusCode != 200) throw Exception('HTTP ${resp.statusCode}');
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }

  Uri _rest(String path, {Map<String, String>? query}) =>
      Uri(scheme: 'http', host: Uri.parse(_baseUrl).host, port: Uri.parse(_baseUrl).port, path: path, queryParameters: query);

  void selectPair(SwapPairSdk pair) {
    final chain = _chainForPair(pair);
    emit(state.copyWith(selectedPair: pair, selectedChain: chain, offers: [], recentTrades: [], isLoading: true));
    loadOffers(); loadPrice(); loadTrades();
  }
  void selectChain(ChainTypeSdk chain) => emit(state.copyWith(selectedChain: chain));

  ChainTypeSdk _chainForPair(SwapPairSdk pair) {
    switch (pair) {
      case SwapPairSdk.sol: return ChainTypeSdk.solana;
      case SwapPairSdk.eth: return ChainTypeSdk.ethereum;
      case SwapPairSdk.xmr: return ChainTypeSdk.monero;
      case SwapPairSdk.bch: return ChainTypeSdk.bitcoinCash;
      case SwapPairSdk.arb: return ChainTypeSdk.arbitrum;
      case SwapPairSdk.base: return ChainTypeSdk.base;
      case SwapPairSdk.kmd: return ChainTypeSdk.komodo;
      case SwapPairSdk.bnb: return ChainTypeSdk.bnb;
      case SwapPairSdk.dcr: return ChainTypeSdk.decred;
      case SwapPairSdk.btc: return ChainTypeSdk.bitcoin;
      case SwapPairSdk.ltc: return ChainTypeSdk.litecoin;
      case SwapPairSdk.poly: return ChainTypeSdk.polygon;
    }
  }

  Future<void> loadOffers() async {
    if (_baseUrl.isEmpty) return;
    try {
      final r = await _get('/getswapoffers', query: {'pair': state.selectedPair.id.toString()});
      final offersList = (r['offers'] as List<dynamic>? ?? []).map((o) => SwapOfferSdk.fromJson(o as Map<String, dynamic>)).toList();
      emit(state.copyWith(offers: offersList, error: null));
    } catch (e) { debugPrint('DexCubit: loadOffers failed: $e'); }
  }

  Future<void> loadPrice() async {
    if (_baseUrl.isEmpty) return;
    try {
      final r = await _get('/getswapprice', query: {'pair': state.selectedPair.id.toString()});
      emit(state.copyWith(price: SwapPriceSdk.fromJson(r)));
    } catch (e) { debugPrint('DexCubit: loadPrice failed: $e'); }
  }

  Future<void> loadTrades() async {
    if (_baseUrl.isEmpty) return;
    try {
      final r = await _get('/getswaptrades', query: {'pair': state.selectedPair.id.toString(), 'limit': '50'});
      final trades = (r['trades'] as List<dynamic>? ?? []).map((t) => SwapTradeSdk.fromJson(t as Map<String, dynamic>)).toList();
      emit(state.copyWith(recentTrades: trades));
    } catch (e) { debugPrint('DexCubit: loadTrades failed: $e'); }
  }

  Future<void> loadOrderbook() async {
    if (_baseUrl.isEmpty) return;
    try {
      final r = await _get('/get_orderbook_state', query: {'depth': '20'});
      emit(state.copyWith(orderbook: OrderBookStateSdk.fromJson(r)));
    } catch (e) { debugPrint('DexCubit: loadOrderbook failed: $e'); }
  }

  Future<void> loadActiveSwaps() async {
    if (_baseUrl.isEmpty) return;
    try {
      final r = await _post('/getactiveswaps', {});
      final swaps = (r['swaps'] as List<dynamic>? ?? []).map((s) => SwapStatusSdk.fromJson(s as Map<String, dynamic>)).toList();
      emit(state.copyWith(activeSwaps: swaps));
    } catch (e) { debugPrint('DexCubit: loadActiveSwaps failed: $e'); }
  }

  Future<void> submitOffer({required int xfgAmount, required int rateNum, required String makerPubKey, required String signature, int ttlBlocks = 1440}) async {
    // Fail honestly instead of sending unsigned garbage: offer signing uses the
    // wallet's sign_offer RPC (C++ SimpleWallet), which this wallet build does
    // not expose. The SwapXFG CLI remains the orderbook path for signed offers.
    if (makerPubKey.isEmpty || signature.isEmpty) {
      emit(state.copyWith(isLoading: false,
        error: 'Offer signing is not available in this wallet build — use the SwapXFG CLI to post signed offers'));
      return;
    }
    emit(state.copyWith(isLoading: true, lastResult: null, error: null));
    try {
      final r = await _post('/submitswap', {'offerId': DateTime.now().millisecondsSinceEpoch.toRadixString(16), 'xfgAmount': xfgAmount, 'rateNum': rateNum, 'pair': state.selectedPair.id, 'makerPubKey': makerPubKey, 'signature': signature, 'ttlBlocks': ttlBlocks});
      emit(state.copyWith(isLoading: false, lastResult: 'Offer submitted: ${r['status'] ?? 'error'}'));
      await loadOffers();
    } catch (e) { emit(state.copyWith(isLoading: false, error: 'Submit failed: $e')); }
  }

  Future<void> cancelOffer({required String offerId, required String makerPubKey, required String signature}) async {
    if (makerPubKey.isEmpty || signature.isEmpty) {
      emit(state.copyWith(isLoading: false,
        error: 'Offer cancellation signing is not available in this wallet build — use the SwapXFG CLI'));
      return;
    }
    emit(state.copyWith(isLoading: true, lastResult: null, error: null));
    try {
      final r = await _post('/cancelswap', {'offerId': offerId, 'makerPubKey': makerPubKey, 'signature': signature});
      emit(state.copyWith(isLoading: false, lastResult: 'Offer cancelled: ${r['status'] ?? 'error'}'));
      await loadOffers();
    } catch (e) { emit(state.copyWith(isLoading: false, error: 'Cancel failed: $e')); }
  }

  Future<void> requestSwap({required String offerId, required int amount, required String takerPubKey, required String proofOfFunds}) async {
    // A signed taker identity + reserve proof are required; neither is
    // producible in this wallet build yet. Fail honestly instead of sending
    // empty values that the daemon would reject anyway.
    if (takerPubKey.isEmpty || proofOfFunds.isEmpty) {
      emit(state.copyWith(isLoading: false,
        error: 'Taking offers requires a signed taker identity — use the SwapXFG CLI for order fills'));
      return;
    }
    emit(state.copyWith(isLoading: true, lastResult: null, error: null));
    try {
      final r = await _post('/requestswap', {'offerId': offerId, 'amount': amount, 'takerPubKey': takerPubKey, 'proofOfFunds': proofOfFunds});
      emit(state.copyWith(isLoading: false, lastResult: 'Swap requested: ${r['status'] ?? 'error'}'));
    } catch (e) { emit(state.copyWith(isLoading: false, error: 'Swap failed: $e')); }
  }

  Future<void> verifyPayment({required String txHash, required String fromAddress, required String toAddress, required int amount, int minConfirmations = 6}) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final r = await _post('/verify_payment', {'chain': state.selectedChain.id, 'tx_hash': txHash, 'from_address': fromAddress, 'to_address': toAddress, 'amount': amount, 'min_confirmations': minConfirmations});
      final proof = PaymentProofSdk.fromJson(r);
      emit(state.copyWith(isLoading: false, lastProof: proof, lastResult: proof.verified ? 'Payment verified: ${proof.confirmations} confirmations' : 'Payment NOT verified'));
    } catch (e) { emit(state.copyWith(isLoading: false, error: 'Verification failed: $e')); }
  }

  Future<HtlcHashLock?> createHtlcHashLock() async {
    try {
      final r = await _post('/htlc_create_hash_lock', {});
      return HtlcHashLock.fromJson(r);
    } catch (e) { emit(state.copyWith(error: 'HTLC hash lock failed: $e')); return null; }
  }

  Future<HtlcScript?> buildHtlcScript({required String hashLock, required String recipientPubkey, required String senderPubkey, required int timelock}) async {
    try {
      final r = await _post('/htlc_build_script', {'hash_lock': hashLock, 'recipient_pubkey': recipientPubkey, 'sender_pubkey': senderPubkey, 'timelock': timelock});
      return HtlcScript.fromJson(r);
    } catch (e) { emit(state.copyWith(error: 'HTLC script build failed: $e')); return null; }
  }

  Future<void> refresh() async {
    await loadOffers(); await loadPrice(); await loadTrades(); await loadOrderbook(); await loadActiveSwaps();
    if (_swapClient != null) await loadSpvSwaps();
  }

  Future<void> _checkSwapDaemon() async {
    if (_swapClient == null) return;
    try {
      final available = await _swapClient!.isAvailable();
      emit(state.copyWith(isSwapDaemonConnected: available));
      if (available) await loadSpvSwaps();
    } catch (e) { emit(state.copyWith(isSwapDaemonConnected: false)); }
  }

  Future<void> loadSpvSwaps() async {
    if (_swapClient == null) return;
    try {
      final swaps = await _swapClient!.listSwaps();
      emit(state.copyWith(spvSwaps: swaps, error: null));
    } catch (e) { debugPrint('DexCubit: loadSpvSwaps failed: $e'); }
  }

  Future<void> initiateCrossChainSwap({required String pair, required int xfgAmount, required int ctrAmount, required String peer, String role = 'alice', String? expectedPeerPubkey}) async {
    if (_swapClient == null) { emit(state.copyWith(error: 'Swap daemon not connected')); return; }
    emit(state.copyWith(isSwapInitiating: true, error: null, lastResult: null));
    try {
      final swapId = await _swapClient!.initiateSwap(
        pair: pair, xfgAmount: xfgAmount, ctrAmount: ctrAmount, peer: peer,
        role: role, expectedPeerPubkey: expectedPeerPubkey);
      emit(state.copyWith(isSwapInitiating: false, lastResult: 'Swap initiated: $swapId'));
      await loadSpvSwaps();
    } catch (e) { emit(state.copyWith(isSwapInitiating: false, error: 'Failed to initiate swap: $e')); }
  }

  Future<void> acceptSwap(String swapId) async {
    if (_swapClient == null) { emit(state.copyWith(error: 'Swap daemon not connected')); return; }
    emit(state.copyWith(isLoading: true, error: null, lastResult: null));
    try {
      final result = await _swapClient!.acceptSwap(swapId);
      emit(state.copyWith(isLoading: false, lastResult: 'Accepted: ${result['state'] ?? swapId}'));
      await loadSpvSwaps();
    } catch (e) { emit(state.copyWith(isLoading: false, error: 'Accept failed: $e')); }
  }

  Future<void> refundSpvSwap(String swapId) async {
    if (_swapClient == null) return;
    emit(state.copyWith(isLoading: true, error: null));
    try {
      await _swapClient!.refund(swapId);
      emit(state.copyWith(isLoading: false, lastResult: 'Refunded: $swapId'));
      await loadSpvSwaps();
    } catch (e) { emit(state.copyWith(isLoading: false, error: 'Refund failed: $e')); }
  }

  Future<void> checkSpvTimeouts() async {
    if (_swapClient == null) return;
    try {
      final result = await _swapClient!.checkTimeouts();
      if (result.refunded.isNotEmpty) emit(state.copyWith(lastResult: 'Refunded ${result.refunded.length} timed-out swap(s)'));
      await loadSpvSwaps();
    } catch (e) { debugPrint('DexCubit: checkSpvTimeouts failed: $e'); }
  }

  Future<void> loadBalance({String? address}) async {
    final addr = address ?? _userAddress;
    if (addr == null || addr.isEmpty || _web3 == null) return;
    emit(state.copyWith(isBalanceLoading: true));
    try {
      final bal = await _web3!.getBalance(addr, _userAddress ?? 'eth');
      emit(state.copyWith(evmBalance: bal, isBalanceLoading: false));
    } catch (e) { emit(state.copyWith(isBalanceLoading: false, error: 'Balance fetch failed: $e')); }
  }

  Future<void> evmLockHtlc({required String privateKey, required String htlcAddress, required String hashlock, required int timelock, required double amount, String chain = 'eth'}) async {
    if (_web3 == null) { emit(state.copyWith(error: 'Web3 not configured')); return; }
    emit(state.copyWith(isLoading: true, error: null, lastResult: null));
    try {
      switchEvmChain(chain);
      final txHash = await _web3!.lockHtlc(privateKey: privateKey, htlcAddress: htlcAddress, hashlock: hashlock, timelock: timelock, amount: amount, chain: chain);
      emit(state.copyWith(isLoading: false, htlcTxHash: txHash, lastResult: 'HTLC locked: $txHash'));
    } catch (e) { emit(state.copyWith(isLoading: false, error: 'HTLC lock failed: $e')); }
  }

  Future<void> evmClaimHtlc({required String privateKey, required String htlcAddress, required String preimage, String chain = 'eth'}) async {
    if (_web3 == null) return;
    emit(state.copyWith(isLoading: true, error: null));
    try {
      switchEvmChain(chain);
      final txHash = await _web3!.claimHtlc(privateKey: privateKey, htlcAddress: htlcAddress, preimage: preimage, chain: chain);
      emit(state.copyWith(isLoading: false, lastResult: 'Claimed: $txHash'));
    } catch (e) { emit(state.copyWith(isLoading: false, error: 'Claim failed: $e')); }
  }

  Future<void> evmRefundHtlc({required String privateKey, required String htlcAddress, String chain = 'eth'}) async {
    if (_web3 == null) return;
    emit(state.copyWith(isLoading: true, error: null));
    try {
      switchEvmChain(chain);
      final txHash = await _web3!.refundHtlc(privateKey: privateKey, htlcAddress: htlcAddress, chain: chain);
      emit(state.copyWith(isLoading: false, lastResult: 'Refunded: $txHash'));
    } catch (e) { emit(state.copyWith(isLoading: false, error: 'Refund failed: $e')); }
  }

  @override
  Future<void> close() { _http.close(); _swapClient?.dispose(); _web3?.dispose(); return super.close(); }
}
