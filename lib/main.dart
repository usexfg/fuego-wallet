import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:fuego_defi_sdk/fuego_defi_sdk.dart';
import 'package:fuego_core/fuego_core.dart';
import 'package:logging/logging.dart';

import 'bloc/app_bloc_observer.dart';
import 'bloc/auth/auth_cubit.dart';
import 'bloc/wallet/wallet_cubit.dart';
import 'bloc/dex/dex_cubit.dart';
import 'bloc/cd/cd_cubit.dart';
import 'bloc/hearth/hearth_cubit.dart';
import 'providers/wallet_provider.dart';
import 'services/sdk_service.dart';
import 'services/kdf_config_service.dart';
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
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Read KDF config from settings
  final kdfConfigService = KdfConfigService();
  IKdfHostConfig? hostConfig;
  try {
    final kdfHost = await kdfConfigService.getHost();
    if (kdfHost.isNotEmpty) {
      final port = await kdfConfigService.getPort();
      final https = await kdfConfigService.getHttps();
      final password = await kdfConfigService.getPassword();
      hostConfig = RemoteConfig(
        ipAddress: kdfHost,
        port: port,
        https: https,
        rpcPassword: password,
      );
      _log.info('Using remote KDF: $kdfHost:$port');
    }
  } catch (e) {
    _log.warning('Failed to load KDF config: $e');
  }

  // Initialize SDK (optional — needed for DEX, not for wallet/daemon ops)
  FuegoDefiSdk? fuegoDefiSdk;
  try {
    final sdkService = SdkService(hostConfig: hostConfig);
    fuegoDefiSdk = await sdkService.initialize();
    debugPrint('SDK initialized successfully');
  } catch (e) {
    debugPrint('SDK not available (expected without KDF): $e');
  }

  runApp(FuegoApp(sdk: fuegoDefiSdk));
}

class FuegoApp extends StatelessWidget {
  final FuegoDefiSdk? sdk;

  const FuegoApp({super.key, this.sdk});

  @override
  Widget build(BuildContext context) {
    // Mainnet daemon RPC — always works via HTTP
    final daemon = FuegoDaemonClient(host: '207.244.247.64', port: defaultRpcPort);

    // CD/hearth RPC service
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
          if (sdk != null) RepositoryProvider<FuegoDefiSdk>.value(value: sdk!),
          RepositoryProvider<FuegoDaemonClient>.value(value: daemon),
          RepositoryProvider<FuegoRPCService>.value(value: rpcService),
        ],
        child: MultiBlocProvider(
          providers: [
            BlocProvider<AuthCubit>(
              create: (_) => AuthCubit(sdk)..initialize(),
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
