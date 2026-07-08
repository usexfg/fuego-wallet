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

final daemon = FuegoDaemonClient(
  host: '127.0.0.1',
  port: defaultRpcPort,
  walletPort: 8070,
);

final rpcService = FuegoRPCService(
  host: '127.0.0.1',
  port: 18180,
  networkConfig: NetworkConfig.mainnet,
);

Future<void> _startBackend() async {
  final binary = _findBackendBinary();
  if (binary == null) {
    _log.warning('fuego-wallet binary not found — running without backend');
    return;
  }
  _log.info('Starting backend: $binary');
  _backend = await Process.start(binary, ['serve', '--daemon-host', '127.0.0.1']);
  _backend!.stdout.transform(utf8.decoder).listen((l) => _log.fine('[backend] $l'));
  _backend!.stderr.transform(utf8.decoder).listen((l) => _log.warning('[backend] $l'));

  // Wait for backend to be ready
  for (var i = 0; i < 30; i++) {
    try {
      final resp = await HttpClient()
          .getUrl(Uri.parse('http://127.0.0.1:8070/health'))
          .then((r) => r.close());
      if (resp.statusCode == 200) {
        _log.info('Backend ready');
        return;
      }
    } catch (_) {}
    await Future.delayed(const Duration(seconds: 2));
  }
  _log.warning('Backend did not become ready');
}

String? _findBackendBinary() {
  final exe = File(Platform.resolvedExecutable);
  final candidates = [
    '${exe.parent.path}/fuego-wallet',
    if (Platform.isMacOS) '${exe.parent.parent.parent.path}/Resources/bin/fuego-wallet',
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
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

  runApp(const FuegoApp());

  _startBackend();
}

class FuegoApp extends StatelessWidget {
  const FuegoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => WalletProvider(rpcService: rpcService),
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
              create: (_) => WalletCubit(daemon),
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
