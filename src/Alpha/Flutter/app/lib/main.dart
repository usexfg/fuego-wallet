import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:app/utils/polariscode_util.dart' as util;
import 'package:app/utils/polaris_code_language.dart';
import 'package:app/utils/global.dart';
import 'package:app/home.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (util.isDesktop) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(375, 812),
      minimumSize: Size(375, 812),
      center: true,
      //backgroundColor: Colors.transparent,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.hidden,
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
  await Global.init();
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (context) => LocaleProvider(),
      ),
      ChangeNotifierProvider(
        create: (context) => ThemeModeProvider(),
      ),
    ],
    child: MyApp(),
  ));
  WidgetsFlutterBinding.ensureInitialized();
}

class ThemeModeProvider with ChangeNotifier {
  ThemeModeProvider() {
    if (Global.CurrentThemeMode.isNotEmpty) {
      for (ThemeMode tm in ThemeMode.values) {
        if (tm.name.toLowerCase() == Global.CurrentThemeMode.toLowerCase()) {
          _themeMode = tm;
          break;
        }
      }
    } else {
      Global.setCurrentThemeMode(_themeMode.name);
    }
  }
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get value => _themeMode;
  void setThemeMode(ThemeMode themeMode) {
    _themeMode = themeMode;
    notifyListeners();
  }
}
class LocaleProvider with ChangeNotifier {
  LocaleProvider() {
    if (Global.CurrentLanguage.isNotEmpty) {
      List<String> ls = Global.CurrentLanguage.split('-');
      if (ls.length >= 2) {
        _locale = Locale(ls[0], ls[1]);
      }
    }
  }
  
  Locale _locale = window.locale;

  Locale get value => _locale;
  void setLocale(Locale locale) {
    _locale = locale;
    notifyListeners();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<StatefulWidget> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {

  @override
  initState() {
    super.initState();

    if (!kIsWeb) {
      if (Platform.isAndroid) {
        SystemUiOverlayStyle systemUiOverlayStyle = const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.black);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
          overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
        SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);
      }

      requestPermission();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<String> init() async {
    if (util.isTablet(context)) {
      await SystemChrome.setPreferredOrientations(
        [
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      );
    } else {
      await SystemChrome.setPreferredOrientations(
        [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
        ],
      );
    }
    return "";
  }      

  void requestPermission() async {
    if (Platform.isAndroid || Platform.isIOS) {
      PermissionStatus status = await Permission.storage.status;
      if (status != PermissionStatus.granted) {
        status = await Permission.storage.request();
      }
      status = await Permission.manageExternalStorage.status;
      if (status != PermissionStatus.granted) {
        status = await Permission.manageExternalStorage.request();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
            return MaterialApp(
              locale: context.select((LocaleProvider lp) => lp.value),
              localizationsDelegates: [
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                PolarisCodeLanguageDelegate.delegate,
              ],
              supportedLocales: const [Locale('en', 'US'),
              ],
              navigatorKey: Global.navigatorKey,
              debugShowCheckedModeBanner: false,
              title: 'App',
              themeMode: context.select((ThemeModeProvider tp) => tp.value),
              theme: util.lightThemeData,
              darkTheme: util.darkThemeData,
              home: Home(),
              builder: EasyLoading.init(),
            ); 
  }

}
