import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';

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
  double? _touchX;
  double? _touchY;
  bool _showCrosshair = false;
  double _scale = 1.0;
  int _scrollOffset = 0;
  static const int _baseVisibleCount = 60;

  List<CandleData> get _visibleCandles {
    final total = widget.candles.length;
    if (total == 0) return [];
    final visible = max(10, (_baseVisibleCount / _scale).round());
    final clampedVisible = min(visible, total);
    final end = total - _scrollOffset;
    final start = max(0, end - clampedVisible);
    return widget.candles.sublist(start, end);
  }

  List<double> _computeSMA(int period) {
    final candles = widget.candles;
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

  List<double> _computeEMA(int period) {
    final candles = widget.candles;
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
        child: const Center(
          child: Text('No data', style: TextStyle(color: Color(0xFF6B6B6B))),
        ),
      );
    }

    final allCandles = widget.candles;
    final visibleStart = allCandles.indexOf(visible.first);
    final sma7 = _computeSMA(7);
    final sma25 = _computeSMA(25);
    final ema9 = _computeEMA(9);

    final maxPrice = visible.map((c) => c.high).reduce(max);
    final minPrice = visible.map((c) => c.low).reduce(min);
    final pricePadding = (maxPrice - minPrice) * 0.08;
    final yMin = minPrice - pricePadding;
    final yMax = maxPrice + pricePadding;
    final maxVolume = visible.map((c) => c.volume).reduce(max);

    // Build bar data for volume
    final volumeBars = <BarChartGroupData>[];
    for (int i = 0; i < visible.length; i++) {
      final candle = visible[i];
      final volRatio = maxVolume > 0 ? candle.volume / maxVolume : 0;
      volumeBars.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: volRatio,
            width: max(1.0, 8.0 * (300 / visible.length)),
            color: candle.isBullish
                ? widget.bullColor.withOpacity(0.3)
                : widget.bearColor.withOpacity(0.3),
          ),
        ],
      ));
    }

    // Build SMA/EMA line data
    List<FlSpot> sma7Spots = [];
    List<FlSpot> sma25Spots = [];
    List<FlSpot> ema9Spots = [];
    for (int i = 0; i < visible.length; i++) {
      final globalIdx = visibleStart + i;
      if (globalIdx < sma7.length && !sma7[globalIdx].isNaN) {
        sma7Spots.add(FlSpot(i.toDouble(), sma7[globalIdx]));
      }
      if (globalIdx < sma25.length && !sma25[globalIdx].isNaN) {
        sma25Spots.add(FlSpot(i.toDouble(), sma25[globalIdx]));
      }
      if (globalIdx < ema9.length && !ema9[globalIdx].isNaN) {
        ema9Spots.add(FlSpot(i.toDouble(), ema9[globalIdx]));
      }
    }

    // Build candle bar data (using scatter for candles)
    final scatterDots = <FlSpot>[];
    final scatterSpots = <ScatterSpot>[];
    for (int i = 0; i < visible.length; i++) {
      final c = visible[i];
      final color = c.isBullish ? widget.bullColor : widget.bearColor;
      scatterSpots.add(ScatterSpot(
        i.toDouble(),
        c.close,
        dotPainter: _CandleDotPainter(
          open: c.open,
          close: c.close,
          high: c.high,
          low: c.low,
          color: color,
          yMin: yMin,
          yMax: yMax,
        ),
      ));
    }

    final chartHeight = widget.height * 0.65;
    final volumeHeight = widget.height * 0.2;

    return SizedBox(
      height: widget.height,
      child: Column(
        children: [
          SizedBox(
            height: chartHeight,
            child: GestureDetector(
              onScaleStart: (details) {},
              onScaleUpdate: (details) {
                setState(() {
                  _scale = (_scale * details.scale).clamp(0.3, 5.0);
                  final total = widget.candles.length;
                  final visible = max(10, (_baseVisibleCount / _scale).round());
                  final maxOffset = max(0, total - visible);
                  _scrollOffset = (_scrollOffset - (details.focalPointDelta.dx * visible / 300).round())
                      .clamp(0, maxOffset);
                });
              },
              onLongPressStart: (d) => _handleTouch(d.localPosition, visible, visibleStart, yMin, yMax, chartHeight),
              onLongPressMoveUpdate: (d) => _handleTouch(d.localPosition, visible, visibleStart, yMin, yMax, chartHeight),
              onLongPressEnd: (_) => setState(() { _showCrosshair = false; _touchIndex = null; }),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 48, right: 8, top: 8, bottom: 4),
                    child: ScatterChart(
                      ScatterChartData(
                        scatterSpots: scatterSpots,
                        minX: -0.5,
                        maxX: visible.length - 0.5,
                        minY: yMin,
                        maxY: yMax,
                        borderData: FlBorderData(show: false),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: (yMax - yMin) / 5,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: const Color(0xFF1E293B),
                            strokeWidth: 0.5,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: AxisTitles(sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 48,
                            interval: (yMax - yMin) / 5,
                            getTitlesWidget: (value, meta) {
                              return Padding(
                                padding: const EdgeInsets.only(left: 4),
                                child: Text(
                                  _formatPrice(value),
                                  style: GoogleFonts.jetBrainsMono(
                                    color: const Color(0xFF64748B),
                                    fontSize: 9,
                                  ),
                                ),
                              );
                            },
                          )),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 16,
                            interval: max(1, visible.length / 4).toDouble(),
                            getTitlesWidget: (value, meta) {
                              final idx = value.round();
                              if (idx < 0 || idx >= visible.length) return const SizedBox.shrink();
                              final d = visible[idx].time;
                              final months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                              return Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${months[d.month - 1]} ${d.day}',
                                  style: GoogleFonts.jetBrainsMono(
                                    color: const Color(0xFF64748B),
                                    fontSize: 9,
                                  ),
                                ),
                              );
                            },
                          )),
                        ),
                        scatterTouchData: ScatterTouchData(enabled: false),
                      ),
                    ),
                  ),
                  // MA Legend
                  Positioned(
                    top: 8,
                    left: 52,
                    child: Row(
                      children: [
                        _MALegend(label: 'SMA7', color: const Color(0xFFFFAB40)),
                        const SizedBox(width: 8),
                        _MALegend(label: 'EMA9', color: const Color(0xFF42A5F5)),
                        const SizedBox(width: 8),
                        _MALegend(label: 'SMA25', color: const Color(0xFFAB47BC)),
                      ],
                    ),
                  ),
                  // Crosshair overlay
                  if (_showCrosshair && _touchIndex != null && _touchIndex! < visible.length)
                    _buildCrosshairTooltip(visible[_touchIndex!], _touchX ?? 0, _touchY ?? 0, chartHeight),
                ],
              ),
            ),
          ),
          // Volume chart
          SizedBox(
            height: volumeHeight,
            child: Padding(
              padding: const EdgeInsets.only(left: 48, right: 8, top: 0, bottom: 4),
              child: BarChart(
                BarChartData(
                  barGroups: volumeBars,
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 1.1,
                  minY: 0,
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  barTouchData: BarTouchData(enabled: false),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTouch(Offset localPos, List<CandleData> visible, int globalStart, double yMin, double yMax, double chartHeight) {
    final chartWidth = MediaQuery.of(context).size.width - 56;
    final candleWidth = chartWidth / visible.length;
    final index = (localPos.dx / candleWidth).floor().clamp(0, visible.length - 1);
    setState(() {
      _showCrosshair = true;
      _touchIndex = index;
      _touchX = localPos.dx;
      _touchY = localPos.dy;
    });
  }

  Widget _buildCrosshairTooltip(CandleData candle, double x, double y, double chartHeight) {
    final bool isRight = x > chartHeight * 0.6;
    return Positioned(
      left: isRight ? null : x + 12,
      right: isRight ? (chartHeight - x + 12) : null,
      top: max(8, min(y - 40, chartHeight - 80)),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xF0111827),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF334155), width: 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 8),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${candle.time.month}/${candle.time.day}/${candle.time.year}',
              style: GoogleFonts.jetBrainsMono(
                color: const Color(0xFF94A3B8),
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            _tooltipRow('O', candle.open, const Color(0xFF94A3B8)),
            _tooltipRow('H', candle.high, const Color(0xFF94A3B8)),
            _tooltipRow('L', candle.low, const Color(0xFF94A3B8)),
            _tooltipRow('C', candle.close, candle.isBullish ? widget.bullColor : widget.bearColor),
            _tooltipRow('Vol', candle.volume, const Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _tooltipRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: GoogleFonts.jetBrainsMono(
              color: const Color(0xFF64748B),
              fontSize: 10,
            ),
          ),
          Text(
            _formatPrice(value),
            style: GoogleFonts.jetBrainsMono(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    if (price >= 1.0) return '\$${price.toStringAsFixed(2)}';
    if (price >= 0.01) return '\$${price.toStringAsFixed(4)}';
    if (price >= 0.0001) return '\$${price.toStringAsFixed(6)}';
    return '\$${price.toStringAsFixed(8)}';
  }
}

class _MALegend extends StatelessWidget {
  final String label;
  final Color color;
  const _MALegend({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 2, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: GoogleFonts.jetBrainsMono(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CandleDotPainter extends ScatterSpotPainter {
  final double open;
  final double close;
  final double high;
  final double low;
  final Color color;
  final double yMin;
  final double yMax;

  _CandleDotPainter({
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.color,
    required this.yMin,
    required this.yMax,
  });

  @override
  void draw(ScatterSpot spot, Canvas canvas, Size size) {
    final chartSize = Size(size.width * 300, size.height * 400);
    final candleWidth = max(1.0, chartSize.width * 0.003);

    final yRange = yMax - yMin;
    if (yRange <= 0) return;

    double priceToY(double price) {
      return chartSize.height * (1.0 - (price - yMin) / yRange);
    }

    final centerX = spot.x * (chartSize.width / max(1, 60));

    final bodyTop = priceToY(max(open, close));
    final bodyBottom = priceToY(min(open, close));
    final highY = priceToY(high);
    final lowY = priceToY(low);

    final wickPaint = Paint()
      ..color = color
      ..strokeWidth = 1.0;

    canvas.drawLine(
      Offset(centerX, highY),
      Offset(centerX, lowY),
      wickPaint,
    );

    final bodyHeight = max(1.0, bodyBottom - bodyTop);
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, (bodyTop + bodyBottom) / 2),
        width: candleWidth,
        height: bodyHeight,
      ),
      const Radius.circular(1),
    );

    final bodyPaint = Paint()..color = color;
    if (open < close) {
      bodyPaint.style = PaintingStyle.stroke;
      bodyPaint.strokeWidth = 1.0;
    } else {
      bodyPaint.style = PaintingStyle.fill;
    }
    canvas.drawRRect(bodyRect, bodyPaint);
  }

  @override
  bool shouldRepaint(covariant _CandleDotPainter oldDelegate) {
    return oldDelegate.open != open ||
        oldDelegate.close != close ||
        oldDelegate.high != high ||
        oldDelegate.low != low ||
        oldDelegate.color != color;
  }
}
