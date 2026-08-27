import 'package:flutter/material.dart';

class AppTheme {
  // Bank of XFG Luxury Swiss Watch & Monaco Private Banking — Ultra Rare Edition
  // Golden champagne dial, brushed platinum case, Midnight Blue accents
  static const Color primaryColor = Color(0xFFC5A059); // Champagne gold (Swiss watch dial)
  static const Color secondaryColor = Color(0xFF1A1814); // Midnight blue-black (depth)
  static const Color accentColor = Color(0xFF3D5A80); // Midnight Blue (Monaco sea / yacht canvas)
  static const Color backgroundColor = Color(0xFF0D0B08); // Obsidian black (premium watch case back)
  static const Color surfaceColor = Color(0xFF181512); // Warm obsidian (inside the case)
  static const Color cardColor = Color(0xFF25221A); // Brushed platinum dark (card face)

  // Comprehensive reddish-orange color palette
  static const Color primaryLight = Color(0xFFFF5722); // Lighter reddish-orange
  static const Color primaryDark = Color(0xFFBF360C); // Darker reddish-orange
  static const Color primaryAccent = Color(0xFFFF8A65); // Accent reddish-orange
  static const Color primaryVariant = Color(0xFFE64A19); // Primary variant

  // Complementary colors for better UX
  static const Color successColor = Color(0xFF4CAF50); // Success green
  static const Color warningColor = Color(0xFFFF9800); // Warning orange
  static const Color errorColor = Color(0xFFF44336); // Error red
  static const Color infoColor = Color(0xFF2196F3); // Info blue

  // Enhanced surface variations — warm obsidian family
  static const Color surfaceLight = Color(0xFF1E1B14); // Lighter warm obsidian
  static const Color surfaceDark = Color(0xFF12100C); // Darker warm obsidian
  static const Color cardLight = Color(0xFF2A2418); // Lighter card — brushed platinum
  static const Color cardDark = Color(0xFF1A1712); // Darker card

  // Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB3B3B3);
  static const Color textMuted = Color(0xFF7D8590);

  // Status colors (moved above for organization)

  /// App-wide font for words: IBMPlexSans (default) or IBMPlexMono /
  /// Arimo / Trirong / Bitter / Brygada1918 (bundled assets, OFL).
  /// Switched at runtime via [AppTheme.fontFamily].
  static String fontFamily = 'IBMPlexSans';

  /// Font used for all numeric displays (balances, prices, amounts,
  /// hashrates, yields). Bundled Noto Sans, OFL. Fallback chain covers
  /// the ΗΞΔŦ ticker glyph if a word font lacks it.
  static String numberFontFamily = 'NotoSans';

  /// Base sizes are the Material defaults +2 for readability.
  static const double baseSizeBump = 2.0;

  /// Numeric text style helper: applies [numberFontFamily] to figures.
  static TextStyle numericStyle({
    double? fontSize,
    Color color = textPrimary,
    FontWeight fontWeight = FontWeight.w500,
  }) {
    return TextStyle(
      fontFamily: numberFontFamily,
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        background: backgroundColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
        onBackground: textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        elevation: 0,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: cardColor,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        shadowColor: Colors.black26,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 2),
        ),
        labelStyle: const TextStyle(color: textSecondary),
        hintStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.all(16),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: primaryColor,
        unselectedLabelColor: textMuted,
        indicatorColor: primaryColor,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF30363D),
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            color: textPrimary, fontSize: 59, fontWeight: FontWeight.w600),
        displayMedium: TextStyle(
            color: textPrimary, fontSize: 47, fontWeight: FontWeight.w600),
        displaySmall: TextStyle(
            color: textPrimary, fontSize: 38, fontWeight: FontWeight.w600),
        headlineLarge: TextStyle(
            color: textPrimary, fontSize: 34, fontWeight: FontWeight.w600),
        headlineMedium: TextStyle(
            color: textPrimary, fontSize: 30, fontWeight: FontWeight.w500),
        headlineSmall: TextStyle(
            color: textPrimary, fontSize: 26, fontWeight: FontWeight.w500),
        titleLarge: TextStyle(
            color: textPrimary, fontSize: 24, fontWeight: FontWeight.w500),
        titleMedium: TextStyle(
            color: textPrimary, fontSize: 18, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(
            color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textPrimary, fontSize: 18),
        bodyMedium: TextStyle(color: textPrimary, fontSize: 16),
        bodySmall: TextStyle(color: textSecondary, fontSize: 14),
        labelLarge: TextStyle(
            color: textPrimary, fontSize: 16, fontWeight: FontWeight.w500),
        labelMedium: TextStyle(color: textSecondary, fontSize: 14),
        labelSmall: TextStyle(color: textMuted, fontSize: 13),
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceColor,
        labelStyle: const TextStyle(color: textPrimary),
        side: const BorderSide(color: Colors.transparent),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) return primaryColor;
          return textMuted;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected))
            return primaryColor.withOpacity(0.5);
          return textMuted.withOpacity(0.3);
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: Color(0xFF30363D),
        circularTrackColor: Color(0xFF30363D),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        surface: Color(0xFFF8F9FA),
        background: Colors.white,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: Colors.black87,
        onBackground: Colors.black87,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        titleTextStyle: TextStyle(
          color: Colors.black87,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: Colors.black87),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        shadowColor: Colors.black12,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // Custom gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryDark,
      primaryColor,
      primaryLight,
    ],
  );

  static final LinearGradient subtleGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      primaryColor.withOpacity(0.1),
      primaryLight.withOpacity(0.05),
    ],
  );

  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryLight,
      primaryColor,
    ],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      primaryAccent,
      primaryLight,
    ],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      backgroundColor,
      Color(0xFF1A1F26),
    ],
  );

  // Text styles with enhanced colors.
  // Numeric styles pin [numberFontFamily] (Noto Sans) for consistent figures.
  static TextStyle get balanceTextStyle => TextStyle(
        fontSize: 34,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        fontFamily: numberFontFamily,
      );

  static TextStyle get currencyTextStyle => TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: accentColor,
        fontFamily: numberFontFamily,
      );

  static TextStyle get transactionAmountStyle => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: primaryColor,
        fontFamily: numberFontFamily,
      );

  static const TextStyle primaryButtonTextStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  // Box shadows with reddish-orange tint
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static final List<BoxShadow> primaryShadow = [
    BoxShadow(
      color: primaryColor.withOpacity(0.3),
      blurRadius: 12,
      offset: const Offset(0, 4),
      spreadRadius: 2,
    ),
  ];

  static const List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: Colors.black26,
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
  ];

  // Color utility methods
  static Color getPrimaryWithOpacity(double opacity) {
    return primaryColor.withOpacity(opacity);
  }

  static Color getSuccessWithOpacity(double opacity) {
    return successColor.withOpacity(opacity);
  }

  static Color getWarningWithOpacity(double opacity) {
    return warningColor.withOpacity(opacity);
  }

  static Color getErrorWithOpacity(double opacity) {
    return errorColor.withOpacity(opacity);
  }

  // Material Design 3 inspired color schemes
  static const Map<String, Color> cryptoColorPalette = {
    'bitcoin': Color(0xFFF7931A),
    'ethereum': Color(0xFF627EEA),
    'monero': Color(0xFF4C82FB),
    'reddit': Color(0xFFFF4500),
    'fuego': primaryColor,
  };
}
