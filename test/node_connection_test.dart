import 'package:flutter_test/flutter_test.dart';
import 'package:fuego/models/network_config.dart';
import 'package:fuego/services/daemon_manager.dart';
import 'package:fuego/services/fuego_rpc_service.dart';
import 'package:fuego/services/node_connection.dart';

void main() {
  group('NodeConnection platform defaults', () {
    test('platformDefaultMode is local on desktop OSes', () {
      // CI and dev machines running these tests are desktop.
      // Mobile defaults are covered by isMobile/isDesktop flags.
      if (NodeConnection.isDesktop) {
        expect(NodeConnection.platformDefaultMode(), ConnectionMode.local);
      }
      if (NodeConnection.isMobile) {
        expect(NodeConnection.platformDefaultMode(), ConnectionMode.remote);
      }
    });

    test('useLocalNode tracks mode', () {
      final dm = DaemonManager(config: NetworkConfig.mainnet);
      final rpc = FuegoRPCService(networkConfig: NetworkConfig.mainnet);
      final nc = NodeConnection(
        daemonManager: dm,
        rpcService: rpc,
        networkConfig: NetworkConfig.mainnet,
        mode: ConnectionMode.local,
      );
      expect(nc.useLocalNode, isTrue);

      final remote = NodeConnection(
        daemonManager: dm,
        rpcService: rpc,
        networkConfig: NetworkConfig.mainnet,
        mode: ConnectionMode.remote,
        remoteHost: 'node1.usexfg.org',
        remotePort: 18180,
      );
      expect(remote.useLocalNode, isFalse);
      expect(remote.remoteHost, 'node1.usexfg.org');
      expect(remote.remotePort, 18180);
    });

    test('ConnectionEndpoints walletBaseUrl format', () {
      const ep = ConnectionEndpoints(
        mode: ConnectionMode.local,
        walletHost: '127.0.0.1',
        walletPort: 18189,
        chainHost: '127.0.0.1',
        chainPort: 18180,
        proxyRunning: true,
      );
      expect(ep.walletBaseUrl, 'http://127.0.0.1:18189');
      expect(ep.chainBaseUrl, 'http://127.0.0.1:18180');
      expect(ep.ok, isTrue);
    });
  });
}
