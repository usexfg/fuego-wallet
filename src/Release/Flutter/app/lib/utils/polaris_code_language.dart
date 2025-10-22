import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'dart:ui';

class PolarisCodeLanguage {
  final Locale locale;
  PolarisCodeLanguage(this.locale);
  
  static List<Locale> suppoertedLocales = const [
    
  ];
  
  static bool suppoertedLanguage(String code) {
    for (Locale locale in suppoertedLocales) {
      if (locale.languageCode + "-" + (locale.countryCode ?? "") == code) {
        return true;
      }
    }
    return false;
  }
  static Locale getDefaultLanguage(){
    for (Locale locale in suppoertedLocales) {
      if (locale.languageCode == window.locale.languageCode &&
          locale.countryCode == window.locale.countryCode) {
        return locale;
      }
    }
    if(suppoertedLocales.isEmpty){
      return Locale("en", "US");
    }else{
      return suppoertedLocales.first;
    }
  }
    
  static final Map<String, Map<String, String>> _localizedValues = {
  };

  String convert(String key) {
    if (_localizedValues.containsKey(locale.languageCode+"-"+(locale.countryCode??"")) && _localizedValues[locale.languageCode+"-"+(locale.countryCode??"")]!.containsKey(key)) {
      return _localizedValues[locale.languageCode+"-"+(locale.countryCode??"")]![key]!;
    } else {
      return key;
    }
  }

  static PolarisCodeLanguage of(BuildContext context) {
    PolarisCodeLanguage? pcl =
        Localizations.of(context, PolarisCodeLanguage);
    if (pcl != null) {
      return pcl;
    } else {
      Locale locale = Locale("en", "US");
      return PolarisCodeLanguage(locale);
    }
  }
}


class PolarisCodeLanguageDelegate
    extends LocalizationsDelegate<PolarisCodeLanguage> {
  const PolarisCodeLanguageDelegate();
  @override
  bool isSupported(Locale locale) {
    return [].contains(locale.languageCode + "-" + (locale.countryCode ?? ""));
  }

  @override
  Future<PolarisCodeLanguage> load(Locale locale) {
    return SynchronousFuture<PolarisCodeLanguage>(
        PolarisCodeLanguage(locale));
  }

  @override
  bool shouldReload(
      LocalizationsDelegate<PolarisCodeLanguage> old) {
    return false;
  }

  static PolarisCodeLanguageDelegate delegate =
      const PolarisCodeLanguageDelegate();
}