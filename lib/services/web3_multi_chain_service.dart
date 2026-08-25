import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:solana/solana.dart' as solana;
import 'package:solana/base58.dart';
import 'package:solana/encoder.dart' as solana_encoder;
import '../models/erc20_token.dart';
import 'erc20_service.dart';

class Web3MultiChainService {
  Web3Client? _ethClient;
  solana.RpcClient? _solRpcClient;
  String _ethRpcUrl;
  String _solRpcUrl;

  // Per-chain EVM clients — fixes single-client bug where getEvmBalance(chain:'poly')
  // still queried ETH mainnet. Keys: eth/arb/base/bsc/poly.
  final Map<String, Web3Client> _evmClients = {};
  final Map<String, String> _evmRpcUrls = {};
  Erc20Service? _erc20;
  Erc20Service get erc20 {
    _erc20 ??= Erc20Service(rpcUrls: Map<String, String>.from(_evmRpcUrls));
    return _erc20!;
  }

  static const defaultEthRpc = 'https://eth.llamarpc.com';
  static const defaultArbRpc = 'https://arb1.arbitrum.io/rpc';
  static const defaultBaseRpc = 'https://mainnet.base.org';
  static const defaultBscRpc = 'https://bsc-dataseed.binance.org';
  static const defaultPolyRpc = 'https://polygon-rpc.com';
  static const defaultSolRpc = 'https://api.mainnet-beta.solana.com';

  static const chainIds = {
    'eth': 1, 'arb': 42161, 'base': 8453, 'bsc': 56, 'poly': 137,
    'op': 10, 'avax': 43114, 'cro': 25, 'monad': 143, 'xpl': 9745,
    'pls': 369, 'uni': 130, 'rh': 4663, 'bob': 60808, 'gleec': 11169,
    'linea': 59144, 'zksync': 324,
    'hyperevm': 999, 'ink': 57073, 'rsk': 30, 'gnosis': 100,
    'flare': 14, 'kaia': 8217, 'scroll': 534352, 'abstract': 2741,
    'plume': 98866,
    'soneium': 1868, 'doma': 97477, 'beam': 4337, 'moonriver': 1285,
    'peaq': 3338, 'tempo': 4217, 'sei': 1329,
  };

  static const _defaultEvmRpcs = {
    'eth': defaultEthRpc,
    'arb': defaultArbRpc,
    'base': defaultBaseRpc,
    'bsc': defaultBscRpc,
    'poly': defaultPolyRpc,
    'op': 'https://mainnet.optimism.io',
    'avax': 'https://api.avax.network/ext/bc/C/rpc',
    'cro': 'https://evm.cronos.org',
    'monad': 'https://rpc.monad.xyz',
    'xpl': 'https://rpc.plasma.to',
    'pls': 'https://rpc.pulsechain.com',
    'uni': 'https://mainnet.unichain.org',
    'rh': 'https://rpc.mainnet.chain.robinhood.com',
    'bob': 'https://rpc.nodeflare.app/bob/public',
    'gleec': 'https://evm-rpc.gleec.com',
    'linea': 'https://rpc.linea.build',
    'zksync': 'https://mainnet.era.zksync.io',
    'hyperevm': 'https://rpc.hyperliquid.xyz/evm',
    'ink': 'https://rpc-gel.inkonchain.com',
    'rsk': 'https://public-node.rsk.co',
    'gnosis': 'https://rpc.gnosischain.com',
    'flare': 'https://flare-api.flare.network/ext/C-rpc',
    'kaia': 'https://public-en.node.kaia.io',
    'scroll': 'https://rpc.scroll.io',
    'abstract': 'https://rpc.abstract.xyz',
    'plume': 'https://rpc.plume.org',
    'soneium': 'https://rpc.soneium.org',
    'doma': 'https://rpc.doma.xyz',
    'beam': 'https://build.onbeam.com/rpc',
    'moonriver': 'https://rpc.api.moonriver.moonbeam.network',
    'peaq': 'https://peaq.api.onfinality.io/public',
    'tempo': 'https://rpc.tempo.xyz',
    'sei': 'https://evm-rpc.sei-apis.com',
  };

  Web3MultiChainService({String ethRpcUrl = '', String solRpcUrl = ''})
      : _ethRpcUrl = ethRpcUrl.isEmpty ? defaultEthRpc : ethRpcUrl,
        _solRpcUrl = solRpcUrl.isEmpty ? defaultSolRpc : solRpcUrl {
    _ethClient = Web3Client(_ethRpcUrl, http.Client());
    _solRpcClient = solana.RpcClient(_solRpcUrl);
    for (final e in _defaultEvmRpcs.entries) {
      final url = e.key == 'eth' ? _ethRpcUrl : e.value;
      _evmRpcUrls[e.key] = url;
      _evmClients[e.key] = e.key == 'eth' ? _ethClient! : Web3Client(url, http.Client());
    }
    _erc20 = Erc20Service(rpcUrls: Map<String, String>.from(_evmRpcUrls));
  }

  Web3Client _evmClientFor(String chain) {
    final k = chain.toLowerCase();
    return _evmClients[k] ?? _ethClient!;
  }

  void setEthRpc(String rpcUrl) {
    _ethRpcUrl = rpcUrl.isEmpty ? defaultEthRpc : rpcUrl;
    _ethClient?.dispose();
    _ethClient = Web3Client(_ethRpcUrl, http.Client());
    // Keep per-chain map in sync — eth key is canonical for ETH mainnet
    _evmClients['eth']?.dispose();
    _evmClients['eth'] = _ethClient!;
    _evmRpcUrls['eth'] = _ethRpcUrl;
    _erc20?.setRpcUrl('eth', _ethRpcUrl);
  }

  /// Set RPC for a specific EVM chain (eth/arb/base/bsc/poly). Falls back to
  /// [setEthRpc] when chain == 'eth' for backward compat.
  void setEvmRpc(String chain, String rpcUrl) {
    final k = chain.toLowerCase();
    if (k == 'eth') {
      setEthRpc(rpcUrl);
      return;
    }
    final defaults = _defaultEvmRpcs[k];
    final url = rpcUrl.isEmpty ? (defaults ?? rpcUrl) : rpcUrl;
    if (url.isEmpty) return;
    _evmClients[k]?.dispose();
    _evmRpcUrls[k] = url;
    _evmClients[k] = Web3Client(url, http.Client());
    _erc20?.setRpcUrl(k, url);
  }

  void setSolRpc(String rpcUrl) {
    _solRpcUrl = rpcUrl.isEmpty ? defaultSolRpc : rpcUrl;
    _solRpcClient = solana.RpcClient(_solRpcUrl);
  }

  int getChainId(String chain) => chainIds[chain.toLowerCase()] ?? 1;

  Future<double> getEthBalance(String address) async {
    try {
      final balance = await _evmClientFor('eth').getBalance(EthereumAddress.fromHex(address));
      return balance.getValueInUnit(EtherUnit.ether);
    } catch (e) {
      dev.log('Error fetching ETH balance: $e');
      return 0.0;
    }
  }

  Future<double> getEvmBalance(String address, {String chain = 'eth'}) async {
    // Tempo has no native gas token — eth_getBalance returns a constant fake
    // (0x9612...26c9). Report 0 and use TIP-20 balances via Erc20Service instead.
    if (chain.toLowerCase() == 'tempo') {
      dev.log('Tempo has no native balance — use TIP-20 token balances');
      return 0.0;
    }
    try {
      final client = _evmClientFor(chain);
      final balance = await client.getBalance(EthereumAddress.fromHex(address));
      return balance.getValueInUnit(EtherUnit.ether);
    } catch (e) {
      dev.log('Error fetching $chain balance: $e');
      return 0.0;
    }
  }

  // ── ERC20 delegation (USDT/USDC via Erc20Service) ──────────────────

  Future<BigInt> getErc20Balance({
    required String holderAddress,
    required String tokenAddress,
    String chain = 'eth',
  }) =>
      erc20.balanceOf(chainKey: chain, tokenAddress: tokenAddress, holderAddress: holderAddress);

  Future<double> getErc20BalanceAsDouble({
    required String holderAddress,
    required Erc20Token token,
  }) =>
      erc20.balanceAsDouble(token: token, holderAddress: holderAddress);

  Future<int> getErc20Decimals({required String tokenAddress, String chain = 'eth'}) =>
      erc20.decimals(chainKey: chain, tokenAddress: tokenAddress);

  Future<BigInt> getErc20Allowance({
    required String owner,
    required String spender,
    required String tokenAddress,
    String chain = 'eth',
  }) =>
      erc20.allowance(chainKey: chain, tokenAddress: tokenAddress, owner: owner, spender: spender);

  Future<String> sendErc20({
    required String privateKey,
    required String tokenAddress,
    required String toAddress,
    required BigInt amountBaseUnits,
    String chain = 'eth',
  }) =>
      erc20.transfer(
        chainKey: chain,
        privateKey: privateKey,
        tokenAddress: tokenAddress,
        toAddress: toAddress,
        amountBaseUnits: amountBaseUnits,
      );

  Future<String> sendErc20Token({
    required String privateKey,
    required Erc20Token token,
    required String toAddress,
    required String amountDisplay,
  }) =>
      erc20.transferToken(
        token: token,
        privateKey: privateKey,
        toAddress: toAddress,
        amountDisplay: amountDisplay,
      );

  Future<String> approveErc20({
    required String privateKey,
    required String tokenAddress,
    required String spender,
    required BigInt amountBaseUnits,
    String chain = 'eth',
  }) =>
      erc20.approve(
        chainKey: chain,
        privateKey: privateKey,
        tokenAddress: tokenAddress,
        spender: spender,
        amountBaseUnits: amountBaseUnits,
      );

  Future<double> getSolBalance(String address) async {
    try {
      final balance = await _solRpcClient!.getBalance(address);
      return balance.value / 1000000000.0;
    } catch (e) {
      dev.log('Error fetching SOL balance: $e');
      return 0.0;
    }
  }

  Future<double> getBalance(String address, String chain) async {
    final k = chain.toLowerCase();
    if (k == 'sol') return getSolBalance(address);
    if (EvmChainKey.values.any((e) => e.key == k)) {
      return getEvmBalance(address, chain: k);
    }
    return 0.0;
  }

  Future<String> sendEth(String privateKey, String toAddress, double amount, {String chain = 'eth'}) async {
    try {
      final credentials = EthPrivateKey.fromHex(privateKey);
      final receiver = EthereumAddress.fromHex(toAddress);
      final weiAmount = BigInt.from(amount * 1e18);
      final txHash = await _evmClientFor(chain).sendTransaction(
        credentials,
        Transaction(to: receiver, value: EtherAmount.inWei(weiAmount)),
        chainId: getChainId(chain),
      );
      return txHash;
    } catch (e) {
      throw Exception('$chain transfer failed: $e');
    }
  }

  Future<String> lockHtlc({
    required String privateKey, required String htlcAddress,
    required String hashlock, required int timelock,
    required double amount, String chain = 'eth',
  }) async {
    try {
      final credentials = EthPrivateKey.fromHex(privateKey);
      final receiver = EthereumAddress.fromHex(htlcAddress);
      final weiAmount = BigInt.from(amount * 1e18);
      final txHash = await _evmClientFor(chain).sendTransaction(
        credentials,
        Transaction(
          to: receiver,
          value: EtherAmount.inWei(weiAmount),
          data: Uint8List.fromList(_encodeLockCall(hashlock, timelock)),
        ),
        chainId: getChainId(chain),
      );
      return txHash;
    } catch (e) {
      throw Exception('$chain HTLC lock failed: $e');
    }
  }

  Future<String> claimHtlc({
    required String privateKey, required String htlcAddress,
    required String preimage, String chain = 'eth',
  }) async {
    try {
      final credentials = EthPrivateKey.fromHex(privateKey);
      final txHash = await _evmClientFor(chain).sendTransaction(
        credentials,
        Transaction(
          to: EthereumAddress.fromHex(htlcAddress),
          data: Uint8List.fromList(_encodeClaimCall(preimage)),
        ),
        chainId: getChainId(chain),
      );
      return txHash;
    } catch (e) {
      throw Exception('$chain HTLC claim failed: $e');
    }
  }

  Future<String> refundHtlc({
    required String privateKey, required String htlcAddress, String chain = 'eth',
  }) async {
    try {
      final credentials = EthPrivateKey.fromHex(privateKey);
      final txHash = await _evmClientFor(chain).sendTransaction(
        credentials,
        Transaction(
          to: EthereumAddress.fromHex(htlcAddress),
          data: Uint8List.fromList(_encodeRefundCall()),
        ),
        chainId: getChainId(chain),
      );
      return txHash;
    } catch (e) {
      throw Exception('$chain HTLC refund failed: $e');
    }
  }

  Future<String> sendSol(String privateKeyBase58, String toAddress, double amountSol) async {
    try {
      final keyBytes = base58decode(privateKeyBase58);
      final sender = await solana.Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: keyBytes.toList());
      final lamports = (amountSol * 1000000000).toInt();
      final message = solana.Message(instructions: [
        solana.SystemInstruction.transfer(
          fundingAccount: sender.publicKey,
          recipientAccount: solana.Ed25519HDPublicKey.fromBase58(toAddress),
          lamports: lamports,
        ),
      ]);
      final blockhash = await _solRpcClient!.getLatestBlockhash();
      final compiledMessage = message.compile(recentBlockhash: blockhash.value.blockhash, feePayer: sender.publicKey);
      final signature = await sender.sign(compiledMessage.toByteArray());
      final tx = solana_encoder.SignedTx(signatures: [signature], compiledMessage: compiledMessage);
      return await _solRpcClient!.sendTransaction(tx.encode(), preflightCommitment: solana.Commitment.confirmed);
    } catch (e) {
      throw Exception('SOL transfer failed: $e');
    }
  }

  static List<int> _encodeLockCall(String hashlock, int timelock) {
    final data = <int>[];
    data.addAll([0xb0, 0x6c, 0x95, 0x5c]);
    data.addAll(_pad32Bytes(_hexToBytes(hashlock)));
    data.addAll(_pad32BigInt(BigInt.from(timelock)));
    return data;
  }

  static List<int> _encodeClaimCall(String preimage) {
    final data = <int>[];
    data.addAll([0x43, 0x7e, 0x29, 0x20]);
    data.addAll(_pad32Bytes(_hexToBytes(preimage)));
    return data;
  }

  static List<int> _encodeRefundCall() => [0x2e, 0x1a, 0x4d, 0x40];

  static List<int> _pad32BigInt(BigInt value) => _hexToBytes(value.toRadixString(16).padLeft(64, '0'));
  static List<int> _pad32Bytes(List<int> bytes) => bytes.length >= 32 ? bytes.sublist(0, 32) : List<int>.filled(32 - bytes.length, 0) + bytes;

  static List<int> _hexToBytes(String hex) {
    final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
    final bytes = <int>[];
    for (var i = 0; i < clean.length; i += 2) {
      bytes.add(int.parse(clean.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  void dispose() {
    _ethClient?.dispose();
    for (final c in _evmClients.values) {
      if (c != _ethClient) c.dispose();
    }
    _evmClients.clear();
    _erc20?.dispose();
  }

  /// Derive EIP-55 checksummed address from a 64-hex private key. Returns '' on failure.
  static String deriveAddressFromPrivateKey(String privateKey) {
    try {
      final clean = privateKey.startsWith('0x') ? privateKey.substring(2) : privateKey;
      if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(clean)) return '';
      final creds = EthPrivateKey.fromHex(clean);
      return creds.address.hexEip55;
    } catch (_) {
      return '';
    }
  }
}
