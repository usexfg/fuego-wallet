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
              Color(0xFFFFAB91),
              Color(0xFFFF8A65),
              Color(0xFFBF360C),
              Color(0xFF1A1F26),
              Color(0xFF0A0E14),
            ],
            stops: [0.0, 0.12, 0.35, 0.65, 1.0],
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFFD700).withAlpha(38)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFD700).withAlpha(15),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            ImpChart.trading(
              candles: impCandles,
              lineColor: const Color(0xFFFFD700),
              backgroundColor: Colors.transparent,
              pulseColor: const Color(0xFFFFAB91),
              enableGestures: true,
              showCrosshair: true,
              defaultVisibleCount: 60,
            ),
            if (pair.isNotEmpty)
              Positioned(
                top: 8,
                left: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFAB91).withAlpha(220),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(pair,
                      style: const TextStyle(
                          color: Color(0xFF0A0E14),
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
