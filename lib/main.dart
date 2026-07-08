import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'core/core.dart';
import 'package:logging/logging.dart';

import 'bloc/app_bloc_observer.dart';
import 'bloc/auth/auth_cubit.dart';
import 'bloc/wallet/wallet_cubit.dart';
import 'bloc/dex/dex_cubit.dart';
import 'bloc/cd/cd_cubit.dart';
import 'bloc/hearth/hearth_cubit.dart';
import 'providers/wallet_provider.dart';
import 'services/fuego_rpc_service.dart';
import 'services/fuego_daemon_client.dart' as hearth;
import 'models/network_config.dart';
import 'screens/splash_screen.dart';
import 'utils/theme.dart';

final _log = Logger('main');
Process? _backend;
final Completer<void> _backendReady = Completer<void>();

const String _defaultDaemonHost = '207.244.247.64';
const int _backendPort = 8070;

final daemon = FuegoDaemonClient(
  host: '127.0.0.1',
  port: defaultRpcPort,
  walletPort: _backendPort,
);

final rpcService = FuegoRPCService(
  host: '127.0.0.1',
  port: _backendPort,
  networkConfig: NetworkConfig.mainnet,
);

Future<void> _startBackend() async {
  final binary = _findBackendBinary();
  if (binary == null) {
    print('[backend] ERROR: fuego-wallet binary not found — falling back to remote node');
    rpcService.updateNode(
      NetworkConfig.mainnet.defaultSeedNode.split(':')[0],
      port: NetworkConfig.mainnet.daemonRpcPort,
    );
    if (!_backendReady.isCompleted) _backendReady.complete();
    return;
  }
  print('[backend] Starting: $binary');
  try {
    _backend = await Process.start(binary, [
      '--port', _backendPort.toString(),
      'serve',
      '--daemon-host', _defaultDaemonHost,
    ]);
    print('[backend] Process started (pid=${_backend!.pid})');
    _backend!.stdout.transform(utf8.decoder).listen((l) => print('[backend:stdout] $l'));
    _backend!.stderr.transform(utf8.decoder).listen((l) => print('[backend:stderr] $l'));
    _backend!.exitCode.then((code) => print('[backend] Exited with code $code'));
  } catch (e) {
    print('[backend] ERROR starting process: $e — falling back to remote node');
    rpcService.updateNode(
      NetworkConfig.mainnet.defaultSeedNode.split(':')[0],
      port: NetworkConfig.mainnet.daemonRpcPort,
    );
    if (!_backendReady.isCompleted) _backendReady.complete();
    return;
  }

  // Wait for backend to be ready
  for (var i = 0; i < 30; i++) {
    try {
      final resp = await HttpClient()
          .getUrl(Uri.parse('http://127.0.0.1:$_backendPort/health'))
          .then((r) => r.close());
      final body = await resp.transform(utf8.decoder).join();
      if (resp.statusCode == 200) {
        print('[backend] Health OK on attempt $i: $body');
        if (!_backendReady.isCompleted) _backendReady.complete();
        return;
      }
      print('[backend] Health check $i: HTTP ${resp.statusCode} — $body');
    } catch (e) {
      print('[backend] Health check $i failed: $e');
    }
    await Future.delayed(const Duration(seconds: 2));
  }
  print('[backend] ERROR: Backend did not become ready after 60s — falling back to remote');
  rpcService.updateNode(
    NetworkConfig.mainnet.defaultSeedNode.split(':')[0],
    port: NetworkConfig.mainnet.daemonRpcPort,
  );
  if (!_backendReady.isCompleted) _backendReady.complete();
}

String? _findBackendBinary() {
  final exe = File(Platform.resolvedExecutable);
  print('[main] resolvedExecutable: ${Platform.resolvedExecutable}');
  print('[main] exe.parent.path: ${exe.parent.path}');

  final projectRoot = Directory.current.path;
  final candidates = [
    // Release bundle paths
    '${exe.parent.path}/fuego-wallet',
    if (Platform.isMacOS) '${exe.parent.parent.parent.path}/Resources/bin/fuego-wallet',
    // Rust dev build outputs (relative to project root)
    '$projectRoot/rust-fuego-wallet/target/debug/fuego-wallet',
    '$projectRoot/rust-fuego-wallet/target/release/fuego-wallet',
  ];
  for (final c in candidates) {
    final exists = File(c).existsSync();
    print('[main] checking: $c exists=$exists');
    if (exists) return c;
  }
  return null;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = AppBlocObserver();

  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(FuegoApp(backendReady: _backendReady.future));

  _startBackend();
}

class FuegoApp extends StatelessWidget {
  final Future<void> backendReady;
  const FuegoApp({super.key, required this.backendReady});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final wp = WalletProvider(rpcService: rpcService);
            wp.waitForBackend(backendReady);
            return wp;
          },
        ),
      ],
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FuegoDaemonClient>.value(value: daemon),
          RepositoryProvider<FuegoRPCService>.value(value: rpcService),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>(
              create: (_) => AuthCubit()..initialize(),
            ),
            BlocProvider<WalletCubit>(
              create: (_) => WalletCubit(daemon, backendReady: backendReady),
            ),
            BlocProvider<CdCubit>(
              create: (_) => CdCubit(rpcService)..loadAll(),
            ),
            BlocProvider<HearthCubit>(
              create: (_) => HearthCubit(hearth.FuegoDaemonClient(host: '127.0.0.1')),
            ),
            BlocProvider<DexCubit>(
              create: (_) => DexCubit()..init(),
            ),
          ],
          child: MaterialApp(
            title: 'Fuego',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.dark,
            home: const SplashScreen(),
            debugShowCheckedModeBanner: false,
          ),
        ),
      ),
    );
  }
}
