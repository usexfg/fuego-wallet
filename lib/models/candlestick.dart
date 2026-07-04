class Candlestick {
  final int time;     // unix seconds
  final double open;
  final double high;
  final double low;
  final double close;
  final double volume;

  const Candlestick({
    required this.time,
    required this.open,
    required this.high,
    required this.low,
    required this.close,
    this.volume = 0,
  });

  factory Candlestick.fromJson(Map<String, dynamic> json) {
    return Candlestick(
      time: (json['period_start'] as num).toInt(),
      open: (json['open'] as num).toDouble(),
      high: (json['high'] as num).toDouble(),
      low: (json['low'] as num).toDouble(),
      close: (json['close'] as num).toDouble(),
      volume: (json['volume'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toChartJson() => {
        'time': time,
        'open': open,
        'high': high,
        'low': low,
        'close': close,
        'volume': volume,
      };
}
