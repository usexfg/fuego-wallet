import 'package:flutter/material.dart';
import 'package:imp_trading_chart/imp_trading_chart.dart';
import '../models/candlestick.dart';

class FuegoChart extends StatelessWidget {
  final List<Candlestick> candles;
  final String pair;

  const FuegoChart({
    super.key,
    required this.candles,
    this.pair = '',
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
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF252B33),
              Color(0xFF0A0E14),
            ],
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            ImpChart.trading(
              candles: impCandles,
              lineColor: const Color(0xFFFF5722),
              backgroundColor: Colors.transparent,
              pulseColor: const Color(0xFFFF5722),
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
                    color: const Color(0xFF252B33).withAlpha(200),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(pair,
                      style: const TextStyle(
                          color: Color(0xFFFF5722),
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
