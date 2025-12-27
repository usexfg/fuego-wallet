import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/contracts.dart';
import 'package:web3dart/json_rpc.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Web3 service for COLD token on Ethereum
class Web3COLDService {
  static final Logger _logger = Logger('Web3COLDService');

  // Singleton instance
  static Web3COLDService? _instance;
  static Web3COLDService get instance => _instance ??= Web3COLDService._();

  // Web3 client
  Web3Client? _client;
  DeployedContract? _coldContract;

  // COLD Token Contract Address (Ethereum Mainnet)
  static const String COLD_CONTRACT_ADDRESS = '0x5aFe5e5C60940B5C6Ca0322dFe51c6D01d455755';

  // COLD Token ABI (simplified)
  static const String COLD_ABI = '''
  [
    {
      "constant": true,
      "inputs": [{"name": "account","type":"address"}],
      "name": "balanceOf",
      "outputs": [{"name": "balance","type":"uint256"}],
      "type": "function"
    },
    {
      "constant": true,
      "inputs": [],
      "name": "decimals",
      "outputs": [{"name": "decimals","type":"uint8"}],
      "type": "function"
    },
    {
      "constant": true,
      "inputs": [],
      "name": "symbol",
      "outputs": [{"name": "symbol","type":"string"}],
      "type": "function"
    },
    {
      "constant": true,
      "inputs": [],
      "name": "name",
      "outputs": [{"name": "name","type":"string"}],
      "type": "function"
    },
    {
      "constant": true,
      "inputs": [],
      "name": "totalSupply",
      "outputs": [{"name": "supply","type":"uint256"}],
      "type": "function"
    },
    {
      "constant": false,
      "inputs": [
        {"name": "to","type":"address"},
        {"name": "value","type":"uint256"}
      ],
      "name": "transfer",
      "outputs": [{"name": "success","type":"bool"}],
      "type": "function"
    }
  ]
  ''';

  // RPC endpoints
  static const List<String> RPC_ENDPOINTS = [
    'https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161', // Public Infura
    'https://eth-mainnet.g.alchemy.com/v2/demo',
    'https://ethereum.publicnode.com',
    'https://eth.llamarpc.com',
  ];

  // State
  bool _isConnected = false;
  String _currentRpc = '';
  Map<String, dynamic>? _cachedBalance;
  DateTime? _lastBalanceUpdate;

  // Callbacks
  Function(String)? onLog;
  Function(bool)? onConnectionStatusChanged;
  Function(Map<String, dynamic>)? onBalanceUpdated;

  Web3COLDService._();

  /// Initialize the service
  Future<void> initialize() async {
    try {
      _logger.info('Initializing Web3COLDService...');

      // Try to restore last used RPC
      final prefs = await SharedPreferences.getInstance();
      _currentRpc = prefs.getString('cold_rpc_endpoint') ?? RPC_ENDPOINTS.first;

      // Connect to RPC
      await connect(_currentRpc);

      _logger.info('Web3COLDService initialized');
    } catch (e, stackTrace) {
      _logger.severe('Failed to initialize Web3COLDService', e, stackTrace);
      onLog?.call('ERROR: Failed to initialize Web3 service: $e');
    }
  }

  /// Connect to Ethereum RPC
  Future<bool> connect(String rpcEndpoint) async {
    try {
      onLog?.call('Connecting to Ethereum RPC...');

      // Create Web3 client
      _client = Web3Client(rpcEndpoint, http.Client());

      // Test connection
      final networkId = await _client!.getNetworkId();
      _logger.info('Connected to Ethereum network (ID: $networkId)');

      // Load COLD contract
      final abi = jsonDecode(COLD_ABI);
      _coldContract = DeployedContract(
        ContractAbi.fromJson(COLD_ABI, 'COLD'),
        EthereumAddress.fromHex(COLD_CONTRACT_ADDRESS),
      );

      _isConnected = true;
      _currentRpc = rpcEndpoint;
      onConnectionStatusChanged?.call(true);
      onLog?.call('Connected to Ethereum: $rpcEndpoint');

      // Save RPC endpoint
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cold_rpc_endpoint', rpcEndpoint);

      return true;
    } catch (e) {
      _logger.warning('Failed to connect to RPC: $rpcEndpoint - $e');
      onLog?.call('ERROR: Connection failed: $e');
      _isConnected = false;
      onConnectionStatusChanged?.call(false);
      return false;
    }
  }

  /// Try multiple RPC endpoints
  Future<bool> connectAuto() async {
    for (String endpoint in RPC_ENDPOINTS) {
      if (await connect(endpoint)) {
        return true;
      }
      onLog?.call('Trying next endpoint...');
      await Future.delayed(const Duration(milliseconds: 500));
    }

    onLog?.call('ERROR: All RPC endpoints failed');
    return false;
  }

  /// Disconnect from RPC
  Future<void> disconnect() async {
    await _client?.dispose();
    _client = null;
    _isConnected = false;
    onConnectionStatusChanged?.call(false);
    onLog?.call('Disconnected from Ethereum');
  }

  /// Get COLD token balance for an address
  Future<Map<String, dynamic>?> getBalance(String address) async {
    if (!_isConnected || _client == null || _coldContract == null) {
      onLog?.call('ERROR: Not connected to Ethereum');
      return null;
    }

    try {
      onLog?.call('Fetching COLD balance for $address...');

      final ethAddress = EthereumAddress.fromHex(address);

      // Get balance
      final balanceFunction = _coldContract!.function('balanceOf');
      final balanceResult = await _client!.call(
        contract: _coldContract!,
        function: balanceFunction,
        params: [ethAddress],
      );

      final rawBalance = balanceResult[0] as BigInt;

      // Get decimals
      final decimalsFunction = _coldContract!.function('decimals');
      final decimalsResult = await _client!.call(
        contract: _coldContract!,
        function: decimalsFunction,
        params: [],
      );

      final decimals = decimalsResult[0] as int;

      // Get symbol and name
      final symbolFunction = _coldContract!.function('symbol');
      final nameFunction = _coldContract!.function('name');

      final symbolResult = await _client!.call(
        contract: _coldContract!,
        function: symbolFunction,
        params: [],
      );

      final nameResult = await _client!.call(
        contract: _coldContract!,
        function: nameFunction,
        params: [],
      );

      final symbol = symbolResult[0] as String;
      final name = nameResult[0] as String;

      // Convert to human-readable format
      final balanceInTokens = rawBalance / BigInt.from(10).pow(decimals);
      final balanceDisplay = balanceInTokens.toStringAsFixed(2);

      final balanceData = {
        'address': address,
        'symbol': symbol,
        'name': name,
        'decimals': decimals,
        'rawBalance': rawBalance.toString(),
        'balance': balanceDisplay,
        'timestamp': DateTime.now().toIso8601String(),
        'network': 'ethereum',
      };

      _cachedBalance = balanceData;
      _lastBalanceUpdate = DateTime.now();

      onBalanceUpdated?.call(balanceData);
      onLog?.call('COLD Balance: $balanceDisplay $symbol');

      return balanceData;
    } catch (e, stackTrace) {
      _logger.severe('Failed to get COLD balance', e, stackTrace);
      onLog?.call('ERROR: Failed to get balance: $e');
      return null;
    }
  }

  /// Check if address is valid
  bool isValidEthereumAddress(String address) {
    try {
      EthereumAddress.fromHex(address);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get current block number
  Future<int?> getCurrentBlock() async {
    if (!_isConnected || _client == null) return null;

    try {
      final block = await _client!.getBlockNumber();
      onLog?.call('Current block: $block');
      return block;
    } catch (e) {
      _logger.warning('Failed to get block number: $e');
      return null;
    }
  }

  /// Get gas price
  Future<String?> getGasPrice() async {
    if (!_isConnected || _client == null) return null;

    try {
      final gasPrice = await _client!.getGasPrice();
      final gasInGwei = gasPrice.getInWei / BigInt.from(10).pow(9);
      onLog?.call('Gas price: ${gasInGwei.toStringAsFixed(2)} Gwei');
      return gasInGwei.toStringAsFixed(2);
    } catch (e) {
      _logger.warning('Failed to get gas price: $e');
      return null;
    }
  }

  /// Transfer COLD tokens
  Future<Map<String, dynamic>?> transfer({
    required String fromAddress,
    required String toAddress,
    required String amount,
    required String privateKey,
  }) async {
    if (!_isConnected || _client == null || _coldContract == null) {
      onLog?.call('ERROR: Not connected to Ethereum');
      return null;
    }

    try {
      onLog?.call('Initiating COLD transfer...');

      // Create credentials from private key
      final credentials = EthPrivateKey.fromHex(privateKey);

      // Verify from address matches credentials
      final credentialAddress = credentials.address;
      final expectedAddress = EthereumAddress.fromHex(fromAddress);
      if (credentialAddress != expectedAddress) {
        onLog?.call('ERROR: Private key does not match from address');
        return null;
      }

      // Parse amount with decimals
      final decimalsFunction = _coldContract!.function('decimals');
      final decimalsResult = await _client!.call(
        contract: _coldContract!,
        function: decimalsFunction,
        params: [],
      );
      final decimals = decimalsResult[0] as int;
      final amountWei = (double.parse(amount) * 10).pow(decimals).toInt();
      final amountBigInt = BigInt.from(amountWei);

      // Create transfer transaction
      final transferFunction = _coldContract!.function('transfer');
      final toAddressEth = EthereumAddress.fromHex(toAddress);

      final transaction = Transaction.callContract(
        contract: _coldContract!,
        function: transferFunction,
        parameters: [toAddressEth, amountBigInt],
        from: credentialAddress,
      );

      // Estimate gas
      final gasEstimate = await _client!.estimateGas(
        transaction: transaction,
      );

      // Send transaction
      final txHash = await _client!.sendTransaction(
        credentials,
        transaction.copyWith(gasPrice: await _client!.getGasPrice(), gas: gasEstimate),
        chainId: 1, // Ethereum Mainnet
      );

      onLog?.call('Transaction sent: $txHash');
      onLog?.call('View on https://etherscan.io/tx/$txHash');

      return {
        'success': true,
        'transactionHash': txHash,
        'from': fromAddress,
        'to': toAddress,
        'amount': amount,
        'timestamp': DateTime.now().toIso8601String(),
        'explorerUrl': 'https://etherscan.io/tx/$txHash',
      };
    } catch (e, stackTrace) {
      _logger.severe('COLD transfer failed', e, stackTrace);
      onLog?.call('ERROR: Transfer failed: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Get transaction receipt
  Future<Map<String, dynamic>?> getTransactionReceipt(String txHash) async {
    if (!_isConnected || _client == null) return null;

    try {
      final receipt = await _client!.getTransactionReceipt(txHash);
      if (receipt == null) return null;

      return {
        'transactionHash': receipt.transactionHash.toString(),
        'status': receipt.status,
        'blockNumber': receipt.blockNumber.toString(),
        'gasUsed': receipt.gasUsed.toString(),
        'from': receipt.from.toString(),
        'to': receipt.to.toString(),
      };
    } catch (e) {
      _logger.warning('Failed to get transaction receipt: $e');
      return null;
    }
  }

  /// Get cached balance (if recent)
  Map<String, dynamic>? get cachedBalance => _cachedBalance;

  /// Check if balance cache is still valid (within 5 minutes)
  bool get isBalanceCacheValid {
    if (_cachedBalance == null || _lastBalanceUpdate == null) return false;
    final age = DateTime.now().difference(_lastBalanceUpdate!);
    return age.inMinutes < 5;
  }

  /// Get current RPC endpoint
  String get currentRpc => _currentRpc;

  /// Get connection status
  bool get isConnected => _isConnected;

  /// Get available RPC endpoints
  List<String> get availableRpcEndpoints => RPC_ENDPOINTS;

  /// Set log callback
  void setLogCallback(Function(String) callback) {
    onLog = callback;
  }

  /// Set connection status callback
  void setConnectionCallback(Function(bool) callback) {
    onConnectionStatusChanged = callback;
  }

  /// Set balance update callback
  void setBalanceCallback(Function(Map<String, dynamic>) callback) {
    onBalanceUpdated = callback;
  }

  /// Dispose the service
  Future<void> dispose() async {
    await disconnect();
    onLog = null;
    onConnectionStatusChanged = null;
    onBalanceUpdated = null;
    _logger.info('Web3COLDService disposed');
  }
}
