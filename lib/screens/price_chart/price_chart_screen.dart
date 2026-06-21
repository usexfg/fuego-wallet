import 'dart:convert';
import 'dart:math';
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
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'XFG / USD',
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            Text(
              'Fuego Price History',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 11,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
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
      return const Center(child: Text('No data available', style: TextStyle(color: AppTheme.textMuted)));
    }

    final currentPrice = candles.last.close;
    final firstPrice = candles.first.open;
    final priceChange = currentPrice - firstPrice;
    final priceChangePct = firstPrice > 0 ? (priceChange / firstPrice * 100) : 0;
    final isPositive = priceChange >= 0;

    final allHigh = candles.map((c) => c.high).reduce(max);
    final allLow = candles.map((c) => c.low).reduce(min);
    final totalVolume = candles.map((c) => c.volume).fold(0.0, (a, b) => a + b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPriceHeader(currentPrice, priceChange, priceChangePct, isPositive),
          const SizedBox(height: 20),
          _buildPeriodSelector(),
          const SizedBox(height: 16),
          _buildChartCard(candles),
          const SizedBox(height: 16),
          _buildStatsGrid(allHigh, allLow, totalVolume, candles),
          const SizedBox(height: 16),
          _buildMarketInfo(candles),
        ],
      ),
    );
  }

  Widget _buildPriceHeader(double currentPrice, double change, double changePct, bool isPositive) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isPositive ? AppTheme.successColor : AppTheme.errorColor).withOpacity(0.2),
          width: 1,
        ),
      ),
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
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'USD',
                  style: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: isPositive ? AppTheme.successColor : AppTheme.errorColor,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '${isPositive ? '+' : ''}${change.toStringAsFixed(6)} (${isPositive ? '+' : ''}${changePct.toStringAsFixed(2)}%)',
                style: GoogleFonts.jetBrainsMono(
                  color: isPositive ? AppTheme.successColor : AppTheme.errorColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _selectedPeriod,
                style: GoogleFonts.inter(
                  color: AppTheme.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: _periodLimits.keys.map((period) {
          final isSelected = _selectedPeriod == period;
          return GestureDetector(
            onTap: () => setState(() => _selectedPeriod = period),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: isSelected
                    ? Border.all(color: AppTheme.primaryColor.withOpacity(0.5))
                    : Border.all(color: AppTheme.dividerColor.withOpacity(0.5)),
              ),
              child: Text(
                period,
                style: GoogleFonts.jetBrainsMono(
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildChartCard(List<CandleData> candles) {
    return Container(
      height: 380,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: TradingChart(
        candles: candles,
        height: 360,
        bullColor: AppTheme.successColor,
        bearColor: AppTheme.errorColor,
      ),
    );
  }

  Widget _buildStatsGrid(double allHigh, double allLow, double totalVolume, List<CandleData> candles) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Market Statistics',
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildStatItem('24h High', _formatPrice(allHigh), AppTheme.successColor)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatItem('24h Low', _formatPrice(allLow), AppTheme.errorColor)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatItem('Total Volume', _formatVolume(totalVolume), AppTheme.infoColor)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatItem('Data Points', '${candles.length}', AppTheme.accentColor)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarketInfo(List<CandleData> candles) {
    final firstDate = candles.first.time;
    final lastDate = candles.last.time;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Price History',
            style: GoogleFonts.inter(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('Start Date', _formatDate(firstDate)),
          const SizedBox(height: 8),
          _buildInfoRow('End Date', _formatDate(lastDate)),
          const SizedBox(height: 8),
          _buildInfoRow('All-Time High', _formatPrice(candles.map((c) => c.high).reduce(max))),
          const SizedBox(height: 8),
          _buildInfoRow('All-Time Low', _formatPrice(candles.map((c) => c.low).reduce(min))),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: AppTheme.textMuted, fontSize: 12),
        ),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
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

  String _formatVolume(double volume) {
    if (volume >= 1e6) return '${(volume / 1e6).toStringAsFixed(2)}M';
    if (volume >= 1e3) return '${(volume / 1e3).toStringAsFixed(2)}K';
    return volume.toStringAsFixed(2);
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
