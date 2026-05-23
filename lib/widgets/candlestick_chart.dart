import 'dart:math';
import 'package:flutter/material.dart';

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
  final Color volumeBullColor;
  final Color volumeBearColor;

  const TradingChart({
    super.key,
    required this.candles,
    this.height = 320,
    this.bullColor = const Color(0xFFFF3B2F),
    this.bearColor = const Color(0xFF2E8BC0),
    this.volumeBullColor = const Color(0x33FF3B2F),
    this.volumeBearColor = const Color(0x332E8BC0),
  });

  @override
  State<TradingChart> createState() => _TradingChartState();
}

class _TradingChartState extends State<TradingChart> {
  String _selectedTimeframe = '1H';
  int _visibleCount = 30;
  double? _crosshairX;
  double? _crosshairY;
  int? _crosshairIndex;
  Offset? _touchPosition;
  bool _showCrosshair = false;

  final Map<String, int> _timeframeLimits = {
    '15m': 40,
    '1H': 30,
    '4H': 24,
    '1D': 20,
    '1W': 12,
  };

  @override
  Widget build(BuildContext context) {
    final candles = widget.candles.length > _visibleCount
        ? widget.candles.sublist(widget.candles.length - _visibleCount)
        : widget.candles;

    if (candles.isEmpty) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: Text('No chart data', style: TextStyle(color: Color(0xFF6B6B6B))),
        ),
      );
    }

    final maxPrice = candles.map((c) => c.high).reduce(max);
    final minPrice = candles.map((c) => c.low).reduce(min);
    final maxVolume = candles.map((c) => c.volume).reduce(max);

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onPanStart: (d) => _updateCrosshair(d.localPosition, candles),
            onPanUpdate: (d) => _updateCrosshair(d.localPosition, candles),
            onPanEnd: (_) => setState(() => _showCrosshair = false),
            onLongPressStart: (d) {
              setState(() => _showCrosshair = true);
              _updateCrosshair(d.localPosition, candles);
            },
            onLongPressMoveUpdate: (d) => _updateCrosshair(d.localPosition, candles),
            onLongPressEnd: (_) => setState(() => _showCrosshair = false),
            child: CustomPaint(
              painter: _CandlestickPainter(
                candles: candles,
                maxPrice: maxPrice,
                minPrice: minPrice,
                maxVolume: maxVolume,
                bullColor: widget.bullColor,
                bearColor: widget.bearColor,
                volumeBullColor: widget.volumeBullColor,
                volumeBearColor: widget.volumeBearColor,
                crosshairX: _crosshairX,
                crosshairY: _crosshairY,
                crosshairIndex: _crosshairIndex,
                showCrosshair: _showCrosshair,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        _buildTimeframeSelector(),
      ],
    );
  }

  void _updateCrosshair(Offset position, List<CandleData> candles) {
    final chartWidth = context.size?.width ?? 300;
    final candleWidth = chartWidth / candles.length;
    final index = (position.dx / candleWidth).floor().clamp(0, candles.length - 1);
    final candle = candles[index];

    setState(() {
      _showCrosshair = true;
      _crosshairX = position.dx;
      _crosshairY = position.dy;
      _crosshairIndex = index;
      _touchPosition = position;
    });
  }

  Widget _buildTimeframeSelector() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _timeframeLimits.keys.map((tf) {
          final isSelected = _selectedTimeframe == tf;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedTimeframe = tf;
                _visibleCount = _timeframeLimits[tf]!;
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFF6B35).withOpacity(0.2)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: isSelected
                    ? Border.all(color: const Color(0xFFFF6B35).withOpacity(0.5))
                    : Border.all(color: const Color(0xFF6B6B6B).withOpacity(0.2)),
              ),
              child: Text(
                tf,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFFFF6B35)
                      : const Color(0xFF6B6B6B),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CandlestickPainter extends CustomPainter {
  final List<CandleData> candles;
  final double maxPrice;
  final double minPrice;
  final double maxVolume;
  final Color bullColor;
  final Color bearColor;
  final Color volumeBullColor;
  final Color volumeBearColor;
  final double? crosshairX;
  final double? crosshairY;
  final int? crosshairIndex;
  final bool showCrosshair;

  _CandlestickPainter({
    required this.candles,
    required this.maxPrice,
    required this.minPrice,
    required this.maxVolume,
    required this.bullColor,
    required this.bearColor,
    required this.volumeBullColor,
    required this.volumeBearColor,
    this.crosshairX,
    this.crosshairY,
    this.crosshairIndex,
    this.showCrosshair = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final chartArea = size.height * 0.75;
    final volumeArea = size.height - chartArea;
    final priceRange = maxPrice - minPrice;
    final candleWidth = size.width / candles.length;
    final gridColor = const Color(0xFF2A2A35);

    _drawGrid(canvas, size, chartArea, gridColor);

    for (int i = 0; i < candles.length; i++) {
      final candle = candles[i];
      final x = i * candleWidth;

      _drawCandle(canvas, candle, x, candleWidth, chartArea, priceRange);

      if (maxVolume > 0) {
        _drawVolume(canvas, candle, x, candleWidth, chartArea, volumeArea);
      }
    }

    if (showCrosshair && crosshairX != null) {
      _drawCrosshair(canvas, size, chartArea);
    }
  }

  void _drawGrid(Canvas canvas, Size size, double chartArea, Color gridColor) {
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    final priceSteps = 6;
    for (int i = 0; i <= priceSteps; i++) {
      final y = chartArea * i / priceSteps;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final timeSteps = 5;
    for (int i = 0; i <= timeSteps; i++) {
      final x = size.width * i / timeSteps;
      canvas.drawLine(Offset(x, 0), Offset(x, chartArea), gridPaint);
    }
  }

  void _drawCandle(Canvas canvas, CandleData candle, double x,
      double candleWidth, double chartArea, double priceRange) {
    final isBullish = candle.isBullish;
    final color = isBullish ? bullColor : bearColor;
    final bodyWidth = candleWidth * 0.65;
    final halfBody = bodyWidth / 2;
    final centerX = x + candleWidth / 2;

    final bodyTop = chartArea - ((candle.close - minPrice) / priceRange * chartArea);
    final bodyBottom = chartArea - ((candle.open - minPrice) / priceRange * chartArea);
    final highY = chartArea - ((candle.high - minPrice) / priceRange * chartArea);
    final lowY = chartArea - ((candle.low - minPrice) / priceRange * chartArea);

    final wickPaint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(centerX, highY),
      Offset(centerX, lowY),
      wickPaint,
    );

    final bodyRect = Rect.fromLTRB(
      centerX - halfBody,
      bodyTop.clamp(0, chartArea),
      centerX + halfBody,
      bodyBottom.clamp(0, chartArea),
    );

    final bodyPaint = Paint()
      ..color = isBullish ? color : color
      ..style = PaintingStyle.fill;

    canvas.drawRect(bodyRect, bodyPaint);

    if (isBullish) {
      canvas.drawRect(
        bodyRect,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 0.5,
      );
    }
  }

  void _drawVolume(Canvas canvas, CandleData candle, double x,
      double candleWidth, double chartArea, double volumeArea) {
    final volumeRatio = maxVolume > 0 ? candle.volume / maxVolume : 0.1;
    final barHeight = volumeRatio * volumeArea;
    final barWidth = candleWidth * 0.5;
    final barX = x + (candleWidth - barWidth) / 2;
    final barY = chartArea + (volumeArea - barHeight);

    final paint = Paint()
      ..color = candle.isBullish ? volumeBullColor : volumeBearColor
      ..style = PaintingStyle.fill;

    final barRect = Rect.fromLTRB(barX, barY, barX + barWidth, barY + barHeight);
    canvas.drawRect(barRect, paint);
  }

  void _drawCrosshair(Canvas canvas, Size size, double chartArea) {
    final paint = Paint()
      ..color = const Color(0x80FFFFFF)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final dashPaint = Paint()
      ..color = const Color(0x30FFFFFF)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset(crosshairX!, 0),
      Offset(crosshairX!, chartArea),
      dashPaint,
    );

    canvas.drawLine(
      Offset(0, crosshairY!),
      Offset(size.width, crosshairY!),
      dashPaint,
    );

    if (crosshairIndex != null && crosshairIndex! < candles.length) {
      final candle = candles[crosshairIndex!];
      final isBullish = candle.isBullish;
      final color = isBullish ? bullColor : bearColor;

      final tooltipPaint = Paint()
        ..color = const Color(0xDD1A1B23);
      final tooltipRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(crosshairX!, crosshairY! - 30),
          width: 120,
          height: 60,
        ),
        const Radius.circular(8),
      );
      canvas.drawRRect(tooltipRect, tooltipPaint);
      canvas.drawRRect(
        tooltipRect,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 1,
      );

      final textPainter = TextPainter(
        text: TextSpan(
          children: [
            TextSpan(
              text: 'O: ${candle.open.toStringAsFixed(4)}\n',
              style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 10, fontFamily: 'monospace'),
            ),
            TextSpan(
              text: 'H: ${candle.high.toStringAsFixed(4)}\n',
              style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 10, fontFamily: 'monospace'),
            ),
            TextSpan(
              text: 'L: ${candle.low.toStringAsFixed(4)}\n',
              style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 10, fontFamily: 'monospace'),
            ),
            TextSpan(
              text: 'C: ${candle.close.toStringAsFixed(4)}',
              style: TextStyle(color: isBullish ? const Color(0xFFFF3B2F) : const Color(0xFF2E8BC0), fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.w600),
            ),
          ],
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.left,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(crosshairX! - 50, crosshairY! - 50),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CandlestickPainter oldDelegate) {
    return oldDelegate.crosshairX != crosshairX ||
        oldDelegate.crosshairY != crosshairY ||
        oldDelegate.showCrosshair != showCrosshair ||
        oldDelegate.maxPrice != maxPrice ||
        oldDelegate.minPrice != minPrice;
  }
}

List<CandleData> generateSampleCandles(double basePrice, int count) {
  final random = Random(42);
  final candles = <CandleData>[];
  double price = basePrice;
  final now = DateTime.now();

  for (int i = 0; i < count; i++) {
    final volatility = basePrice * 0.03;
    final open = price;
    final change = (random.nextDouble() - 0.5) * volatility * 2;
    final close = (open + change).clamp(basePrice * 0.7, basePrice * 1.3);
    final high = max(open, close) + random.nextDouble() * volatility;
    final low = min(open, close) - random.nextDouble() * volatility;

    candles.add(CandleData(
      open: open,
      high: high,
      low: low.clamp(0, double.infinity),
      close: close,
      volume: random.nextDouble() * basePrice * 100,
      time: now.subtract(Duration(hours: count - i)),
    ));
    price = close;
  }

  return candles;
}
