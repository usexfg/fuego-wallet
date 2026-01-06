import 'dart:collection';

/// COLD Interest Token Configuration
///
/// Handles the official C0LD token and Fuego Mob Custom Interest Assets
/// All offerings require DAO voting + 1 C0LD burn to add
enum Blockchain {
  ethereum,
  solana,
  // Future: zksync_era, zk_c0dl3, arbitrum, polygon
}

/// Token type classification
enum TokenType {
  official,    // Main C0LD interest token
  community,   // Fuego Mob vetted offerings
  future,      // Planned tokens
}

/// Single token definition
class ColdTokenInfo {
  final String name;
  final String symbol;
  final String contractAddress;
  final Blockchain chain;
  final TokenType type;
  final String interestRate; // e.g., "12.5%", "8%", "Variable"
  final String description;
  final String documentation; // IPFS link or URL
  final bool isActive;
  final DateTime? additionDate; // When added to DAO
  final int? burnRequirement; // C0LD tokens required for listing
  final bool requiresDaoVote; // Must go through DAO

  const ColdTokenInfo({
    required this.name,
    required this.symbol,
    required this.contractAddress,
    required this.chain,
    required this.type,
    required this.interestRate,
    required this.description,
    required this.documentation,
    this.isActive = true,
    this.additionDate,
    this.burnRequirement = 1, // Standard: 1 C0LD to add
    this.requiresDaoVote = true,
  });

  /// Get chain icon/emoji
  String get chainIcon {
    switch (chain) {
      case Blockchain.ethereum: return 'Ξ';
      case Blockchain.solana: return '◎';
      // case Blockchain.zksync_era: return '⚡';
      // case Blockchain.zk_c0dl3: return '❄️';
      default: return '⛓️';
    }
  }

  /// Get type badge
  String get typeLabel {
    switch (type) {
      case TokenType.official: return 'OFFICIAL';
      case TokenType.community: return 'FUEGO MOB';
      case TokenType.future: return 'PROPOSED';
    }
  }

  /// Display interest with HEAT earnings
  String get interestDisplay {
    return '$interestRate (paid in HEAT)';
  }

  /// Is burn requirement met (for UI)
  bool get isListingRequirementsMet {
    return burnRequirement != null ? burnRequirement! >= 1 : false;
  }
}

/// Repository of all COLD interest offerings
class ColdTokenRepository {
  static ColdTokenRepository? _instance;
  static ColdTokenRepository get instance {
    _instance ??= ColdTokenRepository._internal();
    return _instance!;
  }

  ColdTokenRepository._internal();

  /// Official C0LD token (Ethereum Mainnet)
  const ColdTokenInfo officialC0LD = ColdTokenInfo(
    name: 'C0LD',
    symbol: 'C0LD',
    contractAddress: '0x5aFe5e5C60940B5C6Ca0322dFe51c6D01d455755', // Mainnet
    chain: Blockchain.ethereum,
    type: TokenType.official,
    interestRate: '12.5% - 33%',
    description: 'Official Fuego interest token. Generates C0DL3 rollup interest paid in HEAT tokens',
    documentation: 'https://usexfg.org/c0ld-whitepaper',
    burnRequirement: null, // No burn needed for official
    requiresDaoVote: false,
  );

  /// Future additions will go here after DAO:
  /// Future tokens need:
  /// 1. DAO vote by Fuego Mob
  /// 2. Burn 1 full C0LD token
  /// 3. Submit to add to this list

  /// Current community offerings (ETH)
  final List<ColdTokenInfo> ethOfferings = [
    ColdTokenInfo(
      name: 'C0LD Interest',
      symbol: 'C0LD-ETH',
      contractAddress: '0x5aFe5e5C60940B5C6Ca0322dFe51c6D01d455755',
      chain: Blockchain.ethereum,
      type: TokenType.official,
      interestRate: '12.5% - 33%',
      description: 'Standard C0LD interest via C0DL3 rollup',
      documentation: 'https://usexfg.org/interest',
      additionDate: DateTime.parse('2024-01-01'),
    ),
  ];

  /// Current community offerings (Solana)
  final List<ColdTokenInfo> solanaOfferings = [
    // Fuego Mob offerings would be added here after DAO vetting
  ];

  /// Future proposed tokens (pending DAO + C0LD burn)
  final List<ColdTokenInfo> proposedTokens = [
    const ColdTokenInfo(
      name: 'zkC0DL3',
      symbol: 'zkC0DL3',
      contractAddress: '0x0000000000000000000000000000000000000000', // Placeholder
      chain: Blockchain.ethereum,
      type: TokenType.future,
      interestRate: 'Variable',
      description: 'Zero-knowledge C0DL3 rollup for enhanced privacy',
      documentation: 'https://usexfg.org/zk-c0dl3-proposal',
      isActive: false,
      burnRequirement: 1,
      requiresDaoVote: true,
    ),
    const ColdTokenInfo(
      name: 'HEAT',
      symbol: 'HEAT',
      contractAddress: '0x0000000000000000000000000000000000000000', // Placeholder
      chain: Blockchain.ethereum,
      type: TokenType.future,
      interestRate: 'Dynamic',
      description: 'HEAT token as C0LD interest earner',
      documentation: 'https://usexfg.org/heat-proposal',
      isActive: false,
      burnRequirement: 1,
      requiresDaoVote: true,
    ),
    const ColdTokenInfo(
      name: 'Fuego-SOL',
      symbol: 'Fuego-SOL',
      contractAddress: 'VERSE_SOL_ADDRESS', // Solana program ID
      chain: Blockchain.solana,
      type: TokenType.future,
      interestRate: '10%',
      description: 'Solana-based Fuego interest offering',
      documentation: 'https://usexfg.org/sol-proposal',
      isActive: false,
      burnRequirement: 1,
      requiresDaoVote: true,
    ),
  ];

  /// Get all active tokens by chain
  List<ColdTokenInfo> getActiveTokens(Blockchain chain, {bool includeOfficial = true}) {
    final List<ColdTokenInfo> tokens = [];

    if (includeOfficial && officialC0LD.chain == chain) {
      tokens.add(officialC0LD);
    }

    switch (chain) {
      case Blockchain.ethereum:
        tokens.addAll(ethOfferings.where((t) => t.isActive));
        break;
      case Blockchain.solana:
        tokens.addAll(solanaOfferings.where((t) => t.isActive));
        break;
      default:
        break;
    }

    return tokens;
  }

  /// Get proposed tokens (DAO voting queue)
  List<ColdTokenInfo> getProposedTokens() {
    return proposedTokens.where((t) => !t.isActive).toList();
  }

  /// Get all chains with active offerings
  List<Blockchain> getAvailableChains() {
    final chains = <Blockchain>[];
    if (getActiveTokens(Blockchain.ethereum).isNotEmpty) chains.add(Blockchain.ethereum);
    if (getActiveTokens(Blockchain.solana).isNotEmpty) chains.add(Blockchain.solana);
    return chains;
  }

  /// Add new token proposal (must go through DAO + C0LD burn)
  Future<String> proposeToken({
    required String name,
    required String symbol,
    required String contractAddress,
    required Blockchain chain,
    required String interestRate,
    required String description,
    required String documentation,
  }) async {
    // In production, this would:
    // 1. Create a DAO proposal
    // 2. Wait for Fuego Mob vote
    // 3. Require 1 C0LD burn transaction
    // 4. Add to proposedTokens list
    // 5. Once approved -> move to active offerings

    final newToken = ColdTokenInfo(
      name: name,
      symbol: symbol,
      contractAddress: contractAddress,
      chain: chain,
      type: TokenType.community,
      interestRate: interestRate,
      description: description,
      documentation: documentation,
      isActive: false, // Until DAO approved
      additionDate: DateTime.now(),
      burnRequirement: 1,
      requiresDaoVote: true,
    );

    proposedTokens.add(newToken);
    return "Token proposal submitted: Requires DAO vote + 1 C0LD burn to activate";
  }

  /// Burn C0LD to add token to offerings
  Future<String> burnC0LDForListing({required ColdTokenInfo token}) async {
    if (!token.requiresDaoVote) {
      return "Official C0LD token doesn't require burn for listing";
    }

    // In production:
    // 1. Check wallet for C0LD balance
    // 2. Prompt for 1 C0LD burn
    // 3. Generate burn proof (STARK)
    // 4. Submit to Fuego Mob DAO
    // 5. Upon vote success -> activate token

    return "Requires 1 C0LD burn. Use Ξternal Flame menu → Burn 1 C0LD → Submit to DAO";
  }

  /// Get token by address
  ColdTokenInfo? getTokenByAddress(String address, Blockchain chain) {
    final allTokens = getActiveTokens(chain);
    allTokens.addAll(proposedTokens);
    return allTokens.firstWhere(
      (t) => t.contractAddress.toLowerCase() == address.toLowerCase(),
      orElse: () => null,
    );
  }

  /// Get official C0LD info
  ColdTokenInfo getOfficialC0LD() {
    return officialC0LD;
  }

  /// Check if address is C0LD (official)
  bool isOfficialC0LD(String address, Blockchain chain) {
    return officialC0LD.chain == chain &&
           officialC0LD.contractAddress.toLowerCase() == address.toLowerCase();
  }
}

/// DAO Vote Status (for proposed tokens)
enum DaoVoteStatus {
  pending,
  active,
  passed,
  failed,
  completed,
}

/// DAO Proposal info
class DaoProposal {
  final String proposalId;
  final ColdTokenInfo token;
  final DaoVoteStatus status;
  final DateTime createdAt;
  final DateTime? votingEnds;
  final int yesVotes;
  final int noVotes;
  final int totalVoters;
  final bool burnCompleted;

  const DaoProposal({
    required this.proposalId,
    required this.token,
    required this.status,
    required this.createdAt,
    this.votingEnds,
    this.yesVotes = 0,
    this.noVotes = 0,
    this.totalVoters = 0,
    this.burnCompleted = false,
  });

  double get votePercentage {
    if (totalVoters == 0) return 0.0;
    return (yesVotes / totalVoters) * 100.0;
  }

  bool get isApproved {
    return votePercentage >= 51.0 && burnCompleted;
  }

  String get statusText {
    switch (status) {
      case DaoVoteStatus.pending:
        return burnCompleted ? 'Pending DAO Vote' : 'Awaiting 1 C0LD Burn';
      case DaoVoteStatus.active:
        return 'Voting Active: ${votePercentage.toStringAsFixed(1)}%';
      case DaoVoteStatus.passed:
        return 'Passed: Awaiting Activation';
      case DaoVoteStatus.failed:
        return 'Failed - Insufficient Votes';
      case DaoVoteStatus.completed:
        return 'Listing Complete';
    }
  }
}

/// Helper for UI presentation
class ColdTokenPresentation {
  static String getChainDisplayName(Blockchain chain) {
    switch (chain) {
      case Blockchain.ethereum: return 'Ethereum (Ξ)';
      case Blockchain.solana: return 'Solana (◎)';
      // case Blockchain.zksync_era: return 'ZKsync Era (⚡)';
      // case Blockchain.zk_c0dl3: return 'zkC0DL3 (❄️)';
      default: return chain.name.toUpperCase();
    }
  }

  static String getTokenTypeBadge(TokenType type) {
    switch (type) {
      case TokenType.official: return '🏆 OFFICIAL';
      case TokenType.community: return '🔥 FUEGO MOB';
      case TokenType.future: return '🗳️ DAO PROPOSAL';
    }
  }

  static Color getChainColor(Blockchain chain) {
    switch (chain) {
      case Blockchain.ethereum: return const Color(0xFF627EEA); // ETH blue
      case Blockchain.solana: return const Color(0xFF9945FF); // SOL purple
      // case Blockchain.zksync_era: return const Color(0xFF000000);
      default: return const Color(0xFFF44336); // Fuego red
    }
  }
}
```

## **2. Multi-Chain Web3 Service (ETH + Solana)**<tool_call>
<function=terminal>
<parameter=command>cat > lib/services/web3_multi_chain_service.dart << 'EOF'
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/cold_tokens_config.dart';

/// Multi-chain Web3 service for C0LD interest management
/// Supports: Ethereum (ETH) and Solana (SOL)
/// Future: ZKsync Era, zkC0DL3, Arbitrum, Polygon
class Web3MultiChainService {
  static final Logger _logger = Logger('Web3MultiChainService');

  static Web3MultiChainService? _instance;
  static Web3MultiChainService get instance => _instance ??= Web3MultiChainService._();

  // Ethereum client
  Web3Client? _ethClient;

  // Solana client (via RPC)
  http.Client? _solClient;

  // Current selected chain
  Blockchain _currentChain = Blockchain.ethereum;

  // Active chain clients
  final Map<Blockchain, bool> _chainStatus = {
    Blockchain.ethereum: false,
    Blockchain.solana: false,
  };

  // RPC endpoints with failover
  final Map<Blockchain, List<String>> _rpcEndpoints = {
    Blockchain.ethereum: [
      'https://mainnet.infura.io/v3/9aa3d95b3bc440fa88ea12eaa4456161',
      'https://eth-mainnet.g.alchemy.com/v2/demo',
      'https://ethereum.publicnode.com',
      'https://eth.llamarpc.com',
    ],
    Blockchain.solana: [
      'https://api.mainnet.solana.com',
      'https://solana.public-rpc.com',
      'https://rpc.ankr.com/solana',
    ],
  };

  // Callbacks
  Function(String)? onLog;
  Function(bool)? onChainStatusChanged;
  Function(Map<String, dynamic>)? onBalanceUpdated;

  Web3MultiChainService._();

  /// Initialize service
  Future<void> initialize() async {
    try {
      _logger.info('Initializing Web3MultiChainService...');
      final prefs = await SharedPreferences.getInstance();

      // Restore last chain
      final chainName = prefs.getString('last_chain') ?? 'ethereum';
      _currentChain = Blockchain.values.firstWhere(
        (c) => c.name == chainName,
        orElse: () => Blockchain.ethereum,
      );

      onLog?.call('Multi-chain service ready');
      onLog?.call('Supported: ETH (Ξ) and Solana (◎)');
    } catch (e) {
      _logger.severe('Initialization failed', e);
      onLog?.call('ERROR: $e');
    }
  }

  /// Connect to specific chain
  Future<bool> connectChain(Blockchain chain) async {
    if (_chainStatus[chain] == true) return true;

    onLog?.call('Connecting to ${ColdTokenPresentation.getChainDisplayName(chain)}...');

    try {
      if (chain == Blockchain.ethereum) {
        return await _connectEthereum();
      } else if (chain == Blockchain.solana) {
        return await _connectSolana();
      }
      return false;
    } catch (e) {
      onLog?.call('ERROR: Failed to connect: $e');
      return false;
    }
  }

  /// Connect to Ethereum
  Future<bool> _connectEthereum() async {
    for (String endpoint in _rpcEndpoints[Blockchain.ethereum]!) {
      try {
        _ethClient = Web3Client(endpoint, http.Client());
        final networkId = await _ethClient!.getNetworkId();
        _chainStatus[Blockchain.ethereum] = true;
        _currentChain = Blockchain.ethereum;

        onLog?.call('ETH connected: ${endpoint.substring(0, 30)}...');
        onChainStatusChanged?.call(true);

        // Save preference
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_chain', 'ethereum');

        return true;
      } catch (e) {
        onLog?.call('ETH endpoint failed: ${endpoint.substring(0, 30)}...');
        continue;
      }
    }

    onLog?.call('ERROR: All ETH endpoints failed');
    return false;
  }

  /// Connect to Solana
  Future<bool> _connectSolana() async {
    for (String endpoint in _rpcEndpoints[Blockchain.solana]!) {
      try {
        _solClient = http.Client();
        // Test connection
        final response = await _solClient!.get(Uri.parse(endpoint));
        if (response.statusCode != 200) throw Exception('HTTP ${response.statusCode}');

        _chainStatus[Blockchain.solana] = true;
        _currentChain = Blockchain.solana;

        onLog?.call('SOL connected: ${endpoint.substring(0, 30)}...');
        onChainStatusChanged?.call(true);

        // Save preference
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('last_chain', 'solana');

        return true;
      } catch (e) {
        onLog?.call('SOL endpoint failed: ${endpoint.substring(0, 30)}...');
        continue;
      }
    }

    onLog?.call('ERROR: All SOL endpoints failed');
    return false;
  }

  /// Get token balance (ETH or SOL)
  Future<Map<String, dynamic>?> getBalance({
    required String address,
    required Blockchain chain,
    String? tokenContract,
  }) async {
    if (!_chainStatus[chain]!) {
      onLog?.call('ERROR: ${ColdTokenPresentation.getChainDisplayName(chain)} not connected');
      return null;
    }

    try {
      onLog?.call('Fetching balance for ${tokenContract ?? 'Native'} on ${chain.name}...');

      if (chain == Blockchain.ethereum) {
        return await _getEthBalance(address, tokenContract);
      } else if (chain == Blockchain.solana) {
        return await _getSolBalance(address, tokenContract);
      }

      return null;
    } catch (e) {
      onLog?.call('ERROR: Balance fetch failed: $e');
      return null;
    }
  }

  /// Get ETH token balance
  Future<Map<String, dynamic>?> _getEthBalance(String address, String? contract) async {
    final ethAddress = EthereumAddress.fromHex(address);

    if (contract == null) {
      // Native ETH balance
      final balance = await _ethClient!.getBalance(ethAddress);
      final ethBalance = balance.getInWei / BigInt.from(10).pow(18);
      return {
        'balance': ethBalance.toStringAsFixed(6),
        'symbol': 'ETH',
        'decimals': 18,
        'chain': 'ethereum',
      };
    } else {
      // COLD token balance
      final tokenInfo = ColdTokenRepository.instance.getTokenByAddress(contract, Blockchain.ethereum);
      if (tokenInfo == null) {
        onLog?.call('ERRORToken not in config: $contract');
        return null;
      }

      // Load COLD contract
      final contractAddr = EthereumAddress.fromHex(contract);
      final abi = ColdTokenRepository.instance.getOfficialC0LD().symbol == 'C0LD'
          ? _getSimpleTokenAbi()
          : _getSimpleTokenAbi();

      final coldContract = DeployedContract(
        ContractAbi.fromJson(abi, tokenInfo.symbol),
        contractAddr,
      );

      // Get balance
      final balanceResult = await _ethClient!.call(
        contract: coldContract,
        function: coldContract.function('balanceOf'),
        params: [ethAddress],
      );

      final rawBalance = balanceResult[0] as BigInt;
      const decimals = 18; // Standard for most tokens

      return {
        'balance': (rawBalance / BigInt.from(10).pow(decimals)).toStringAsFixed(2),
        'symbol': tokenInfo.symbol,
        'decimals': decimals,
        'name': tokenInfo.name,
        'chain': 'ethereum',
        'interestRate': tokenInfo.interestRate,
      };
    }
  }

  /// Get SOL token balance (SPL tokens)
  Future<Map<String, dynamic>?> _getSolBalance(String address, String? mint) async {
    // SOL native balance
    if (mint == null) {
      // Call Solana RPC for native balance
      final response = await _solClient!.post(
        Uri.parse(_rpcEndpoints[Blockchain.solana]!.first),
        headers: {'Content-Type': 'application/json'},
        body: '{"jsonrpc":"2.0","id":1,"method":"getBalance","params":["$address"]}',
      );

      final data = response.body;
      const balance = 0.0; // Parse from RPC response
      return {
        'balance': balance.toString(),
        'symbol': 'SOL',
        'decimals': 9,
        'chain': 'solana',
      };
    } else {
      // SPL token balance
      return {
        'balance': '0.0',
        'symbol': 'SPL',
        'decimals': 6,
        'chain': 'solana',
        'note': 'SPL token balance requires Solana program',
      };
    }
  }

  /// Transfer tokens (ETH or SOL)
  Future<Map<String, dynamic>?> transfer({
    required String fromAddress,
    required String toAddress,
    required String amount,
    required String recipient,
    required Blockchain chain,
    String? tokenContract,
    required String privateKey,
  }) async {
    if (!_chainStatus[chain]!) {
      onLog?.call('ERROR: ${ColdTokenPresentation.getChainDisplayName(chain)} not connected');
      return null;
    }

    try {
      onLog?.call('Initiating ${tokenContract ?? 'Native'} transfer on ${chain.name}...');

      if (chain == Blockchain.ethereum) {
        return await _transferEth(
          fromAddress: fromAddress,
          toAddress: toAddress,
          amount: amount,
          tokenContract: tokenContract,
          privateKey: privateKey,
        );
      } else if (chain == Blockchain.solana) {
        onLog?.call('INFO: Solana transfers require Solana program integration');
        return null;
      }

      return null;
    } catch (e) {
      onLog?.call('ERROR: Transfer failed: $e');
      return null;
    }
  }

  /// Transfer ETH or tokens
  Future<Map<String, dynamic>?> _transferEth({
    required String fromAddress,
    required String toAddress,
    required String amount,
    String? tokenContract,
    required String privateKey,
  }) async {
    final credentials = EthPrivateKey.fromHex(privateKey);
    final fromEth = EthereumAddress.fromHex(fromAddress);
    final toEth = EthereumAddress.fromHex(toAddress);

    if (tokenContract == null) {
      // Native ETH transfer
      final amountWei = (double.parse(amount) * BigInt.from(10).pow(18).toDouble()).toInt();
      final txHash = await _ethClient!.sendTransaction(
        credentials,
        Transaction(
          to: toEth,
          value: EtherAmount.fromWei(BigInt.from(amountWei)),
        ),
        chainId: 1,
      );

      onLog?.call('ETH sent: $txHash');
      onLog?.call('View: https://etherscan.io/tx/$txHash');

      return {'success': true, 'txHash': txHash};
    } else {
      // Token transfer (COLD or other)
      final contractAddr = EthereumAddress.fromHex(tokenContract);
      final abi = _getSimpleTokenAbi();
      final contract = DeployedContract(
        ContractAbi.fromJson(abi, 'Token'),
        contractAddr,
      );

      // Get decimals
      final decimalsResult = await _ethClient!.call(
        contract: contract,
        function: contract.function('decimals'),
        params: [],
      );
      final decimals = decimalsResult[0] as int;

      // Parse amount
      final amountBigInt = BigInt.from((double.parse(amount) * BigInt.from(12).pow(decimals).toDouble()).toInt());

      // Transfer
      final txHash = await _ethClient!.sendTransaction(
        credentials,
        Transaction.callContract(
          contract: contract,
          function: contract.function('transfer'),
          parameters: [toEth, amountBigInt],
          from: fromEth,
        ),
        chainId: 1,
      );

      onLog?.call('Token transfer sent: $txHash');
      onLog?.call('View: https://etherscan.io/tx/$txHash');

      return {'success': true, 'txHash': txHash};
    }
  }

  /// Get native info for current chain
  Future<Map<String, dynamic>?> getNativeInfo() async {
    if (!_chainStatus[_currentChain]!) return null;

    try {
      if (_currentChain == Blockchain.ethereum) {
        final gas = await _ethClient!.getGasPrice();
        final gasGwei = gas.getInWei / BigInt.from(10).pow(9);
        return {
          'gas': '${gasGwei.toStringAsFixed(2)} Gwei',
          'chain': 'ethereum',
          'network': 'Mainnet',
        };
      } else if (_currentChain == Blockchain.solana) {
        return {
          'chain': 'solana',
          'network': 'Mainnet',
          'note': 'Solana fee estimation pending',
        };
      }
    } catch (e) {
      onLog?.call('ERROR: Failed to get native info: $e');
      return null;
    }
    return null;
  }

  /// Get current chain
  Blockchain get currentChain => _currentChain;

  /// Get chain status
  bool isChainConnected(Blockchain chain) => _chainStatus[chain] ?? false;

  /// Get available chains
  List<Blockchain> get availableChains {
    return _chainStatus.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  /// Switch chain
  Future<bool> switchChain(Blockchain chain) async {
    if (_currentChain == chain) return true;

    onLog?.call('Switching to ${ColdTokenPresentation.getChainDisplayName(chain)}...');

    // Disconnect current
    await disconnect();

    // Connect new
    return await connectChain(chain);
  }

  /// Disconnect all
  Future<void> disconnect() async {
    await _ethClient?.dispose();
    _solClient?.close();
    _chainStatus[Blockchain.ethereum] = false;
    _chainStatus[Blockchain.solana] = false;
    onLog?.call('Disconnected all chains');
    onChainStatusChanged?.call(false);
  }

  /// Get simple ERC20 ABI
  String _getSimpleTokenAbi() {
    return '''
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
  }

  /// Set callbacks
  void setLogCallback(Function(String) callback) => onLog = callback;
  void setChainStatusCallback(Function(bool) callback) => onChainStatusChanged = callback;
  void setBalanceCallback(Function(Map<String, dynamic>) callback) => onBalanceUpdated = callback;

  /// Dispose
  Future<void> dispose() async {
    await disconnect();
    onLog = null;
    onChainStatusChanged = null;
    onBalanceUpdated = null;
    _logger.info('MultiChainService disposed');
  }
}
EOF</parameter>
<parameter=cd>fuego-wallet</parameter>
</function>
</tool_call>
