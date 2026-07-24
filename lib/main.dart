import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:provider/provider.dart';

import 'bloc/app_bloc_observer.dart';
import 'bloc/auth/auth_cubit.dart';
import 'bloc/cd/cd_cubit.dart';
import 'bloc/dex/dex_cubit.dart';
import 'bloc/hearth/hearth_cubit.dart';
import 'bloc/mining/mining_cubit.dart';
import 'bloc/wallet/wallet_cubit.dart';
import 'core/core.dart';
import 'models/network_config.dart';
import 'providers/wallet_provider.dart';
import 'screens/splash_screen.dart';
import 'services/fuego_daemon_client.dart' as hearth;
import 'services/fuego_rpc_service.dart';
import 'services/fuego_vault_service.dart';
import 'services/security_service.dart';
import 'utils/theme.dart';

final _log = Logger('main');
Process? _backend;
final Completer<void> _backendReady = Completer<void>();
final SecurityService _securityService = SecurityService();
final FuegoVaultService _vaultService =
    FuegoVaultService(security: _securityService);

bool get _useTestnet =>
    Platform.environment['FUEGO_TESTNET'] == '1' ||
    Platform.environment['FUEGO_TESTNET'] == 'true';

NetworkConfig get _activeConfig =>
    _useTestnet ? NetworkConfig.testnet : NetworkConfig.mainnet;

String get _defaultDaemonHost =>
    Platform.environment['FUEGO_DAEMON_HOST'] ??
    _activeConfig.defaultSeedNode.split(':')[0];

int get _defaultDaemonPort =>
    int.tryParse(Platform.environment['FUEGO_DAEMON_PORT'] ?? '') ??
    _activeConfig.daemonRpcPort;

const int _backendPort = 8070;

late final FuegoDaemonClient daemon = FuegoDaemonClient(
  host: _defaultDaemonHost,
  port: _defaultDaemonPort,
  walletPort: _backendPort,
);

late final FuegoRPCService rpcService = FuegoRPCService(
  host: '127.0.0.1',
  port: _backendPort,
  networkConfig: _activeConfig,
);

void _logDebug(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

Future<void> _startBackend() async {
  final binary = _findBackendBinary();
  if (binary == null) {
    _log.warning('fuego-walletd binary not found — using remote node for public RPC only');
    rpcService.updateNode(
      _defaultDaemonHost,
      port: _defaultDaemonPort,
    );
    if (!_backendReady.isCompleted) _backendReady.complete();
    return;
  }
  _logDebug('[backend] Starting local backend');
  try {
    final args = [
      '--port',
      _backendPort.toString(),
      'serve',
      '--daemon-host',
      _defaultDaemonHost,
      '--daemon-port',
      _defaultDaemonPort.toString(),
    ];
    if (_useTestnet) args.add('--testnet');
    _backend = await Process.start(binary, args);
    if (kDebugMode) {
      _backend!.stdout
          .transform(utf8.decoder)
          .listen((l) => debugPrint('[backend:stdout] $l'));
      _backend!.stderr
          .transform(utf8.decoder)
          .listen((l) => debugPrint('[backend:stderr] $l'));
    } else {
      // Drain streams so the process does not block
      _backend!.stdout.drain<void>();
      _backend!.stderr.drain<void>();
    }
    _backend!.exitCode.then((code) {
      _logDebug('[backend] Exited with code $code');
    });
  } catch (e) {
    _log.warning('Failed to start backend process');
    rpcService.updateNode(
      _defaultDaemonHost,
      port: _defaultDaemonPort,
    );
    if (!_backendReady.isCompleted) _backendReady.complete();
    return;
  }

  for (var i = 0; i < 120; i++) {
    try {
      final client = HttpClient();
      final req = await client.getUrl(
        Uri.parse('http://127.0.0.1:$_backendPort/health'),
      );
      final resp = await req.close();
      await resp.drain<void>();
      client.close(force: true);
      if (resp.statusCode == 200) {
        if (!_backendReady.isCompleted) _backendReady.complete();
        return;
      }
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 1));
  }
  _log.warning('Backend did not become ready after 120s');
  if (!_backendReady.isCompleted) _backendReady.complete();
}

Future<void> stopBackend() async {
  final p = _backend;
  _backend = null;
  if (p == null) return;
  try {
    p.kill(ProcessSignal.sigterm);
    await p.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        p.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
  } catch (_) {}
}

String? _findBackendBinary() {
  final exe = File(Platform.resolvedExecutable);
  final projectRoot = Directory.current.path;
  final candidates = [
    '${exe.parent.path}/fuego-walletd',
    if (Platform.isMacOS)
      '${exe.parent.parent.parent.path}/Resources/bin/fuego-walletd',
    '$projectRoot/rust-fuego-wallet/target/debug/fuego-walletd',
    '$projectRoot/rust-fuego-wallet/target/release/fuego-walletd',
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  return null;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Bloc.observer = AppBlocObserver();

  Logger.root.level = kReleaseMode ? Level.WARNING : Level.INFO;
  Logger.root.onRecord.listen((record) {
    if (kReleaseMode && record.level < Level.WARNING) return;
    // Never log secrets — callers must not put keys in log messages
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Probe vault existence only — do not decrypt or generate secrets
  try {
    await _vaultService.init();
  } catch (e) {
    _log.warning('Vault probe failed (non-fatal)');
  }

  runApp(FuegoApp(
    backendReady: _backendReady.future,
    vaultService: _vaultService,
    securityService: _securityService,
  ));

  _startBackend();
}

class FuegoApp extends StatefulWidget {
  final Future<void> backendReady;
  final FuegoVaultService vaultService;
  final SecurityService securityService;

  const FuegoApp({
    super.key,
    required this.backendReady,
    required this.vaultService,
    required this.securityService,
  });

  @override
  State<FuegoApp> createState() => _FuegoAppState();
}

class _FuegoAppState extends State<FuegoApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(stopBackend());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      unawaited(stopBackend());
    }
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final wp = WalletProvider(
              rpcService: rpcService,
              securityService: widget.securityService,
              vault: widget.vaultService,
            );
            wp.waitForBackend(widget.backendReady);
            return wp;
          },
        ),
      ],
      child: MultiRepositoryProvider(
        providers: [
          RepositoryProvider<FuegoDaemonClient>.value(value: daemon),
          RepositoryProvider<FuegoRPCService>.value(value: rpcService),
          RepositoryProvider<FuegoVaultService>.value(
            value: widget.vaultService,
          ),
          RepositoryProvider<SecurityService>.value(
            value: widget.securityService,
          ),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>(
              create: (_) => AuthCubit()..initialize(),
            ),
            BlocProvider<WalletCubit>(
              create: (_) => WalletCubit(
                daemon,
                vault: widget.vaultService,
                backendReady: widget.backendReady,
                security: widget.securityService,
              ),
            ),
            BlocProvider<CdCubit>(
              create: (_) =>
                  CdCubit(rpcService, backendReady: widget.backendReady),
            ),
            BlocProvider<HearthCubit>(
              create: (_) => HearthCubit(hearth.FuegoDaemonClient(
                host: _defaultDaemonHost,
                networkConfig: _activeConfig,
              )),
            ),
            BlocProvider<DexCubit>(
              create: (_) => DexCubit()..init(),
            ),
            BlocProvider<MiningCubit>(
              create: (_) => MiningCubit(),
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
