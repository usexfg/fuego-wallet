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

    const bg = Color(0xFF0D1117);

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF1f2937)),
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
                      color: Color(0xFFe5e7eb),
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
            ),
          Expanded(
            child: ImpChart.trading(
              candles: data,
              backgroundColor: bg,
              lineColor: const Color(0xFF3b82f6),
              pulseColor: const Color(0xFF22c55e),
              enableGestures: true,
              showCrosshair: true,
              plotFeedback: false,
              crosshairChangeFeedback: false,
            ),
          ),
        ],
      ),
    );
  }
}
