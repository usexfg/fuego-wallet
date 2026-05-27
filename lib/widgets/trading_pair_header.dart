import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/theme.dart';

class TradingPairHeader extends StatelessWidget {
  final String baseAsset;
  final String quoteAsset;
  final double price;
  final double change24h;
  final double high24h;
  final double low24h;
  final double volume24h;

  const TradingPairHeader({
    super.key,
    required this.baseAsset,
    required this.quoteAsset,
    required this.price,
    this.change24h = 0,
    this.high24h = 0,
    this.low24h = 0,
    this.volume24h = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = change24h >= 0;
    final changeColor = isPositive
        ? const Color(0xFFEF5350) // Asian Market Bull (Red)
        : const Color(0xFF26A69A); // Asian Market Bear (Green)

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.transparent,
        border: Border(
          bottom: BorderSide(color: Color(0xFF1E293B), width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    '$baseAsset/$quoteAsset',
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: changeColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${isPositive ? '+' : ''}${change24h.toStringAsFixed(2)}%',
                      style: GoogleFonts.jetBrainsMono(
                        color: changeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${isPositive ? '▲' : '▼'} ${price.toStringAsFixed(4)} $quoteAsset',
                style: GoogleFonts.jetBrainsMono(
                  color: changeColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          _statColumn('24h High', high24h.toStringAsFixed(2)),
          const SizedBox(width: 16),
          _statColumn('24h Low', low24h.toStringAsFixed(2)),
          const SizedBox(width: 16),
          _statColumn('24h Vol', _formatVolume(volume24h)),
        ],
      ),
    );
  }

  Widget _statColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF64748B),
            fontSize: 10,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(
            color: const Color(0xFFE2E8F0),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _formatVolume(double volume) {
    if (volume >= 1000000) return '${(volume / 1000000).toStringAsFixed(1)}M';
    if (volume >= 1000) return '${(volume / 1000).toStringAsFixed(1)}K';
    return volume.toStringAsFixed(0);
  }
}
