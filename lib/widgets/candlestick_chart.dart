import 'dart:math';
import 'dart:ui' as ui;
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

// ═══════════════════════════════════════════════════════════════════════════════
// TradingView-style chart with pinch-zoom, momentum scroll, crosshair
// ═══════════════════════════════════════════════════════════════════════════════

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

class _TradingChartState extends State<TradingChart>
    with SingleTickerProviderStateMixin {
  // Viewport state
  double _scale = 1.0;
  double _targetScale = 1.0;
  double _offsetX = 0.0; // in candle units (fractional)
  double _targetOffsetX = 0.0;

  // Crosshair
  int? _crosshairCandleIndex;
  Offset? _crosshairScreenPos;
  bool _crosshairLocked = false;

  // Animation
  late AnimationController _animController;
  Animation<double>? _scaleAnim;
  Animation<double>? _offsetAnim;

  static const int _baseVisible = 60;
  static const double _minScale = 0.5;
  static const double _maxScale = 12.0;

  // Gesture state
  double _lastScale = 1.0;
  double _dragStartX = 0;
  double _dragStartOffset = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  int get _totalCandles => widget.candles.length;

  int get _visibleCount {
    final raw = (_baseVisible / _scale).round();
    return max(5, min(raw, _totalCandles));
  }

  double get _leftIndex {
    final raw = _offsetX;
    return max(0.0, min(raw, (_totalCandles - _visibleCount).toDouble()));
  }

  double get _rightIndex => _leftIndex + _visibleCount;

  void _clampOffset() {
    final maxOff = max(0.0, (_totalCandles - _visibleCount).toDouble());
    _offsetX = _offsetX.clamp(-_visibleCount * 0.3, maxOff + _visibleCount * 0.3);
  }

  void _clampTarget() {
    final maxOff = max(0.0, (_totalCandles - _visibleCount).toDouble());
    _targetOffsetX = _targetOffsetX.clamp(0.0, maxOff);
  }

  void _animateToState() {
    _animController.removeListener(_onAnimTick);
    _animController.reset();

    _scaleAnim = Tween<double>(begin: _scale, end: _targetScale);
    _offsetAnim = Tween<double>(begin: _offsetX, end: _targetOffsetX);

    _animController.addListener(_onAnimTick);
    _animController.forward();
  }

  void _onAnimTick() {
    if (_scaleAnim != null && _offsetAnim != null) {
      setState(() {
        _scale = _scaleAnim!.value;
        _offsetX = _offsetAnim!.value;
        _clampOffset();
      });
    }
  }

  // ── Touch-to-candle mapping ──────────────────────────────────────────────

  int _screenXToCandleIndex(double screenX, double chartWidth) {
    final candleWidth = chartWidth / _visibleCount;
    final idx = (screenX / candleWidth) + _leftIndex;
    return idx.round().clamp(0, _totalCandles - 1);
  }

  // ── Build ────────────────────────────────────────────────────────────────

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
          final chartWidth = constraints.maxWidth;
          final chartHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : widget.height;

          return GestureDetector(
            // ── Horizontal drag (scroll) ──
            onHorizontalDragStart: (d) {
              _dragStartX = d.localPosition.dx;
              _dragStartOffset = _offsetX;
              _crosshairLocked = false;
            },
            onHorizontalDragUpdate: (d) {
              final dx = d.localPosition.dx - _dragStartX;
              final candleWidth = chartWidth / _visibleCount;
              final deltaCandles = -dx / candleWidth;
              setState(() {
                _offsetX = _dragStartOffset + deltaCandles;
                _clampOffset();
                _crosshairCandleIndex =
                    _screenXToCandleIndex(d.localPosition.dx, chartWidth);
                _crosshairScreenPos = d.localPosition;
              });
            },
            onHorizontalDragEnd: (d) {
              // Momentum
              final vx = d.primaryVelocity ?? 0;
              final candleWidth = chartWidth / _visibleCount;
              final velCandles = -vx / candleWidth / 1000 * 16;
              _targetOffsetX = _offsetX + velCandles * 16;
              _targetScale = _scale;
              _clampTarget();
              _animateToState();
            },

            // ── Pinch zoom ──
            onScaleStart: (d) {
              if (d.pointerCount == 2) {
                _lastScale = _scale;
                _crosshairLocked = true;
              }
            },
            onScaleUpdate: (d) {
              if (d.pointerCount == 2) {
                final newScale =
                    (_lastScale * d.scale).clamp(_minScale, _maxScale);
                // Zoom toward center of pinch
                final centerX = d.focalPoint.dx;
                final candleWidth = chartWidth / _visibleCount;
                final centerCandleIdx =
                    (centerX / candleWidth) + _leftIndex;

                final newVisible = max(5, (_baseVisible / newScale).round());
                final newLeftIdx = centerCandleIdx - centerX / (chartWidth / newVisible);

                setState(() {
                  _scale = newScale;
                  _targetScale = newScale;
                  _offsetX = newLeftIdx;
                  _clampOffset();
                });
              } else if (d.pointerCount == 1) {
                // Single finger: crosshair tracking
                setState(() {
                  _crosshairCandleIndex =
                      _screenXToCandleIndex(d.localPosition.dx, chartWidth);
                  _crosshairScreenPos = d.localPosition;
                });
              }
            },

            // ── Double tap: reset zoom ──
            onDoubleTap: () {
              _targetScale = 1.0;
              _targetOffsetX = max(
                  0.0,
                  (_totalCandles - _baseVisible).toDouble());
              _animateToState();
              setState(() {
                _crosshairCandleIndex = null;
                _crosshairScreenPos = null;
              });
            },

            // ── Long press: lock crosshair ──
            onLongPressStart: (d) {
              setState(() {
                _crosshairLocked = true;
                _crosshairCandleIndex =
                    _screenXToCandleIndex(d.localPosition.dx, chartWidth);
                _crosshairScreenPos = d.localPosition;
              });
            },
            onLongPressMoveUpdate: (d) {
              setState(() {
                _crosshairCandleIndex =
                    _screenXToCandleIndex(d.localPosition.dx, chartWidth);
                _crosshairScreenPos = d.localPosition;
              });
            },
            onLongPressEnd: (_) {
              setState(() {
                _crosshairLocked = false;
                _crosshairCandleIndex = null;
                _crosshairScreenPos = null;
              });
            },

            child: CustomPaint(
              painter: _ChartPainter(
                candles: widget.candles,
                leftIndex: _leftIndex,
                visibleCount: _visibleCount,
                bullColor: widget.bullColor,
                bearColor: widget.bearColor,
                crosshairIndex: _crosshairLocked ? _crosshairCandleIndex : null,
                crosshairScreenX:
                    _crosshairLocked ? _crosshairScreenPos?.dx : null,
              ),
              size: Size(chartWidth, chartHeight),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CustomPainter — renders candles, volume, MAs, grid, crosshair
// ═══════════════════════════════════════════════════════════════════════════════

class _ChartPainter extends CustomPainter {
  final List<CandleData> candles;
  final double leftIndex;
  final int visibleCount;
  final Color bullColor;
  final Color bearColor;
  final int? crosshairIndex;
  final double? crosshairScreenX;

  _ChartPainter({
    required this.candles,
    required this.leftIndex,
    required this.visibleCount,
    required this.bullColor,
    required this.bearColor,
    this.crosshairIndex,
    this.crosshairScreenX,
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
    final bodyW = max(1.5, candleW * 0.6);

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
          Rect.fromLTWH(bx, by, bodyW, bh),
          Paint()
            ..color = (c.isBullish ? bullColor : bearColor).withOpacity(0.22)
            ..style = PaintingStyle.fill);
    }

    // ── X-axis date labels ───────────────────────────────────────────────
    final step = max(1, visibleCount ~/ 6);
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    for (int i = 0; i < visible.length; i += step) {
      final d = visible[i].time;
      final label = '${months[d.month - 1]} ${d.day}';
      final x = (i - localLeft) * candleW;
      _drawText(canvas, label, Offset(x + 2, priceH - 10),
          const Color(0xFF64748B), 9);
    }

    // ── Candlesticks ─────────────────────────────────────────────────────
    double p2y(double p) => priceH * (1.0 - (p - yMin) / yRange);

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
      final bh = max(1.0, bot - top);
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
    _drawMA(canvas, visible, startIdx, localLeft, candleW, priceH, yMin, yRange,
        7, const Color(0xFFFFAB40));
    _drawMA(canvas, visible, startIdx, localLeft, candleW, priceH, yMin, yRange,
        9, const Color(0xFF42A5F5), ema: true);
    _drawMA(canvas, visible, startIdx, localLeft, candleW, priceH, yMin, yRange,
        25, const Color(0xFFAB47BC));

    // ── MA Legend ─────────────────────────────────────────────────────────
    double lx = 8;
    for (final (label, col) in [
      ('SMA7', const Color(0xFFFFAB40)),
      ('EMA9', const Color(0xFF42A5F5)),
      ('SMA25', const Color(0xFFAB47BC)),
    ]) {
      final dp = Paint()..color = col..strokeWidth = 2;
      canvas.drawLine(Offset(lx, 10), Offset(lx + 14, 10), dp);
      _drawText(canvas, ' $label', Offset(lx + 16, 3), col, 9, bold: false);
      lx += 52;
    }

    // ── Crosshair ────────────────────────────────────────────────────────
    if (crosshairIndex != null && crosshairIndex! >= startIdx && crosshairIndex! < endIdx) {
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

      // Price tag
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
  }

  // ── Helpers ────────────────────────────────────────────────────────────

  void _drawMA(Canvas canvas, List<CandleData> visible, int startIdx,
      double localLeft, double candleW, double priceH, double yMin,
      double yRange, int period, Color color, {bool ema = false}) {
    // Compute MA on the full visible + buffer slice
    final bufStart = max(0, startIdx - period);
    final bufEnd = min(candles.length, startIdx + visible.length + 2);
    final buf = candles.sublist(bufStart, bufEnd);

    List<double> vals;
    if (ema) {
      vals = _ema(buf, period);
    } else {
      vals = _sma(buf, period);
    }

    final path = Path();
    bool started = false;
    for (int i = 0; i < visible.length; i++) {
      final globalI = startIdx + i;
      final bufI = globalI - bufStart;
      if (bufI < 0 || bufI >= vals.length || vals[bufI].isNaN) continue;
      final x = (i - localLeft + 0.5) * candleW;
      final y = priceH * (1.0 - (vals[bufI] - yMin) / yRange);
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
// Sample data generator (used by atomic_swaps_screen and demo)
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
