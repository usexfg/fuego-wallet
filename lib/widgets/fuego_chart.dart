import 'package:flutter/material.dart';
import 'package:imp_trading_chart/imp_trading_chart.dart';
import '../models/candlestick.dart';

class FuegoChart extends StatelessWidget {
  final List<Candlestick> candles;
  final String pair;
  final Color lineColor;
  final Color bgColor;

  const FuegoChart({
    super.key,
    required this.candles,
    this.pair = '',
    this.lineColor = const Color(0xFFFF5722),
    this.bgColor = const Color(0xFF0A0E14),
  });

  @override
  Widget build(BuildContext context) {
    if (candles.isEmpty) return const SizedBox.shrink();
    final impCandles = candles
        .map((c) => Candle(
              time: c.time,
              open: c.open,
              high: c.high,
              low: c.low,
              close: c.close,
              volume: c.volume,
            ))
        .toList();
    return LayoutBuilder(builder: (context, constraints) {
      return Container(
        height: constraints.maxHeight,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(0),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            ImpChart.trading(
              candles: impCandles,
              lineColor: lineColor,
              backgroundColor: Colors.transparent,
              pulseColor: lineColor,
              enableGestures: true,
              showCrosshair: true,
              defaultVisibleCount: candles.length,
            ),
            if (pair.isNotEmpty)
              Positioned(
                top: 8,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: bgColor.withAlpha(200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(pair,
                      style: TextStyle(
                          color: lineColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2)),
                ),
              ),
          ],
        ),
      );
    });
  }
}
