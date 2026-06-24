import 'package:flutter/material.dart';
import '../../../utils/theme.dart';

class HeatScreen extends StatelessWidget {
  const HeatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('HEAT Stablecoin'),
        backgroundColor: AppTheme.surfaceColor,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.local_fire_department, size: 64, color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text('H\u2CB6\u2206T Stablecoin', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            SizedBox(height: 8),
            Text('Algorithmic stablecoin pegged to purchasing power\nPI-controlled, burn-to-mint mechanism',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}
