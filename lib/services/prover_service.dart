import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:logging/logging.dart';

class ProverService {
  static final Logger _logger = Logger('ProverService');

  static Future<String> _extractBinary() async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String binaryName = Platform.isWindows
          ? 'fuego-prover-windows.exe'
          : Platform.isMacOS
              ? 'fuego-prover-macos'
              : 'fuego-prover-linux';

      final File binaryFile = File(path.join(tempDir.path, binaryName));

      final ByteData data = await rootBundle.load('assets/bin/$binaryName');
      await binaryFile.create(recursive: true);
      await binaryFile.writeAsBytes(data.buffer.asUint8List());

      if (!Platform.isWindows) {
        await Process.run('chmod', ['+x', binaryFile.path]);
      }

      return binaryFile.path;
    } catch (e, stackTrace) {
      _logger.severe('Failed to extract prover binary', e, stackTrace);
      throw Exception('Failed to extract prover binary: $e');
    }
  }

  static Future<String> generateMerkleProof(String commitmentIndex) async {
    try {
      final String binaryPath = await _extractBinary();
      final List<String> args = ['prove-merkle', commitmentIndex];

      final ProcessResult result = await Process.run(binaryPath, args);

      if (result.exitCode == 0) {
        return result.stdout.trim();
      } else {
        throw Exception('Merkle proof generation failed: ${result.stderr}');
      }
    } catch (e) {
      _logger.severe('Merkle proof generation error: $e');
      rethrow;
    }
  }
}
