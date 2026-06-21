import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'providers/wallet_provider.dart';
import 'services/fuego_rpc_service.dart';
import 'services/wallet_daemon_service.dart';
import 'models/network_config.dart';
import 'screens/splash_screen.dart';
import 'utils/theme.dart';
import 'screens/banking/atomic_swaps_screen.dart';
import 'screens/heat/heat_page.dart';
import 'screens/banking/aliases_screen.dart';
import 'screens/cd/cd_page.dart';
import 'screens/price_chart/price_chart_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize WalletDaemonService
  await WalletDaemonService.initialize(
    daemonAddress: '207.244.247.64',
    daemonPort: 18180,
    networkConfig: NetworkConfig.mainnet,
  );

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const XFGWalletApp());
}

class XFGWalletApp extends StatelessWidget {
  const XFGWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => WalletProvider(
            rpcService: FuegoRPCService(
              host: '207.244.247.64',
              port: 18180,
              networkConfig: NetworkConfig.mainnet,
            ),
          ),
        ),
      ],
      child: MaterialApp(
        title: 'Fuego Wallet',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: const SplashScreen(),
      routes: {
        '/swaps': (context) => const AtomicSwapsScreen(),
        '/heat': (context) => const HeatPage(),
        '/aliases': (context) => const AliasesScreen(),
        '/cd': (context) => const CDPage(),
        '/price-chart': (context) => const PriceChartScreen(),
      },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
