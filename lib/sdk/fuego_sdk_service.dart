import 'package:fuego_sdk/fuego_sdk.dart';

/// Fuego SDK Service - Wrapper for FuegoSDK in the wallet app
/// 
/// This service provides a high-level interface to the Fuego SDK,
/// integrating node management, mining, CDs, swaps, HEAT proofs, and aliases.
class FuegoSDKService {
  static FuegoSDKService? _instance;
  late final FuegoSDK _sdk;
  
  late final NodeService _node;
  late final MiningService _mining;
  late final CDService _cd;
  late final SwapService _swap;
  late final HEATService _heat;
  late final AliasService _alias;

  FuegoSDKService._internal();

  /// Get singleton instance
  static FuegoSDKService get instance {
    _instance ??= FuegoSDKService._internal();
    return _instance!;
  }

  /// Initialize the SDK
  /// 
  /// [dataDir] - Directory for blockchain data (defaults to app documents directory)
  /// [testnet] - Use testnet if true
  Future<FuegoError> initialize({
    String? dataDir,
    bool testnet = false,
  }) async {
    _sdk = FuegoSDK.instance;
    
    // Initialize services
    _node = NodeService(_sdk);
    _mining = MiningService(_sdk);
    _cd = CDService(_sdk);
    _swap = SwapService(_sdk);
    _heat = HEATService(_sdk);
    _alias = AliasService(_sdk);

    return await _sdk.initialize(
      dataDir: dataDir ?? await _getDefaultDataDir(),
      testnet: testnet,
    );
  }

  /// Cleanup SDK resources
  void cleanup() {
    _sdk.cleanup();
  }

  /// Get the data directory path
  Future<String> _getDefaultDataDir() async {
    // This would use path_provider in actual implementation
    // For now, return a placeholder
    return '/tmp/fuego';
  }

  // ============================================================================
  // Node Service
  // ============================================================================

  /// Start the node
  Future<FuegoError> startNode({
    FuegoNodeMode mode = FuegoNodeMode.embedded,
    String? remoteHost,
    int? remotePort,
  }) {
    return _node.start(
      mode: mode,
      remoteHost: remoteHost,
      remotePort: remotePort,
    );
  }

  /// Stop the node
  Future<FuegoError> stopNode() => _node.stop();

  /// Check if node is running
  bool isNodeRunning() => _node.isRunning();

  /// Get peer count
  Future<int> getPeerCount() => _node.getPeerCount();

  /// Get block height
  Future<int> getBlockHeight() => _node.getBlockHeight();

  /// Get sync status
  Future<bool> isSynchronized() => _node.isSynchronized();

  // ============================================================================
  // Mining Service
  // ============================================================================

  /// Start mining
  Future<FuegoError> startMining(String walletAddress) =>
      _mining.start(walletAddress);

  /// Stop mining
  Future<FuegoError> stopMining() => _mining.stop();

  /// Check if mining is running
  bool isMiningRunning() => _mining.isRunning();

  /// Get hashrate
  Future<double> getHashrate() => _mining.getHashrate();

  // ============================================================================
  // CD Service
  // ============================================================================

  /// Create a CD
  Future<CDInfo> createCD({
    required int amount,
    required int lockTime,
    required String walletFile,
    required String walletPassword,
  }) {
    return _cd.create(
      amount: amount,
      lockTime: lockTime,
      walletFile: walletFile,
      walletPassword: walletPassword,
    );
  }

  /// Redeem a CD
  Future<int> redeemCD({
    required String txHash,
    required String walletFile,
    required String walletPassword,
  }) {
    return _cd.redeem(
      txHash: txHash,
      walletFile: walletFile,
      walletPassword: walletPassword,
    );
  }

  /// Get CD info
  Future<CDInfo> getCDInfo(String txHash) => _cd.getInfo(txHash);

  // ============================================================================
  // Swap Service
  // ============================================================================

  /// Initiate a swap
  Future<SwapInfo> initiateSwap({
    required String counterpartyAddress,
    required int amount,
    required String walletFile,
    required String walletPassword,
  }) {
    return _swap.initiate(
      counterpartyAddress: counterpartyAddress,
      amount: amount,
      walletFile: walletFile,
      walletPassword: walletPassword,
    );
  }

  /// Join a swap
  Future<SwapInfo> joinSwap({
    required String swapId,
    required String walletFile,
    required String walletPassword,
  }) {
    return _swap.join(
      swapId: swapId,
      walletFile: walletFile,
      walletPassword: walletPassword,
    );
  }

  /// Lock swap funds
  Future<FuegoError> lockSwapFunds({
    required String swapId,
    required String walletFile,
    required String walletPassword,
  }) {
    return _swap.lockFunds(
      swapId: swapId,
      walletFile: walletFile,
      walletPassword: walletPassword,
    );
  }

  /// Complete a swap
  Future<FuegoError> completeSwap({
    required String swapId,
    required String walletFile,
    required String walletPassword,
  }) {
    return _swap.complete(
      swapId: swapId,
      walletFile: walletFile,
      walletPassword: walletPassword,
    );
  }

  /// Refund a swap
  Future<FuegoError> refundSwap({
    required String swapId,
    required String walletFile,
    required String walletPassword,
  }) {
    return _swap.refund(
      swapId: swapId,
      walletFile: walletFile,
      walletPassword: walletPassword,
    );
  }

  /// Get swap info
  Future<SwapInfo> getSwapInfo(String swapId) => _swap.getInfo(swapId);

  // ============================================================================
  // HEAT Service
  // ============================================================================

  /// Generate HEAT proof
  Future<HEATProof> generateHEATProof({
    required String transactionData,
    required String walletFile,
    required String walletPassword,
  }) {
    return _heat.generateProof(
      transactionData: transactionData,
      walletFile: walletFile,
      walletPassword: walletPassword,
    );
  }

  /// Verify HEAT proof
  Future<bool> verifyHEATProof(HEATProof proof) => _heat.verifyProof(proof);

  // ============================================================================
  // Alias Service
  // ============================================================================

  /// Register alias
  Future<String> registerAlias({
    required String alias,
    required String walletAddress,
    required String walletFile,
    required String walletPassword,
  }) {
    return _alias.register(
      alias: alias,
      walletAddress: walletAddress,
      walletFile: walletFile,
      walletPassword: walletPassword,
    );
  }

  /// Resolve alias
  Future<String> resolveAlias(String alias) => _alias.resolve(alias);

  /// Get owned aliases
  Future<List<String>> getOwnedAliases(String walletAddress) =>
      _alias.getOwned(walletAddress);

  // ============================================================================
  // Properties
  // ============================================================================

  /// Get SDK version
  String get version => _sdk.version;

  /// Check if initialized
  bool get isInitialized => _sdk.isInitialized;

  /// Get node service
  NodeService get node => _node;

  /// Get mining service
  MiningService get mining => _mining;

  /// Get CD service
  CDService get cd => _cd;

  /// Get swap service
  SwapService get swap => _swap;

  /// Get HEAT service
  HEATService get heat => _heat;

  /// Get alias service
  AliasService get alias => _alias;
}
