import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:app/home.dart';

Widget getPage(String name, {Map<String, dynamic>? param}){
  switch(name){
  case "/Home":
    return  Home();
  }    
  return Container();
}  

bool get isDesktop {
  if (kIsWeb) return false;
  return [
    TargetPlatform.windows,
    TargetPlatform.linux,
    TargetPlatform.macOS,
  ].contains(defaultTargetPlatform);
}



// Is Phone or Tablet Screen
bool isTablet(BuildContext context) {
  return MediaQuery.of(context).size.shortestSide > 600;
}



  
ThemeMode themeMode = ThemeMode.light;

ThemeData lightThemeData = ThemeData(
  colorSchemeSeed: Color.fromARGB(255,58,70,81),
  useMaterial3: true,
  brightness: Brightness.light,


  textTheme: TextTheme(
    displayLarge: TextStyle(
      fontSize: 57.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: -0.25,
      decorationStyle: TextDecorationStyle.solid,
    ),
    displayMedium: TextStyle(
      fontSize: 45.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.0,
      decorationStyle: TextDecorationStyle.solid,
    ),
    displaySmall: TextStyle(
      fontSize: 36.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.0,
      decorationStyle: TextDecorationStyle.solid,
    ),
    headlineLarge: TextStyle(
      fontSize: 32.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.0,
      decorationStyle: TextDecorationStyle.solid,
    ),
    headlineMedium: TextStyle(
      fontSize: 28.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.0,
      decorationStyle: TextDecorationStyle.solid,
    ),
    headlineSmall: TextStyle(
      fontSize: 24.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.0,
      decorationStyle: TextDecorationStyle.solid,
    ),
    titleLarge: TextStyle(
      fontSize: 22.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.0,
      decorationStyle: TextDecorationStyle.solid,
    ),
    titleMedium: TextStyle(
      fontSize: 16.0,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.15,
      decorationStyle: TextDecorationStyle.solid,
    ),
    titleSmall: TextStyle(
      fontSize: 14.0,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.1,
      decorationStyle: TextDecorationStyle.solid,
    ),
    labelLarge: TextStyle(
      fontSize: 14.0,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.1,
      decorationStyle: TextDecorationStyle.solid,
    ),
    labelMedium: TextStyle(
      fontSize: 12.0,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.5,
      decorationStyle: TextDecorationStyle.solid,
    ),
    labelSmall: TextStyle(
      fontSize: 11.0,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.5,
      decorationStyle: TextDecorationStyle.solid,
    ),
    bodyLarge: TextStyle(
      fontSize: 16.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.5,
      decorationStyle: TextDecorationStyle.solid,
    ),
    bodyMedium: TextStyle(
      fontSize: 14.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.25,
      decorationStyle: TextDecorationStyle.solid,
    ),  
    bodySmall: TextStyle(
      fontSize: 12.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.4,
      decorationStyle: TextDecorationStyle.solid,
    ),
  ),  
);

ThemeData darkThemeData = ThemeData(
  colorSchemeSeed: Color.fromARGB(255,58,70,81),
  useMaterial3: true,
  brightness: Brightness.dark,


  textTheme: TextTheme(
    displayLarge: TextStyle(
      fontSize: 57.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: -0.25,
      decorationStyle: TextDecorationStyle.solid,
    ),
    displayMedium: TextStyle(
      fontSize: 45.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.0,
      decorationStyle: TextDecorationStyle.solid,
    ),
    displaySmall: TextStyle(
      fontSize: 36.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.0,
      decorationStyle: TextDecorationStyle.solid,
    ),
    headlineLarge: TextStyle(
      fontSize: 32.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.0,
      decorationStyle: TextDecorationStyle.solid,
    ),
    headlineMedium: TextStyle(
      fontSize: 28.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.0,
      decorationStyle: TextDecorationStyle.solid,
    ),
    headlineSmall: TextStyle(
      fontSize: 24.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.0,
      decorationStyle: TextDecorationStyle.solid,
    ),
    titleLarge: TextStyle(
      fontSize: 22.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.0,
      decorationStyle: TextDecorationStyle.solid,
    ),
    titleMedium: TextStyle(
      fontSize: 16.0,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.15,
      decorationStyle: TextDecorationStyle.solid,
    ),
    titleSmall: TextStyle(
      fontSize: 14.0,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.1,
      decorationStyle: TextDecorationStyle.solid,
    ),
    labelLarge: TextStyle(
      fontSize: 14.0,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.1,
      decorationStyle: TextDecorationStyle.solid,
    ),
    labelMedium: TextStyle(
      fontSize: 12.0,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.5,
      decorationStyle: TextDecorationStyle.solid,
    ),
    labelSmall: TextStyle(
      fontSize: 11.0,
      fontWeight: FontWeight.w500,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.5,
      decorationStyle: TextDecorationStyle.solid,
    ),
    bodyLarge: TextStyle(
      fontSize: 16.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.5,
      decorationStyle: TextDecorationStyle.solid,
    ),
    bodyMedium: TextStyle(
      fontSize: 14.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.25,
      decorationStyle: TextDecorationStyle.solid,
    ),  
    bodySmall: TextStyle(
      fontSize: 12.0,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.normal,
      decoration: TextDecoration.none,
      letterSpacing: 0.4,
      decorationStyle: TextDecorationStyle.solid,
    ),
  ),    
);
