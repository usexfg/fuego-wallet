import 'package:flutter/material.dart';
import '../../../utils/theme.dart';

class HearthScreen extends StatelessWidget {
  const HearthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Hearth AMM'),
        backgroundColor: AppTheme.surfaceColor,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horiz, size: 64, color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text('XFG \u2194 H\u2CB6\u2206T Swap', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            SizedBox(height: 8),
            Text('Constant-product AMM pool\n0.3% fee to liquidity providers',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}
