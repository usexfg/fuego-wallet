import 'package:flutter/material.dart';
import '../../utils/theme.dart';

class HeatPage extends StatelessWidget {
  const HeatPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HEAT / XFG Burn'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Steps to mint HEAT:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('1. Burn XFG in the wallet (amount you choose).'),
            Text('2. Generate a zk‑proof using fuego‑prover (CLI or FFI).'),
            Text('3. Submit the proof to stark‑cli to receive HEAT on Ethereum.'),
            SizedBox(height: 16),
            Text('HEAT tokens are minted automatically after proof verification.', style: TextStyle(color: Colors.orangeAccent)),
          ],
        ),
      ),
    );
  }
}
