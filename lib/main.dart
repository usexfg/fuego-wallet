import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import '../core/core.dart';
import 'package:logging/logging.dart';

import 'bloc/app_bloc_observer.dart';
import 'bloc/auth/auth_cubit.dart';
import 'bloc/wallet/wallet_cubit.dart';
import 'bloc/dex/dex_cubit.dart';
import 'bloc/cd/cd_cubit.dart';
import 'bloc/hearth/hearth_cubit.dart';
import 'providers/wallet_provider.dart';
import 'services/fuego_rpc_service.dart';
import 'services/walletd_service.dart';
import 'services/fuego_daemon_client.dart' as hearth;
import 'models/network_config.dart';
import 'screens/splash_screen.dart';
import 'utils/theme.dart';

final _log = Logger('main');
final _walletd = WalletdService();

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
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Start walletd before app launches
  try {
    await _walletd.start(daemonHost: '207.244.247.64', daemonPort: 18180);
    _log.info('walletd started on port ${_walletd.rpcPort}');
  } catch (e) {
    _log.warning('walletd failed to start: $e');
  }

  runApp(FuegoApp(walletd: _walletd));
}

class FuegoApp extends StatefulWidget {
  final WalletdService walletd;
  const FuegoApp({super.key, required this.walletd});

  @override
  State<FuegoApp> createState() => _FuegoAppState();
}

class _FuegoAppState extends State<FuegoApp> {
  @override
  void dispose() {
    widget.walletd.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final daemon = FuegoDaemonClient(
      host: '207.244.247.64',
      port: defaultRpcPort,
      walletPort: widget.walletd.rpcPort,
    );

    final rpcService = FuegoRPCService(
      host: '207.244.247.64',
      port: 18180,
      networkConfig: NetworkConfig.mainnet,
    );

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
              create: (_) => HearthCubit(hearth.FuegoDaemonClient(host: '207.244.247.64')),
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
