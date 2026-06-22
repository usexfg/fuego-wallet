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
    this.height = 400,
    this.bullColor = const Color(0xFF26A69A),
    this.bearColor = const Color(0xFFEF5350),
  });

  @override
  State<TradingChart> createState() => _TradingChartState();
}

class _TradingChartState extends State<TradingChart> {
  int? _touchIndex;
  double _scale = 1.0;
  int _scrollOffset = 0;
  static const int _baseVisibleCount = 80;

  List<CandleData> get _visibleCandles {
    final total = widget.candles.length;
    if (total == 0) return [];
    final visible = max(10, (_baseVisibleCount / _scale).round());
    final clampedVisible = min(visible, total);
    final end = total - _scrollOffset;
    final start = max(0, end - clampedVisible);
    return widget.candles.sublist(start, end);
  }

  List<double> _computeSMA(List<CandleData> candles, int period) {
    final result = <double>[];
    for (int i = 0; i < candles.length; i++) {
      if (i < period - 1) {
        result.add(double.nan);
      } else {
        double sum = 0;
        for (int j = i - period + 1; j <= i; j++) {
          sum += candles[j].close;
        }
        result.add(sum / period);
      }
    }
    return result;
  }

  List<double> _computeEMA(List<CandleData> candles, int period) {
    final result = <double>[];
    if (candles.isEmpty) return result;
    double ema = candles[0].close;
    final multiplier = 2.0 / (period + 1);
    for (int i = 0; i < candles.length; i++) {
      if (i < period - 1) {
        double sum = 0;
        for (int j = 0; j <= i; j++) sum += candles[j].close;
        ema = sum / (i + 1);
        result.add(double.nan);
      } else {
        ema = (candles[i].close - ema) * multiplier + ema;
        result.add(ema);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleCandles;
    if (visible.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(child: Text('No data', style: TextStyle(color: Color(0xFF6B6B6B)))),
      );
    }

    final maxPrice = visible.map((c) => c.high).reduce(max);
    final minPrice = visible.map((c) => c.low).reduce(min);
    final pricePad = (maxPrice - minPrice) * 0.08;
    final yMin = minPrice - pricePad;
    final yMax = maxPrice + pricePad;
    final maxVolume = visible.map((c) => c.volume).reduce(max);

    final sma7 = _computeSMA(visible, 7);
    final ema9 = _computeEMA(visible, 9);
    final sma25 = _computeSMA(visible, 25);

    final allCandles = widget.candles;
    final visibleStart = allCandles.indexOf(visible.first);

    return SizedBox(
      height: widget.height,
      child: GestureDetector(
        onScaleUpdate: (details) {
          setState(() {
            _scale = (_scale * details.scale).clamp(0.3, 8.0);
            final total = widget.candles.length;
            final vis = max(10, (_baseVisibleCount / _scale).round());
            final maxOff = max(0, total - vis);
            _scrollOffset = (_scrollOffset - (details.focalPointDelta.dx * vis / 300).round())
                .clamp(0, maxOff);
          });
        },
        onLongPressStart: (d) => _handleTouch(d.localPosition, visible),
        onLongPressMoveUpdate: (d) => _handleTouch(d.localPosition, visible),
        onLongPressEnd: (_) => setState(() => _touchIndex = null),
        child: CustomPaint(
          painter: _ChartPainter(
            candles: visible,
            visibleStart: visibleStart,
            sma7: sma7,
            ema9: ema9,
            sma25: sma25,
            yMin: yMin,
            yMax: yMax,
            maxVolume: maxVolume,
            bullColor: widget.bullColor,
            bearColor: widget.bearColor,
            touchIndex: _touchIndex,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }

  void _handleTouch(Offset localPos, List<CandleData> visible) {
    final w = context.size?.width ?? 300;
    final candleW = w / visible.length;
    final idx = (localPos.dx / candleW).floor().clamp(0, visible.length - 1);
    setState(() => _touchIndex = idx);
  }
}

class _ChartPainter extends CustomPainter {
  final List<CandleData> candles;
  final int visibleStart;
  final List<double> sma7;
  final List<double> ema9;
  final List<double> sma25;
  final double yMin;
  final double yMax;
  final double maxVolume;
  final Color bullColor;
  final Color bearColor;
  final int? touchIndex;

  _ChartPainter({
    required this.candles,
    required this.visibleStart,
    required this.sma7,
    required this.ema9,
    required this.sma25,
    required this.yMin,
    required this.yMax,
    required this.maxVolume,
    required this.bullColor,
    required this.bearColor,
    this.touchIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final priceAreaHeight = size.height * 0.72;
    final volumeAreaHeight = size.height * 0.18;
    final volumeTop = priceAreaHeight + size.height * 0.04;
    final priceRange = yMax - yMin;
    if (priceRange <= 0 || candles.isEmpty) return;

    final candleW = size.width / candles.length;
    final bodyW = max(1.0, candleW * 0.65);

    // --- Grid ---
    final gridPaint = Paint()..color = const Color(0xFF1E293B)..strokeWidth = 0.5;
    for (int i = 0; i <= 5; i++) {
      final y = priceAreaHeight * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // --- Y-axis price labels ---
    for (int i = 0; i <= 5; i++) {
      final y = priceAreaHeight * i / 5;
      final price = yMax - (priceRange * i / 5);
      final label = _fmtPrice(price);
      final tp = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y + 2));
    }

    // --- Volume bars ---
    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final volRatio = maxVolume > 0 ? c.volume / maxVolume : 0.0;
      final barH = volRatio * volumeAreaHeight;
      final barX = i * candleW + (candleW - bodyW) / 2;
      final barY = volumeTop + volumeAreaHeight - barH;
      final volPaint = Paint()
        ..color = (c.isBullish ? bullColor : bearColor).withOpacity(0.25)
        ..style = PaintingStyle.fill;
      canvas.drawRect(Rect.fromLTWH(barX, barY, bodyW, barH), volPaint);
    }

    // --- X-axis date labels ---
    final dateStep = max(1, candles.length ~/ 5);
    for (int i = 0; i < candles.length; i += dateStep) {
      final d = candles[i].time;
      final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final label = '${months[d.month - 1]} ${d.day}';
      final tp = TextPainter(
        text: TextSpan(text: label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 9)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(i * candleW + 2, priceAreaHeight - 12));
    }

    // --- Candlesticks ---
    for (int i = 0; i < candles.length; i++) {
      final c = candles[i];
      final x = i * candleW + candleW / 2;
      final color = c.isBullish ? bullColor : bearColor;

      double priceToY(double p) => priceAreaHeight * (1.0 - (p - yMin) / priceRange);

      final highY = priceToY(c.high);
      final lowY = priceToY(c.low);
      final bodyTop = priceToY(max(c.open, c.close));
      final bodyBottom = priceToY(min(c.open, c.close));

      // Wick
      canvas.drawLine(Offset(x, highY), Offset(x, lowY), Paint()..color = color..strokeWidth = 1.0);

      // Body
      final bodyH = max(1.0, bodyBottom - bodyTop);
      final bodyRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, (bodyTop + bodyBottom) / 2), width: bodyW, height: bodyH),
        const Radius.circular(1),
      );
      final bodyPaint = Paint()..color = color;
      if (c.isBullish) {
        bodyPaint.style = PaintingStyle.stroke;
        bodyPaint.strokeWidth = 1.2;
      } else {
        bodyPaint.style = PaintingStyle.fill;
      }
      canvas.drawRRect(bodyRect, bodyPaint);
    }

    // --- Moving Averages ---
    _drawMA(canvas, sma7, visibleStart, candleW, priceAreaHeight, priceRange, const Color(0xFFFFAB40));
    _drawMA(canvas, ema9, visibleStart, candleW, priceAreaHeight, priceRange, const Color(0xFF42A5F5));
    _drawMA(canvas, sma25, visibleStart, candleW, priceAreaHeight, priceRange, const Color(0xFFAB47BC));

    // --- MA Legend ---
    final legends = [
      ('SMA7', const Color(0xFFFFAB40)),
      ('EMA9', const Color(0xFF42A5F5)),
      ('SMA25', const Color(0xFFAB47BC)),
    ];
    double lx = 8;
    for (final (label, color) in legends) {
      final dp = Paint()..color = color..strokeWidth = 2;
      canvas.drawLine(Offset(lx, 8), Offset(lx + 14, 8), dp);
      final tp = TextPainter(
        text: TextSpan(text: ' $label', style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w500)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lx + 16, 1));
      lx += tp.width + 22;
    }

    // --- Crosshair ---
    if (touchIndex != null && touchIndex! < candles.length) {
      final c = candles[touchIndex!];
      final x = touchIndex! * candleW + candleW / 2;
      final crossPaint = Paint()..color = const Color(0x50FFFFFF)..strokeWidth = 0.8;

      // Vertical line
      canvas.drawLine(Offset(x, 0), Offset(x, priceAreaHeight), crossPaint);

      // Horizontal line at close price
      final closeY = priceAreaHeight * (1.0 - (c.close - yMin) / priceRange);
      canvas.drawLine(Offset(0, closeY), Offset(size.width, closeY), crossPaint);

      // Price tag on right
      final tagPaint = Paint()..color = c.isBullish ? bullColor : bearColor;
      final tagRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width - 52, closeY - 10, 50, 20),
        const Radius.circular(4),
      );
      canvas.drawRRect(tagRect, tagPaint);
      final priceTp = TextPainter(
        text: TextSpan(
          text: _fmtPrice(c.close),
          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      priceTp.paint(canvas, Offset(size.width - 50, closeY - 6));

      // OHLCV tooltip box
      final boxW = 130.0;
      final boxH = 90.0;
      final boxX = x + 16 > size.width - boxW ? x - boxW - 16 : x + 16;
      final boxY = max(8.0, min(closeY - boxH / 2, priceAreaHeight - boxH - 8));

      final boxPaint = Paint()..color = const Color(0xF0111827);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(boxX, boxY, boxW, boxH), const Radius.circular(8)),
        boxPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(boxX, boxY, boxW, boxH), const Radius.circular(8)),
        Paint()..color = const Color(0xFF334155)..style = PaintingStyle.stroke..strokeWidth = 1,
      );

      final dateStr = '${c.time.month}/${c.time.day}/${c.time.year}';
      final lines = [
        ('Date: ', dateStr, const Color(0xFF94A3B8)),
        ('O: ', _fmtPrice(c.open), const Color(0xFF94A3B8)),
        ('H: ', _fmtPrice(c.high), const Color(0xFF94A3B8)),
        ('L: ', _fmtPrice(c.low), const Color(0xFF94A3B8)),
        ('C: ', _fmtPrice(c.close), c.isBullish ? bullColor : bearColor),
        ('Vol: ', _fmtVol(c.volume), const Color(0xFF94A3B8)),
      ];
      double ty = boxY + 8;
      for (final (lbl, val, col) in lines) {
        final tp = TextPainter(
          text: TextSpan(children: [
            TextSpan(text: lbl, style: const TextStyle(color: Color(0xFF64748B), fontSize: 10)),
            TextSpan(text: val, style: TextStyle(color: col, fontSize: 10, fontWeight: FontWeight.w600)),
          ]),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(boxX + 8, ty));
        ty += 13;
      }
    }
  }

  void _drawMA(Canvas canvas, List<double> values, int globalStart, double candleW, double chartH, double priceRange, Color color) {
    final path = Path();
    bool started = false;
    for (int i = 0; i < candles.length; i++) {
      final gIdx = globalStart + i;
      if (gIdx >= values.length || values[gIdx].isNaN) continue;
      final x = i * candleW + candleW / 2;
      final y = chartH * (1.0 - (values[gIdx] - yMin) / priceRange);
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, Paint()..color = color..strokeWidth = 1.5..style = PaintingStyle.stroke);
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
  bool shouldRepaint(covariant _ChartPainter old) => old.touchIndex != touchIndex;
}

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
