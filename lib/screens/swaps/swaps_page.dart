import 'package:flutter/material.dart';

class SwapsPage extends StatelessWidget {
  const SwapsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atomic Swaps'),
      ),
      body: const Center(
        child: Text('Swap UI coming soon – integrated with SwapDaemon and TradingView charts.'),
      ),
    );
  }
}
