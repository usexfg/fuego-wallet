import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Fuego brand colors - Rich reddish-orange inspired by Bitcoin/Monero/Reddit
  static const Color primaryColor = Color(0xFFE53935); // Sleeker vibrant red
  static const Color secondaryColor = Color(0xFF1E1E24); // Dark gray
  static const Color accentColor = Color(0xFFFFD700); // Gold accent
  static const Color backgroundColor = Color(0xFF000000); // OLED Black
  static const Color surfaceColor = Color(0xFF0A0B0E); // Very dark gray/blue
  static const Color cardColor = Color(0xFF111418); // TradingView dark panel style

  // Comprehensive reddish-orange color palette
  static const Color primaryLight = Color(0xFFFF5252); // Lighter red
  static const Color primaryDark = Color(0xFFC62828); // Darker red
  static const Color primaryAccent = Color(0xFFFF8A80); // Accent red
  static const Color primaryVariant = Color(0xFFD32F2F); // Primary variant

  // Complementary colors for better UX
  static const Color successColor = Color(0xFF26A69A); // TradingView Bull green
  static const Color warningColor = Color(0xFFFFB74D); // Warning orange
  static const Color errorColor = Color(0xFFEF5350); // TradingView Bear red
  static const Color infoColor = Color(0xFF2962FF); // Info blue

  // Enhanced surface variations
  static const Color surfaceLight = Color(0xFF181C24); // Lighter surface
  static const Color surfaceDark = Color(0xFF050608); // Darker surface
  static const Color cardLight = Color(0xFF1C212A); // Lighter card
  static const Color cardDark = Color(0xFF0A0C10); // Darker card

  // Text colors
  static const Color textPrimary = Color(0xFFE2E8F0); // Crisp off-white
  static const Color textSecondary = Color(0xFF94A3B8); // Slate cool gray
  static const Color textMuted = Color(0xFF475569); // Deeper slate

  // Interactive and divider colors
  static const Color interactiveColor = Color(0xFF3B82F6);
  static const Color dividerColor = Color(0xFF1E293B);

  // Status colors (moved above for organization)

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: textPrimary,
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: const CardThemeData(
        color: cardColor,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0xFF1E293B), width: 1),
        ),
        shadowColor: Colors.black26,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: Color(0xFF334155)),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentColor,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cardColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(color: textSecondary),
        hintStyle: GoogleFonts.inter(color: textMuted),
        contentPadding: const EdgeInsets.all(16),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: backgroundColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: textPrimary,
        unselectedLabelColor: textMuted,
        indicatorColor: primaryColor,
        labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500),
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold, letterSpacing: -1.0),
        displayMedium: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold, letterSpacing: -0.5),
        displaySmall: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold),
        headlineLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w500),
        titleSmall: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.inter(color: textPrimary),
        bodyMedium: GoogleFonts.inter(color: textPrimary),
        bodySmall: GoogleFonts.inter(color: textSecondary),
        labelLarge: GoogleFonts.inter(color: textPrimary, fontWeight: FontWeight.w500),
        labelMedium: GoogleFonts.inter(color: textSecondary),
        labelSmall: GoogleFonts.inter(color: textMuted),
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      chipTheme: ChipThemeData(
        backgroundColor: cardColor,
        labelStyle: GoogleFonts.inter(color: textPrimary),
        side: const BorderSide(color: dividerColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primaryColor;
          }
          return cardColor;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.transparent;
          return dividerColor;
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primaryColor,
        linearTrackColor: cardColor,
        circularTrackColor: cardColor,
      ),
    );
  }

  static ThemeData get lightTheme {
    final baseTextTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        surface: Color(0xFFF8FAFC),
        error: errorColor,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: Color(0xFF0F172A),
        onError: Colors.white,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        titleTextStyle: GoogleFonts.inter(
          color: const Color(0xFF0F172A),
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      cardTheme: const CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
          side: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        shadowColor: Colors.black12,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold, letterSpacing: -1.0),
        displayMedium: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold, letterSpacing: -0.5),
        displaySmall: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold),
        headlineLarge: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.bold),
        headlineMedium: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
        titleSmall: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.inter(color: const Color(0xFF334155)),
        bodyMedium: GoogleFonts.inter(color: const Color(0xFF334155)),
        bodySmall: GoogleFonts.inter(color: const Color(0xFF64748B)),
        labelLarge: GoogleFonts.inter(color: const Color(0xFF0F172A), fontWeight: FontWeight.w500),
        labelMedium: GoogleFonts.inter(color: const Color(0xFF64748B)),
        labelSmall: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
      ),
    );
  }

  // Custom gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFFF5252),
      primaryColor,
      Color(0xFFC62828),
    ],
  );

  static const LinearGradient subtleGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF1E293B),
      Color(0xFF0F172A),
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
      surfaceColor,
    ],
  );

  // Text styles with enhanced colors
  static TextStyle balanceTextStyle = GoogleFonts.jetBrainsMono(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -1.0,
  );

  static TextStyle currencyTextStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: accentColor,
  );

  static TextStyle transactionAmountStyle = GoogleFonts.jetBrainsMono(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: primaryColor,
  );

  static TextStyle primaryButtonTextStyle = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
    letterSpacing: 0.5,
  );

  // Box shadows
  static const List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> primaryShadow = [
    BoxShadow(
      color: Color(0x33E53935), // primaryColor
      blurRadius: 16,
      offset: Offset(0, 8),
      spreadRadius: -2,
    ),
  ];

  static const List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: Color(0x1A000000),
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
