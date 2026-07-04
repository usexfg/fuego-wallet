import 'package:flutter/material.dart';
import 'package:imp_trading_chart/imp_trading_chart.dart';
import '../models/candlestick.dart';

class FuegoChart extends StatelessWidget {
  final List<Candlestick> candles;
  final String pair;
  final double? height;

  const FuegoChart({
    super.key,
    required this.candles,
    this.pair = '',
    this.height,
  });

  static const _bg = Color(0xFF120700);
  static const _fire = Color(0xFFf97316);
  static const _amber = Color(0xFFfbbf24);
  static const _white = Color(0xFFe5d5c0);
  static const _text = Color(0xFFb0a090);
  static const _muted = Color(0xFF8a7a6a);

  static final _fireStyle = ChartStyle(
    backgroundColor: _bg,
    textColor: _text,
    labelFontSize: 10,
    lineStyle: LineChartStyle.smooth(
      color: _fire,
      width: 2.0,
      curveTension: 0.3,
      showGlow: true,
    ),
    currentPriceStyle: CurrentPriceIndicatorStyle.dashed(
      lineColor: _amber,
      bullishColor: _amber,
      bearishColor: _amber,
    ).copyWith(
      textColor: _bg,
      labelFontSize: 10,
    ),
    rippleStyle: RippleAnimationStyle.subtle(color: _fire),
    priceLabelStyle: const PriceLabelStyle(
      color: _muted,
      fontSize: 10,
    ),
    timeLabelStyle: const TimeLabelStyle(
      color: _muted,
      fontSize: 9,
    ),
    axisStyle: const AxisStyle(
      gridColor: Color(0x0DFFFFFF),
      showGrid: true,
    ),
    crosshairStyle: CrosshairStyle.dashed(
      lineColor: _amber,
      lineWidth: 1.0,
    ).copyWith(
      trackerColor: _amber,
      trackerRadius: 4.0,
      showTrackerRing: false,
      labelBackgroundColor: _amber,
      labelTextColor: _bg,
      labelFontSize: 10,
    ),
    layout: const ChartLayout(
      topPadding: 8,
      bottomPadding: 24,
      rightPadding: 56,
      leftPadding: 8,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) return const SizedBox.shrink();

    final data = candles
        .map((c) => Candle(
              time: c.time,
              open: c.open,
              high: c.high,
              low: c.low,
              close: c.close,
              volume: c.volume,
            ))
        .toList();

    final lastClose = data.last.close;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1a0c01)),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          ImpChart(
            candles: data,
            style: _fireStyle,
            currentPrice: lastClose,
            enableGestures: true,
            defaultVisibleCount: 60,
            plotFeedback: false,
            crosshairChangeFeedback: false,
          ),
          if (pair.isNotEmpty)
            Positioned(
              top: 8,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _bg.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(pair,
                    style: const TextStyle(
                        color: _white, fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
        ],
      ),
    );
  }
}
