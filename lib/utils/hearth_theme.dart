import 'package:flutter/material.dart';

class HearthTheme {
  HearthTheme._();

  static const Color bgPure = Color(0xFF000000);
  static const Color bgDeep = Color(0xFF0A0A0A);
  static const Color bgCard = Color(0xFF111111);
  static const Color bgSurface = Color(0xFF161616);
  static const Color bgElevated = Color(0xFF1C1C1C);
  static const Color bgInput = Color(0xFF151515);

  static const Color bidPrimary = Color(0xFF00ACC1);
  static const Color bidLight = Color(0xFF4DD0E1);
  static const Color bidBg = Color(0x1800ACC1);
  static const Color bidDepth = Color(0x3000ACC1);

  static const Color askPrimary = Color(0xFFD84315);
  static const Color askLight = Color(0xFFFF5722);
  static const Color askBg = Color(0x18D84315);
  static const Color askDepth = Color(0x30D84315);

  static const Color textWhite = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFFD9D9D9);
  static const Color textSecondary = Color(0xFF888888);
  static const Color textMuted = Color(0xFF555555);
  static const Color textDim = Color(0xFF333333);

  static const Color divider = Color(0xFF1A1A1A);
  static const Color border = Color(0xFF222222);

  static const Color chartLine = Color(0xFFD84315);
  static const Color chartPulse = Color(0xFFD84315);

  static TextStyle mono({double size = 12, FontWeight weight = FontWeight.w500, Color color = textPrimary}) {
    return TextStyle(
      fontFamily: 'monospace',
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
