import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web3dart/web3dart.dart';
import 'package:solana/solana.dart' as solana;
import 'package:solana/base58.dart';
import 'package:solana/encoder.dart' as solana_encoder;

class Web3MultiChainService {
  final Web3Client _ethClient;
  final solana.RpcClient _solRpcClient;

  // Default endpoints
  Web3MultiChainService({
    String ethRpcUrl = 'https://mainnet.infura.io/v3/YOUR_INFURA_KEY', // Placeholder
    String solRpcUrl = 'https://api.mainnet-beta.solana.com',
  })  : _ethClient = Web3Client(ethRpcUrl, http.Client()),
        _solRpcClient = solana.RpcClient(solRpcUrl);

  /// Retrieves the ETH balance for an Ethereum address.
  Future<double> getEthBalance(String address) async {
    try {
      final ethAddress = EthereumAddress.fromHex(address);
      final balance = await _ethClient.getBalance(ethAddress);
      // Balance is in Wei, convert to Ether
      return balance.getValueInUnit(EtherUnit.ether);
    } catch (e) {
      print('Error fetching ETH balance: $e');
      return 0.0;
    }
  }

  /// Retrieves the SOL balance for a Solana address.
  Future<double> getSolBalance(String address) async {
    try {
      final balance = await _solRpcClient.getBalance(address);
      // Balance is in Lamports, convert to SOL
      return balance.value / 1000000000.0;
    } catch (e) {
      print('Error fetching SOL balance: $e');
      return 0.0;
    }
  }

  /// Sends ETH using a private key.
  Future<String> sendEth(String privateKey, String toAddress, double amountEth) async {
    try {
      final credentials = EthPrivateKey.fromHex(privateKey);
      final receiver = EthereumAddress.fromHex(toAddress);

      // Amount to send in Wei
      final weiAmount = BigInt.from(amountEth * 1e18);

      final transaction = Transaction(
        to: receiver,
        value: EtherAmount.inWei(weiAmount),
      );

      final txHash = await _ethClient.sendTransaction(
        credentials,
        transaction,
        chainId: 1, // mainnet
      );
      return txHash;
    } catch (e) {
      throw Exception('ETH transfer failed: $e');
    }
  }

  /// Sends SOL using a base58 encoded private key.
  Future<String> sendSol(String privateKeyBase58, String toAddress, double amountSol) async {
    try {
      // Create keypair from base58 private key
      // Many wallets export 64-byte secret key in base58. The solana package usually
      // takes the byte array.
      final keyBytes = base58decode(privateKeyBase58);

      final sender = await solana.Ed25519HDKeyPair.fromPrivateKeyBytes(privateKey: keyBytes.toList());

      final lamports = (amountSol * 1000000000).toInt();

      final message = solana.Message(
        instructions: [
          solana.SystemInstruction.transfer(
            fundingAccount: sender.publicKey,
            recipientAccount: solana.Ed25519HDPublicKey.fromBase58(toAddress),
            lamports: lamports,
          ),
        ],
      );

      // We need a blockhash
      final blockhash = await _solRpcClient.getLatestBlockhash();

      final compiledMessage = message.compile(
        recentBlockhash: blockhash.value.blockhash,
        feePayer: sender.publicKey,
      );

      final signature = await sender.sign(compiledMessage.toByteArray());

      final tx = solana_encoder.SignedTx(
        signatures: [signature],
        compiledMessage: compiledMessage,
      );

      final txHash = await _solRpcClient.sendTransaction(
        tx.encode(),
        preflightCommitment: solana.Commitment.confirmed,
      );
      return txHash;
    } catch (e) {
      throw Exception('SOL transfer failed: $e');
    }
  }

  /// Simulate an atomic swap
  Future<Map<String, dynamic>> executeAtomicSwap({
    required String fromNetwork,
    required String toNetwork,
    required String fromToken,
    required String toToken,
    required double amount,
    required String userAddress,
    required String privateKey, // To actually execute, we'd need this
  }) async {
    // In a real atomic swap, we'd interact with an HTLC (Hash Time Locked Contract)
    // or a bridge protocol. Here we'll simulate the successful initiation.
    print('Initiating atomic swap from $fromNetwork ($fromToken) to $toNetwork ($toToken) for $amount');

    // Simulate delay
    await Future.delayed(const Duration(seconds: 2));

    return {
      'status': 'success',
      'txHash': '0x${DateTime.now().millisecondsSinceEpoch.toRadixString(16)}',
      'message': 'Swap initiated successfully',
    };
  }

  void dispose() {
    _ethClient.dispose();
  }
}
