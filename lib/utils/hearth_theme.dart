import 'package:flutter/material.dart';

class HearthTheme {
  HearthTheme._();

  static const Color bgPure = Color(0xFF0D0B08); // Obsidian — house base
  static const Color bgDeep = Color(0xFF12100C);
  static const Color bgCard = Color(0xFF25221A); // Brushed platinum dark
  static const Color bgSurface = Color(0xFF181512);
  static const Color bgElevated = Color(0xFF1E1B14);
  static const Color bgInput = Color(0xFF1A1712);

  static const Color bidPrimary = Color(0xFF3D5A80); // Midnight Blue — bids (private banking)
  static const Color bidLight = Color(0xFF5A7A9C);
  static const Color bidBg = Color(0x183D5A80);
  static const Color bidDepth = Color(0x303D5A80);

  static const Color askPrimary = Color(0xFFC5A059); // Champagne gold — house primary
  static const Color askLight = Color(0xFFD4B896);
  static const Color askBg = Color(0x18C5A059);
  static const Color askDepth = Color(0x30C5A059);

  static const Color textWhite = Color(0xFFF5F1E8); // Cream parchment
  static const Color textPrimary = Color(0xFFC2B8A3);
  static const Color textSecondary = Color(0xFF8A8278);
  static const Color textMuted = Color(0xFF6B6560);
  static const Color textDim = Color(0xFF3A352F);

  static const Color divider = Color(0xFF2A2418);
  static const Color border = Color(0xFF3A352F);

  static const Color chartLine = Color(0xFFC5A059);
  static const Color chartPulse = Color(0xFFC5A059);

  static TextStyle mono({double size = 12, FontWeight weight = FontWeight.w500, Color color = textPrimary}) {
    return TextStyle(
      fontFamily: 'IBMPlexMono',
      fontSize: size,
      fontWeight: weight,
      color: color,
      letterSpacing: 0.3,
    );
  }

  static TextStyle label({double size = 10, Color color = textMuted}) {
    return TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w500,
      color: color,
      letterSpacing: 0.5,
    );
  }
}
