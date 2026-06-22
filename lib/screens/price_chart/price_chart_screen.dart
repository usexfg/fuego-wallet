import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/theme.dart';
import '../../widgets/candlestick_chart.dart';

class PriceChartScreen extends StatefulWidget {
  const PriceChartScreen({super.key});

  @override
  State<PriceChartScreen> createState() => _PriceChartScreenState();
}

class _PriceChartScreenState extends State<PriceChartScreen> {
  List<CandleData> _candles = [];
  bool _isLoading = true;
  String? _error;
  String _selectedPeriod = 'ALL';

  final Map<String, int> _periodLimits = {
    '1W': 7,
    '1M': 30,
    '3M': 90,
    '1Y': 365,
    'ALL': 999999,
  };

  @override
  void initState() {
    super.initState();
    _loadPriceData();
  }

  Future<void> _loadPriceData() async {
    try {
      final jsonStr = await rootBundle.loadString('assets/data/xfg_historical_prices.json');
      final List<dynamic> jsonList = json.decode(jsonStr);

      final candles = jsonList.map((item) {
        final ts = item['period_start'] as int;
        return CandleData(
          open: (item['open'] as num).toDouble(),
          high: (item['high'] as num).toDouble(),
          low: (item['low'] as num).toDouble(),
          close: (item['close'] as num).toDouble(),
          volume: (item['volume'] as num).toDouble(),
          time: DateTime.fromMillisecondsSinceEpoch(ts * 1000, isUtc: true),
        );
      }).toList();

      setState(() {
        _candles = candles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load price data: $e';
        _isLoading = false;
      });
    }
  }

  List<CandleData> get _filteredCandles {
    final limit = _periodLimits[_selectedPeriod] ?? 999999;
    if (_candles.length <= limit) return _candles;
    return _candles.sublist(_candles.length - limit);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadPriceData,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildChartContent(),
    );
  }

  Widget _buildChartContent() {
    final candles = _filteredCandles;
    if (candles.isEmpty) {
      return const Center(child: Text('No data', style: TextStyle(color: AppTheme.textMuted)));
    }

    final currentPrice = candles.last.close;
    final firstPrice = candles.first.open;
    final priceChange = currentPrice - firstPrice;
    final priceChangePct = firstPrice > 0 ? (priceChange / firstPrice * 100) : 0.0;
    final isPositive = priceChange >= 0;
    final allHigh = candles.map((c) => c.high).reduce(max);
    final allLow = candles.map((c) => c.low).reduce(min);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatPrice(currentPrice),
                    style: GoogleFonts.jetBrainsMono(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      'USD',
                      style: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${isPositive ? '+' : ''}${priceChangePct.toStringAsFixed(2)}%',
                        style: GoogleFonts.jetBrainsMono(
                          color: isPositive ? AppTheme.successColor : AppTheme.errorColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${isPositive ? '+' : ''}${_formatPrice(priceChange)}',
                        style: GoogleFonts.jetBrainsMono(
                          color: isPositive ? AppTheme.successColor : AppTheme.errorColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Period selector
              SizedBox(
                height: 32,
                child: Row(
                  children: _periodLimits.keys.map((period) {
                    final isSelected = _selectedPeriod == period;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedPeriod = period),
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor.withOpacity(0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: isSelected
                              ? Border.all(color: AppTheme.primaryColor.withOpacity(0.5))
                              : Border.all(color: AppTheme.dividerColor.withOpacity(0.3)),
                        ),
                        child: Center(
                          child: Text(
                            period,
                            style: GoogleFonts.jetBrainsMono(
                              color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        // Chart
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TradingChart(
              candles: candles,
              height: double.infinity,
              bullColor: AppTheme.successColor,
              bearColor: AppTheme.errorColor,
            ),
          ),
        ),
        // Stats bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(
              top: BorderSide(color: AppTheme.dividerColor.withOpacity(0.3), width: 0.5),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statChip('ATH', _formatPrice(allHigh)),
              _statChip('ATL', _formatPrice(allLow)),
              _statChip('Days', '${candles.length}'),
              _statChip('Data', '${_candles.length} pts'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statChip(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatPrice(double price) {
    if (price >= 1.0) return '\$${price.toStringAsFixed(2)}';
    if (price >= 0.01) return '\$${price.toStringAsFixed(4)}';
    if (price >= 0.0001) return '\$${price.toStringAsFixed(6)}';
    return '\$${price.toStringAsFixed(8)}';
  }
}
