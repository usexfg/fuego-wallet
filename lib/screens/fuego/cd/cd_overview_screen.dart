import 'package:flutter/material.dart';
import '../../../utils/theme.dart';

class CdOverviewScreen extends StatelessWidget {
  const CdOverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Certificates of Deposit'),
        backgroundColor: AppTheme.surfaceColor,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.savings, size: 64, color: AppTheme.primaryColor),
            SizedBox(height: 16),
            Text('CD Market', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            SizedBox(height: 8),
            Text('HEAT-denominated time-locked deposits\nearning yield from protocol fees',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      ),
    );
  }
}
