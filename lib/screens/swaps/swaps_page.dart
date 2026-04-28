import 'package:flutter/material.dart';
import '../../utils/theme.dart';

class SwapsPage extends StatelessWidget {
  const SwapsPage({Key? key}) : super(key: key);

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
