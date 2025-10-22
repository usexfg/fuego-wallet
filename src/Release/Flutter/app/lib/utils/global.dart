import 'dart:io' as io;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/utils/polaris_code_language.dart';

class Global {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey();
  
  static SharedPreferences? prefs;
  static Future<void> init() async {
    prefs = await SharedPreferences.getInstance();
    if (!kIsWeb) {
      io.Directory temporaryDirectory = await getTemporaryDirectory();
      _TemporaryDirectory = temporaryDirectory.path;
      io.Directory? applicationCacheDirectory = io.Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationDocumentsDirectory();
      _ApplicationDocumentsDirectory = applicationCacheDirectory?.path ?? "";
    }
  }

  static String get Platform => kIsWeb ? "web" : io.Platform.operatingSystem;
  static String get SystemLanguageCode => window.locale.languageCode;
  static String get SystemCountryCode => window.locale.countryCode??"";
  static String get CurrentLanguage => prefs?.getString("CurrentLanguage") ?? ( PolarisCodeLanguage.getDefaultLanguage().languageCode + "-" + (PolarisCodeLanguage.getDefaultLanguage().countryCode ?? "") );
  static void setCurrentLanguage(String value){
    prefs?.setString("CurrentLanguage", value);
  }
  static String get CurrentThemeMode => prefs?.getString("CurrentThemeMode") ?? "";
  static void setCurrentThemeMode(String value){
    prefs?.setString("CurrentThemeMode", value);
  }
  static String _TemporaryDirectory = "";
  static String get TemporaryDirectory => _TemporaryDirectory;
  static String _ApplicationDocumentsDirectory = "";
  static String get ApplicationDocumentsDirectory =>
      _ApplicationDocumentsDirectory;
        
  static String  get Version => "1.0.1";


}  