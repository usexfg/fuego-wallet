import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CandleData {
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;
  final DateTime time;

  const CandleData({
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    required this.volume,
    required this.time,
  });

  bool get isBullish => close >= open;
  bool get isBearish => close < open;
}

class TradingChart extends StatefulWidget {
  final List<CandleData> candles;
  final double height;
  final Color bullColor;
  final Color bearColor;

  const TradingChart({
    super.key,
    required this.candles,
    this.height = 420,
    this.bullColor = const Color(0xFF26A69A),
    this.bearColor = const Color(0xFFEF5350),
  });

  @override
  State<TradingChart> createState() => _TradingChartState();
}

class _TradingChartState extends State<TradingChart> {
  // Viewport
  double _scale = 1.0;
  double _offsetX = 0.0; // left edge in candle-index units

  // Gesture tracking
  double _lastScale = 1.0;
  double _panStartX = 0;
  double _panStartOffset = 0;
  bool _isPanning = false;

  // Crosshair
  int? _crosshairIndex;
  bool _crosshairLocked = false;

  static const int _baseVisible = 60;
  static const double _minScale = 0.3;
  static const double _maxScale = 20.0;

  int get _totalCandles => widget.candles.length;

  int get _visibleCount {
    final raw = (_baseVisible / _scale).round();
    return max(3, min(raw, _totalCandles));
  }

  double get _leftIndex {
    final maxOff = max(0.0, (_totalCandles - _visibleCount).toDouble());
    return _offsetX.clamp(-_visibleCount * 0.2, maxOff + _visibleCount * 0.2);
  }

  int _screenToIndex(double dx, double chartWidth) {
    final candleW = chartWidth / _visibleCount;
    final idx = (dx / candleW) + _leftIndex;
    return idx.round().clamp(0, _totalCandles - 1);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.candles.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text('No data', style: TextStyle(color: Color(0xFF6B6B6B))),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final W = constraints.maxWidth;
          final H = constraints.maxHeight.isFinite ? constraints.maxHeight : widget.height;

          return GestureDetector(
            // ALL gestures go through onScaleUpdate — no horizontalDrag
            behavior: HitTestBehavior.opaque,

            onScaleStart: (d) {
              _lastScale = _scale;
              _panStartX = d.focalPoint.dx;
              _panStartOffset = _offsetX;
              _isPanning = true;
              if (d.pointerCount == 2) {
                _crosshairLocked = true;
              }
            },

            onScaleUpdate: (d) {
              setState(() {
                if (d.pointerCount == 2) {
                  // ── Pinch zoom ──
                  final newScale = (_lastScale * d.scale).clamp(_minScale, _maxScale);
                  final centerX = d.focalPoint.dx;
                  final newVisible = max(3, (_baseVisible / newScale).round());
                  final centerIdx = (centerX / (W / newVisible)) + _leftIndex;
                  final newLeft = centerIdx - centerX / (W / newVisible);

                  _scale = newScale;
                  _offsetX = newLeft;
                  _crosshairIndex = _screenToIndex(centerX, W);
                } else if (_isPanning) {
                  // ── Single-finger pan / scroll ──
                  final dx = d.focalPoint.dx - _panStartX;
                  final candleW = W / _visibleCount;
                  _offsetX = _panStartOffset - dx / candleW;

                  // Clamp
                  final maxOff = max(0.0, (_totalCandles - _visibleCount).toDouble());
                  _offsetX = _offsetX.clamp(
                      -_visibleCount * 0.3, maxOff + _visibleCount * 0.3);

                  // Crosshair while panning
                  if (!_crosshairLocked) {
                    _crosshairIndex = _screenToIndex(d.focalPoint.dx, W);
                  }
                }
              });
            },

            onScaleEnd: (d) {
              // Snap offset to valid range
              final maxOff = max(0.0, (_totalCandles - _visibleCount).toDouble());
              _offsetX = _offsetX.clamp(0.0, maxOff);
              setState(() {
                _crosshairLocked = false;
              });
            },

            onLongPressStart: (d) {
              setState(() {
                _crosshairLocked = true;
                _crosshairIndex = _screenToIndex(d.localPosition.dx, W);
              });
            },
            onLongPressMoveUpdate: (d) {
              setState(() {
                _crosshairIndex = _screenToIndex(d.localPosition.dx, W);
              });
            },
            onLongPressEnd: (_) {
              setState(() {
                _crosshairLocked = false;
                _crosshairIndex = null;
              });
            },

            onDoubleTap: () {
              setState(() {
                _scale = 1.0;
                _offsetX = max(0.0, (_totalCandles - _baseVisible).toDouble());
                _crosshairIndex = null;
              });
            },

            child: CustomPaint(
              painter: _ChartPainter(
                candles: widget.candles,
                leftIndex: _leftIndex,
                visibleCount: _visibleCount,
                bullColor: widget.bullColor,
                bearColor: widget.bearColor,
                crosshairIndex: _crosshairLocked ? _crosshairIndex : null,
              ),
              size: Size(W, H),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CustomPainter
// ═══════════════════════════════════════════════════════════════════════════════

class _ChartPainter extends CustomPainter {
  final List<CandleData> candles;
  final double leftIndex;
  final int visibleCount;
  final Color bullColor;
  final Color bearColor;
  final int? crosshairIndex;

  _ChartPainter({
    required this.candles,
    required this.leftIndex,
    required this.visibleCount,
    required this.bullColor,
    required this.bearColor,
    this.crosshairIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty || visibleCount <= 0) return;

    final W = size.width;
    final priceH = size.height * 0.70;
    final volH = size.height * 0.18;
    final volTop = priceH + size.height * 0.04;

    // Visible slice
    final startIdx = max(0, leftIndex.floor());
    final endIdx = min(candles.length, leftIndex.ceil() + visibleCount + 2);
    final visible = candles.sublist(startIdx, endIdx);
    if (visible.isEmpty) return;

    final localLeft = leftIndex - startIdx;

    // Price range
    final hi = visible.map((c) => c.high).reduce(max);
    final lo = visible.map((c) => c.low).reduce(min);
    final pad = (hi - lo) * 0.1;
    final yMin = lo - pad;
    final yMax = hi + pad;
    final yRange = yMax - yMin;
    if (yRange <= 0) return;

    final maxVol = visible.map((c) => c.volume).reduce(max);
    final candleW = W / visibleCount;
    final bodyW = max(1.5, candleW * 0.65);

    double p2y(double p) => priceH * (1.0 - (p - yMin) / yRange);

    // ── Grid ──────────────────────────────────────────────────────────────
    final gridPaint = Paint()..color = const Color(0xFF1A2332)..strokeWidth = 0.5;
    for (int i = 0; i <= 6; i++) {
      final y = priceH * i / 6;
      canvas.drawLine(Offset(0, y), Offset(W, y), gridPaint);
    }

    // ── Y-axis price labels ──────────────────────────────────────────────
    for (int i = 0; i <= 6; i++) {
      final y = priceH * i / 6;
      final price = yMax - (yRange * i / 6);
      _drawText(canvas, _fmtPrice(price), Offset(2, y + 3),
          const Color(0xFF64748B), 9);
    }

    // ── Volume bars ──────────────────────────────────────────────────────
    for (int i = 0; i < visible.length; i++) {
      final c = visible[i];
      final vr = maxVol > 0 ? c.volume / maxVol : 0.0;
      final bh = vr * volH;
      final bx = (i - localLeft) * candleW + (candleW - bodyW) / 2;
      final by = volTop + volH - bh;
      canvas.drawRect(
          Rect.fromLTWH(bx, by, bodyW, max(0.5, bh)),
          Paint()
            ..color = (c.isBullish ? bullColor : bearColor).withOpacity(0.25)
            ..style = PaintingStyle.fill);
    }

    // ── X-axis date labels ───────────────────────────────────────────────
    final step = max(1, visibleCount ~/ 5);
    final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    for (int i = 0; i < visible.length; i += step) {
      final d = visible[i].time;
      final label = '${months[d.month - 1]} ${d.day}';
      final x = (i - localLeft) * candleW;
      _drawText(canvas, label, Offset(x + 2, priceH - 10),
          const Color(0xFF64748B), 9);
    }

    // ── Candlesticks ─────────────────────────────────────────────────────
    for (int i = 0; i < visible.length; i++) {
      final c = visible[i];
      final cx = (i - localLeft + 0.5) * candleW;
      final color = c.isBullish ? bullColor : bearColor;

      // Wick
      canvas.drawLine(
          Offset(cx, p2y(c.high)), Offset(cx, p2y(c.low)),
          Paint()..color = color..strokeWidth = max(0.8, bodyW * 0.12));

      // Body
      final top = p2y(max(c.open, c.close));
      final bot = p2y(min(c.open, c.close));
      final bh = max(1.5, bot - top);
      final bodyRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(cx, (top + bot) / 2), width: bodyW, height: bh),
        Radius.circular(max(0.5, bodyW * 0.1)),
      );

      final bp = Paint()..color = color;
      if (c.isBullish) {
        bp.style = PaintingStyle.stroke;
        bp.strokeWidth = max(1.0, bodyW * 0.15);
      } else {
        bp.style = PaintingStyle.fill;
      }
      canvas.drawRRect(bodyRect, bp);
    }

    // ── Moving Averages ──────────────────────────────────────────────────
    final bufStart = max(0, startIdx - 30);
    final bufEnd = min(candles.length, endIdx);
    final buf = candles.sublist(bufStart, bufEnd);

    _drawMA(canvas, buf, bufStart, startIdx, localLeft, candleW, priceH,
        yMin, yRange, 7, const Color(0xFFFFAB40));
    _drawMA(canvas, buf, bufStart, startIdx, localLeft, candleW, priceH,
        yMin, yRange, 9, const Color(0xFF42A5F5), ema: true);
    _drawMA(canvas, buf, bufStart, startIdx, localLeft, candleW, priceH,
        yMin, yRange, 25, const Color(0xFFAB47BC));

    // ── MA Legend ─────────────────────────────────────────────────────────
    double lx = 8;
    for (final (label, col) in [
      ('SMA7', const Color(0xFFFFAB40)),
      ('EMA9', const Color(0xFF42A5F5)),
      ('SMA25', const Color(0xFFAB47BC)),
    ]) {
      canvas.drawLine(Offset(lx, 10), Offset(lx + 14, 10),
          Paint()..color = col..strokeWidth = 2);
      _drawText(canvas, ' $label', Offset(lx + 16, 3), col, 9);
      lx += 52;
    }

    // ── Crosshair ────────────────────────────────────────────────────────
    if (crosshairIndex != null &&
        crosshairIndex! >= startIdx &&
        crosshairIndex! < endIdx) {
      final ci = crosshairIndex!;
      final c = candles[ci];
      final li = (ci - startIdx - localLeft + 0.5) * candleW;

      final crossPaint = Paint()
        ..color = const Color(0x60FFFFFF)
        ..strokeWidth = 0.8;

      // Vertical
      canvas.drawLine(Offset(li, 0), Offset(li, priceH), crossPaint);

      // Horizontal at close
      final closeY = p2y(c.close);
      canvas.drawLine(Offset(0, closeY), Offset(W, closeY), crossPaint);

      // Price tag on right
      final tagColor = c.isBullish ? bullColor : bearColor;
      final tagW = 52.0;
      final tagH = 18.0;
      final tagX = W - tagW;
      final tagY = closeY - tagH / 2;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(tagX, tagY, tagW, tagH), const Radius.circular(3)),
          Paint()..color = tagColor);
      _drawText(canvas, _fmtPrice(c.close), Offset(tagX + 4, tagY + 3),
          Colors.white, 9, bold: true);

      // OHLCV tooltip
      final boxW = 135.0;
      final boxH = 92.0;
      final boxX = li + 20 > W - boxW - 8 ? li - boxW - 20 : li + 20;
      final boxY = max(8.0, min(closeY - boxH / 2, priceH - boxH - 8));

      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(boxX, boxY, boxW, boxH), const Radius.circular(8)),
          Paint()..color = const Color(0xF00F172A));
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(boxX, boxY, boxW, boxH), const Radius.circular(8)),
          Paint()
            ..color = const Color(0xFF334155)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1);

      final rows = [
        ('Date', '${c.time.month}/${c.time.day}/${c.time.year}',
            const Color(0xFF94A3B8)),
        ('O', _fmtPrice(c.open), const Color(0xFF94A3B8)),
        ('H', _fmtPrice(c.high), const Color(0xFF94A3B8)),
        ('L', _fmtPrice(c.low), const Color(0xFF94A3B8)),
        ('C', _fmtPrice(c.close), tagColor),
        ('Vol', _fmtVol(c.volume), const Color(0xFF94A3B8)),
      ];
      double ty = boxY + 8;
      for (final (lbl, val, col) in rows) {
        _drawRow(canvas, boxX + 10, ty, '$lbl: ', val, col);
        ty += 13.5;
      }
    }

    // ── Current price line (dashed) ──────────────────────────────────────
    if (candles.isNotEmpty) {
      final last = candles.last;
      final ly = p2y(last.close);
      final linePaint = Paint()
        ..color = last.isBullish ? bullColor.withOpacity(0.6) : bearColor.withOpacity(0.6)
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke;
      for (double x = 0; x < W; x += 6) {
        canvas.drawLine(Offset(x, ly), Offset(min(x + 3, W), ly), linePaint);
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  void _drawMA(Canvas canvas, List<CandleData> buf, int bufStart,
      int startIdx, double localLeft, double candleW, double priceH,
      double yMin, double yRange, int period, Color color,
      {bool ema = false}) {
    final vals = ema ? _ema(buf, period) : _sma(buf, period);

    final path = Path();
    bool started = false;
    for (int i = 0; i < buf.length; i++) {
      final globalI = bufStart + i;
      if (globalI < startIdx || globalI >= startIdx + visibleCount) continue;
      if (i >= vals.length || vals[i].isNaN) continue;

      final localI = globalI - startIdx;
      final x = (localI - localLeft + 0.5) * candleW;
      final y = priceH * (1.0 - (vals[i] - yMin) / yRange);
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
  }

  List<double> _sma(List<CandleData> data, int p) {
    final r = <double>[];
    for (int i = 0; i < data.length; i++) {
      if (i < p - 1) {
        r.add(double.nan);
      } else {
        double s = 0;
        for (int j = i - p + 1; j <= i; j++) s += data[j].close;
        r.add(s / p);
      }
    }
    return r;
  }

  List<double> _ema(List<CandleData> data, int p) {
    final r = <double>[];
    if (data.isEmpty) return r;
    double e = data[0].close;
    final m = 2.0 / (p + 1);
    for (int i = 0; i < data.length; i++) {
      if (i < p - 1) {
        double s = 0;
        for (int j = 0; j <= i; j++) s += data[j].close;
        e = s / (i + 1);
        r.add(double.nan);
      } else {
        e = (data[i].close - e) * m + e;
        r.add(e);
      }
    }
    return r;
  }

  void _drawText(
      Canvas canvas, String text, Offset pos, Color color, double size,
      {bool bold = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  void _drawRow(
      Canvas canvas, double x, double y, String label, String val, Color col) {
    final tp = TextPainter(
      text: TextSpan(children: [
        TextSpan(
            text: label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
        TextSpan(
            text: val,
            style: TextStyle(
                color: col, fontSize: 10, fontWeight: FontWeight.w600)),
      ]),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x, y));
  }

  String _fmtPrice(double p) {
    if (p >= 1.0) return '\$${p.toStringAsFixed(2)}';
    if (p >= 0.01) return '\$${p.toStringAsFixed(4)}';
    if (p >= 0.0001) return '\$${p.toStringAsFixed(6)}';
    return '\$${p.toStringAsFixed(8)}';
  }

  String _fmtVol(double v) {
    if (v >= 1e6) return '${(v / 1e6).toStringAsFixed(1)}M';
    if (v >= 1e3) return '${(v / 1e3).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.crosshairIndex != crosshairIndex ||
      old.leftIndex != leftIndex ||
      old.visibleCount != visibleCount;
}

// ═══════════════════════════════════════════════════════════════════════════════
// Sample data generator
// ═══════════════════════════════════════════════════════════════════════════════

List<CandleData> generateSampleCandles(double basePrice, int count) {
  final random = Random();
  final candles = <CandleData>[];
  double price = basePrice;
  DateTime time = DateTime.now().subtract(Duration(days: count));

  for (int i = 0; i < count; i++) {
    final open = price;
    final change = (random.nextDouble() - 0.48) * price * 0.06;
    final close = (open + change).clamp(price * 0.5, price * 2.0);
    final high = max(open, close) * (1 + random.nextDouble() * 0.03);
    final low = min(open, close) * (1 - random.nextDouble() * 0.03);

    candles.add(CandleData(
      open: open,
      high: high,
      low: max(0.00001, low),
      close: close,
      volume: 100000 + random.nextDouble() * 5000000,
      time: time,
    ));

    time = time.add(const Duration(days: 1));
    price = close;
  }

  return candles;
}
