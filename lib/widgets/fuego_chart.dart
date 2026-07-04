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

    return Container(
      height: height,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0a0a1a),
            Color(0xFF0d0520),
            Color(0xFF120828),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF00f0ff).withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00f0ff).withOpacity(0.05),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          if (pair.isNotEmpty)
            Container(
              padding: const EdgeInsets.only(left: 12, top: 8, bottom: 2),
              alignment: Alignment.centerLeft,
              child: Text(pair,
                  style: const TextStyle(
                      color: Color(0xFF00f0ff),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2)),
            ),
          Expanded(
            child: ImpChart.trading(
              candles: data,
              backgroundColor: Colors.transparent,
              lineColor: const Color(0xFF00f0ff),
              pulseColor: const Color(0xFFff00ff),
              enableGestures: true,
              showCrosshair: true,
              defaultVisibleCount: 60,
              plotFeedback: true,
              crosshairChangeFeedback: true,
            ),
          ),
        ],
      ),
    );
  }
}
