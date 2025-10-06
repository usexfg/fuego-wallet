import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class CLIService {
  static const String _cliBinaryName = 'xfg-stark-cli';
  static String? _cliPath;

  /// Get the path to the xfg-stark-cli binary
  static Future<String> getCLIPath() async {
    if (_cliPath != null) return _cliPath!;

    try {
      // Get the application documents directory
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String cliDir = path.join(appDir.path, 'bin');
      
      // Create bin directory if it doesn't exist
      await Directory(cliDir).create(recursive: true);
      
      // Determine the correct binary name for the platform
      String binaryName = _getBinaryNameForPlatform();
      final String cliPath = path.join(cliDir, binaryName);
      
      // Check if binary already exists
      if (await File(cliPath).exists()) {
        _cliPath = cliPath;
        return cliPath;
      }
      
      // Extract binary from assets
      await _extractBinaryFromAssets(binaryName, cliPath);
      
      // Make binary executable on Unix systems
      if (Platform.isLinux || Platform.isMacOS) {
        await Process.run('chmod', ['+x', cliPath]);
      }
      
      _cliPath = cliPath;
      return cliPath;
    } catch (e) {
      throw Exception('Failed to setup CLI binary: $e');
    }
  }

  /// Extract the CLI binary from assets to the filesystem
  static Future<void> _extractBinaryFromAssets(String binaryName, String targetPath) async {
    try {
      // Load the binary from assets
      final ByteData data = await rootBundle.load('assets/bin/$binaryName');
      
      // Write to target path
      final File file = File(targetPath);
      await file.writeAsBytes(data.buffer.asUint8List());
    } catch (e) {
      throw Exception('Failed to extract CLI binary: $e');
    }
  }

  /// Get the correct binary name for the current platform
  static String _getBinaryNameForPlatform() {
    if (Platform.isWindows) {
      return 'xfg-stark-cli.exe';
    } else if (Platform.isMacOS) {
      return 'xfg-stark-cli-macos';
    } else if (Platform.isLinux) {
      return 'xfg-stark-cli-linux';
    } else {
      throw UnsupportedError('Unsupported platform: ${Platform.operatingSystem}');
    }
  }

  /// Execute the CLI with the given arguments
  static Future<ProcessResult> executeCLI(List<String> arguments) async {
    final String cliPath = await getCLIPath();
    
    try {
      final ProcessResult result = await Process.run(cliPath, arguments);
      return result;
    } catch (e) {
      throw Exception('Failed to execute CLI: $e');
    }
  }

  /// Generate STARK proof for XFG burn
  static Future<Map<String, dynamic>> generateBurnProof({
    required String privateKey,
    required double burnAmount,
    required String recipientAddress,
  }) async {
    try {
      final List<String> args = [
        'burn-proof',
        '--private-key', privateKey,
        '--amount', burnAmount.toString(),
        '--recipient', recipientAddress,
      ];
      
      final ProcessResult result = await executeCLI(args);
      
      if (result.exitCode != 0) {
        throw Exception('CLI execution failed: ${result.stderr}');
      }
      
      // Parse the JSON output
      final String output = result.stdout.toString();
      return {
        'success': true,
        'proof': output,
        'transactionHash': '', // Will be filled by the CLI output
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Verify STARK proof
  static Future<bool> verifyProof(String proof) async {
    try {
      final List<String> args = ['verify-proof', '--proof', proof];
      final ProcessResult result = await executeCLI(args);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}
