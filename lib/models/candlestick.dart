class Candlestick {
  final int time; // unix seconds
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
    final time = _number(json['period_start'] ?? json['t'] ?? json['time']);
    return Candlestick(
      time: time.toInt(),
      open: _number(json['open'] ?? json['o']),
      high: _number(json['high'] ?? json['h']),
      low: _number(json['low'] ?? json['l']),
      close: _number(json['close'] ?? json['c']),
      volume: _number(json['volume'] ?? json['v'], required: false),
    );
  }

  static double _number(Object? value, {bool required = true}) {
    final parsed = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
    if (!required) return 0;
    throw const FormatException('Invalid OHLCV value');
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
