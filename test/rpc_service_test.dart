// Unit tests for FuegoRPCService

import 'package:flutter_test/flutter_test.dart';
import 'package:xfg_wallet/services/fuego_rpc_service.dart';

void main() {
  group('FuegoRPCService', () {
    test('should initialize with default remote node', () {
      final service = FuegoRPCService();
      expect(FuegoRPCService.defaultRemoteNodes.isNotEmpty, true);
      expect(FuegoRPCService.defaultRemoteNodes.first, '207.244.247.64:18180');
    });

    test('should update node correctly', () {
      final service = FuegoRPCService();

      service.updateNode('custom-node.com', port: 12345);
      expect(service.currentNodeUrl, 'http://custom-node.com:12345');
    });

    test('should use default port when not specified', () {
      final service = FuegoRPCService();
      service.updateNode('test-node.com');
      expect(service.currentNodeUrl, 'http://test-node.com:18180');
    });
  });
}
