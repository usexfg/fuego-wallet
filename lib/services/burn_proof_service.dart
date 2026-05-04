import 'dart:async';
import 'package:logging/logging.dart';
import 'cli_service.dart';
import 'prover_service.dart';

class BundledBurnProof {
  final String starkProofHash;
  final String merkleProof;
  final int burnAmount;
  final String recipientAddress;

  BundledBurnProof({
    required this.starkProofHash,
    required this.merkleProof,
    required this.burnAmount,
    required this.recipientAddress,
  });
}

class BurnProofBundler {
  static final Logger _logger = Logger('BurnProofBundler');

  static Future<BundledBurnProof> generateBundledProof({
    required String transactionHash,
    required String recipientAddress,
    required int burnAmount,
    required String commitmentIndex,
    String burnType = 'Standard Burn',
  }) async {
    try {
      _logger.info('Starting bundled proof generation...');

      // Run generation in parallel or sequentially depending on performance
      // Here sequentially for clarity and error handling
      final starkProofResult = await CLIService.generateBurnProof(
        transactionHash: transactionHash,
        recipientAddress: recipientAddress,
        burnAmount: burnAmount,
        burnType: burnType,
      );

      _logger.info('STARK proof generated.');

      final merkleProof = await ProverService.generateMerkleProof(commitmentIndex);

      _logger.info('Merkle proof generated.');

      return BundledBurnProof(
        starkProofHash: starkProofResult.proofHash,
        merkleProof: merkleProof,
        burnAmount: starkProofResult.burnAmount,
        recipientAddress: starkProofResult.recipientAddress,
      );
    } catch (e, stackTrace) {
      _logger.severe('Failed to generate bundled proof', e, stackTrace);
      rethrow;
    }
  }
}
