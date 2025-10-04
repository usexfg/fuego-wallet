// Unit tests for FuegoRPCService

import 'package:flutter_test/flutter_test.dart';
import 'package:fuego_wallet/services/fuego_rpc_service.dart';

void main() {
  group('FuegoRPCService', () {
    test('should initialize with default remote node', () {
      final service = FuegoRPCService();
      expect(service.defaultRemoteNodes.isNotEmpty, true);
      expect(service.defaultRemoteNodes.first, 'node1.usexfg.org');
    });

    test('should update node correctly', () {
      final service = FuegoRPCService();
      final initialUrl = service.currentNodeUrl;

      service.updateNode('custom-node.com', port: 12345);
      expect(service.currentNodeUrl, 'http://custom-node.com:12345');
      expect(service.currentNodeUrl, isNot(equals(initialUrl)));
    });

    test('should use default port when not specified', () {
      final service = FuegoRPCService();
      service.updateNode('test-node.com');
      expect(service.currentNodeUrl, 'http://test-node.com:28180');
    });
  });
}
