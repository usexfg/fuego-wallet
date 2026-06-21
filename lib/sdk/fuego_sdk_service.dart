import 'package:fuego_sdk/fuego_sdk.dart';
import 'package:fuego_sdk/src/wallet_service.dart';
import 'package:fuego_sdk/src/pool_service.dart';
import 'package:path_provider/path_provider.dart';

/// Fuego SDK Service - Wrapper for FuegoSDK in the wallet app
class FuegoSDKService {
  static FuegoSDKService? _instance;
  late final FuegoSDK _sdk;
  
  late final NodeService _node;
  late final MiningService _mining;
  late final CDService _cd;
  late final SwapService _swap;
  late final HEATService _heat;
  late final AliasService _alias;
  late final WalletService _wallet;
  late final PoolService _pool;

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
    _wallet = WalletService(_sdk);
    _pool = PoolService(_sdk);

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
    try {
      final dir = await getApplicationSupportDirectory();
      return dir.path;
    } catch (_) {
      return '/tmp/fuego';
    }
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
    required int xfgAmount,
    required int counterpartyAmount,
    required String counterpartyChain,
    required String walletFile,
    required String walletPassword,
  }) {
    return _swap.initiate(
      counterpartyAddress: counterpartyAddress,
      xfgAmount: xfgAmount,
      counterpartyAmount: counterpartyAmount,
      counterpartyChain: counterpartyChain,
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

  /// Lock counterparty funds
  Future<FuegoError> lockCounterpartySwapFunds({
    required String swapId,
    required String counterpartyTxHash,
  }) {
    return _swap.lockCounterpartyFunds(
      swapId: swapId,
      counterpartyTxHash: counterpartyTxHash,
    );
  }

  /// Extract adaptor secret
  Future<List<int>> extractSwapSecret({
    required String swapId,
    required List<int> preSignature,
    required List<int> finalSignature,
  }) {
    return _swap.extractSecret(
      swapId: swapId,
      preSignature: preSignature,
      finalSignature: finalSignature,
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
  // Pool Service
  // ============================================================================

  /// Initialize the pool
  Future<FuegoError> initializePool({
    required int xfgAmount,
    required int heatAmount,
    int feeBps = 30,
  }) {
    return _pool.initialize(
      xfgAmount: xfgAmount,
      heatAmount: heatAmount,
      feeBps: feeBps,
    );
  }

  /// Get pool reserves
  Future<PoolReserves> getPoolReserves() => _pool.getReserves();

  /// Execute a pool swap
  Future<PoolSwapResult> poolSwap({
    required String inputAsset,
    required int inputAmount,
    int minOutput = 0,
  }) {
    return _pool.swap(
      inputAsset: inputAsset,
      inputAmount: inputAmount,
      minOutput: minOutput,
    );
  }

  /// Get estimated output from pool
  Future<int> getEstimatedPoolOutput({
    required String inputAsset,
    required int inputAmount,
  }) {
    return _pool.getEstimatedOutput(
      inputAsset: inputAsset,
      inputAmount: inputAmount,
    );
  }

  /// Add liquidity
  Future<PoolLiquidityResult> addPoolLiquidity({
    required int xfgAmount,
    required int heatAmount,
    int minLP = 0,
  }) {
    return _pool.addLiquidity(
      xfgAmount: xfgAmount,
      heatAmount: heatAmount,
      minLP: minLP,
    );
  }

  /// Remove liquidity
  Future<PoolLiquidityResult> removePoolLiquidity({
    required int lpAmount,
    int minXFG = 0,
    int minHEAT = 0,
  }) {
    return _pool.removeLiquidity(
      lpAmount: lpAmount,
      minXFG: minXFG,
      minHEAT: minHEAT,
    );
  }

  /// Get LP balance
  Future<int> getLPBalance(String address) => _pool.getLPBalance(address);

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

  /// Get pool service
  PoolService get pool => _pool;

  /// Get wallet service
  WalletService get wallet => _wallet;

  // ============================================================================
  // Wallet Operations
  // ============================================================================

  /// Open a wallet file
  FuegoError openWallet(String path, String password) =>
      _wallet.open(path, password);

  /// Close the wallet
  void closeWallet() => _wallet.close();

  /// Check if wallet is open
  bool get isWalletOpen => _wallet.isOpen;

  /// Get XFG balance as double
  double get xfgBalance => _wallet.xfgAvailable;
  double get xfgLockedBalance => _wallet.xfgLocked;

  /// Get HEAT balance as double
  double get heatBalance => _wallet.heatAvailable;
  double get heatLockedBalance => _wallet.heatLocked;

  /// Send XFG or HEAT
  Future<({String txHash, FuegoError error})> send({
    required String address,
    required double amount,
    String? assetId,
    double fee = 0.01,
    String? paymentId,
  }) async {
    return _wallet.send(
      address: address,
      amount: amount,
      assetId: assetId,
      fee: fee,
      paymentId: paymentId,
    );
  }
}
