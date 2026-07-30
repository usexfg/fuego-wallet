import 'dart:developer' as dev;
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:solana/solana.dart' as solana;
import 'package:solana/base58.dart';
import 'package:solana/encoder.dart' as solana_encoder;

class Web3MultiChainService {
  Web3Client? _ethClient;
  solana.RpcClient? _solRpcClient;
  String _ethRpcUrl;
  String _solRpcUrl;

  static const defaultEthRpc = 'https://eth.llamarpc.com';
  static const defaultArbRpc = 'https://arb1.arbitrum.io/rpc';
  static const defaultBaseRpc = 'https://mainnet.base.org';
  static const defaultBscRpc = 'https://bsc-dataseed.binance.org';
  static const defaultPolyRpc = 'https://polygon-rpc.com';
  static const defaultSolRpc = 'https://api.mainnet-beta.solana.com';

  static const chainIds = {'eth': 1, 'arb': 42161, 'base': 8453, 'bsc': 56, 'poly': 137};

  Web3MultiChainService({String ethRpcUrl = '', String solRpcUrl = ''})
      : _ethRpcUrl = ethRpcUrl.isEmpty ? defaultEthRpc : ethRpcUrl,
        _solRpcUrl = solRpcUrl.isEmpty ? defaultSolRpc : solRpcUrl {
    _ethClient = Web3Client(_ethRpcUrl, http.Client());
    _solRpcClient = solana.RpcClient(_solRpcUrl);
  }

  void setEthRpc(String rpcUrl) {
    _ethRpcUrl = rpcUrl.isEmpty ? defaultEthRpc : rpcUrl;
    _ethClient?.dispose();
    _ethClient = Web3Client(_ethRpcUrl, http.Client());
  }

  void setSolRpc(String rpcUrl) {
    _solRpcUrl = rpcUrl.isEmpty ? defaultSolRpc : rpcUrl;
    _solRpcClient = solana.RpcClient(_solRpcUrl);
  }

  int getChainId(String chain) => chainIds[chain] ?? 1;

  Future<double> getEthBalance(String address) async {
    try {
      final balance = await _ethClient!.getBalance(EthereumAddress.fromHex(address));
      return balance.getValueInUnit(EtherUnit.ether);
    } catch (e) {
      dev.log('Error fetching ETH balance: $e');
      return 0.0;
    }
  }

  Future<double> getEvmBalance(String address, {String chain = 'eth'}) async {
    try {
      final balance = await _ethClient!.getBalance(EthereumAddress.fromHex(address));
      return balance.getValueInUnit(EtherUnit.ether);
    } catch (e) {
      dev.log('Error fetching $chain balance: $e');
      return 0.0;
    }
  }

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
    switch (chain.toLowerCase()) {
      case 'eth': case 'arb': case 'base': case 'bsc': case 'poly':
        return getEvmBalance(address, chain: chain);
      case 'sol':
        return getSolBalance(address);
      default:
        return 0.0;
    }
  }

  Future<String> sendEth(String privateKey, String toAddress, double amount, {String chain = 'eth'}) async {
    try {
      final credentials = EthPrivateKey.fromHex(privateKey);
      final receiver = EthereumAddress.fromHex(toAddress);
      final weiAmount = BigInt.from(amount * 1e18);
      final txHash = await _ethClient!.sendTransaction(
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
      final txHash = await _ethClient!.sendTransaction(
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
      final txHash = await _ethClient!.sendTransaction(
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
      final txHash = await _ethClient!.sendTransaction(
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

  void dispose() => _ethClient?.dispose();
}
