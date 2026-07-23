import 'package:flutter_test/flutter_test.dart';
import 'package:fuego/services/security_service.dart';

void main() {
  test('BIP39 + vault seed path is wired (no placeholder crypto)', () {
    final mnemonic = SecurityService.generateMnemonic(strength: 128);
    expect(SecurityService.validateMnemonic(mnemonic), isTrue);
    final seed = SecurityService.mnemonicToVaultSeed(mnemonic);
    expect(seed.length, 32);
    // Ensure we never produce the old DateTime-based fake word list pattern
    expect(mnemonic.contains('actress'), isFalse);
  });
}
