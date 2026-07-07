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
}

class FuegoApp extends StatelessWidget {
  const FuegoApp({super.key});

  @override
  Widget build(BuildContext context) {
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
