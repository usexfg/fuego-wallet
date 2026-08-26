import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// XFG ticker display style.
///
/// 'XFG' renders the plain text ticker; any other value renders the ₲
/// glyph (U+20B2, present in all bundled glyph fonts) in that family,
/// applied only to the symbol span via [xfgText].
class XfgTicker {
  XfgTicker._();
  static const prefKey = 'xfg_ticker_font';

  /// Glyph font family, or '' for the plain-text XFG ticker.
  static String font = '';

  static const options = <({String family, String label, String? note})>[
    (family: '', label: 'XFG', note: 'Plain text · default'),
    (family: 'CormorantSC', label: '₲ Cormorant SC', note: 'Small-cap serif'),
    (family: 'UnicaOne', label: '₲ Unica One', note: 'Condensed display'),
    (family: 'Fahkwang', label: '₲ Fahkwang', note: 'Thai-latin sans'),
    (family: 'CrimsonPro', label: '₲ Crimson Pro', note: 'Old-style serif'),
  ];

  static bool get isGlyph => font.isNotEmpty;

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(prefKey) ?? '';
      font = options.any((o) => o.family == saved) ? saved : '';
    } catch (_) {
      font = '';
    }
  }

  static Future<void> set(String family) async {
    font = options.any((o) => o.family == family) ? family : '';
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(prefKey, font);
    } catch (_) {}
  }

  /// The ticker token as rendered inline: 'XFG' or the ₲ glyph.
  static String get symbol => isGlyph ? '\u20B2' : 'XFG';

  /// Style applied to just the glyph span when a glyph font is active.
  static TextStyle? glyphStyle(TextStyle base) =>
      isGlyph ? base.copyWith(fontFamily: font) : null;

  /// Text widget builder: swaps every 'XFG' token for the configured
  /// ticker, styling the glyph span with its own family when active.
  static Widget text(
    String data,
    TextStyle style, {
    Key? key,
    StrutStyle? strutStyle,
    TextAlign? textAlign,
    TextDirection? textDirection,
    Locale? locale,
    bool? softWrap,
    TextOverflow? overflow,
    int? maxLines,
    String? semanticsLabel,
    TextWidthBasis? textWidthBasis,
  }) {
    if (!isGlyph || !data.contains('XFG')) {
      return Text(
        key: key,
        data,
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
      );
    }
    final glyph = glyphStyle(style);
    final spans = <TextSpan>[];
    var i = 0;
    while (true) {
      final idx = data.indexOf('XFG', i);
      if (idx < 0) {
        spans.add(TextSpan(text: data.substring(i)));
        break;
      }
      if (idx > i) spans.add(TextSpan(text: data.substring(i, idx)));
      spans.add(TextSpan(text: '\u20B2', style: glyph));
      i = idx + 3;
    }
    return Text.rich(
      key: key,
      TextSpan(style: style, children: spans),
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
    );
  }
}

/// Drop-in replacement for [Text] that renders every 'XFG' token with
/// the configured ticker glyph font when active.
Widget xfgText(
  String data, {
  Key? key,
  TextStyle? style,
  StrutStyle? strutStyle,
  TextAlign? textAlign,
  TextDirection? textDirection,
  Locale? locale,
  bool? softWrap,
  TextOverflow? overflow,
  int? maxLines,
  String? semanticsLabel,
  TextWidthBasis? textWidthBasis,
}) =>
    XfgTicker.text(
      data,
      style ?? const TextStyle(),
      key: key,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textDirection: textDirection,
      locale: locale,
      softWrap: softWrap,
      overflow: overflow,
      maxLines: maxLines,
      semanticsLabel: semanticsLabel,
      textWidthBasis: textWidthBasis,
    );
