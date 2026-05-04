import 'package:flutter/material.dart';

class AtomicSwapsScreen extends StatefulWidget {
  const AtomicSwapsScreen({super.key});

  @override
  _AtomicSwapsScreenState createState() => _AtomicSwapsScreenState();
}

class _AtomicSwapsScreenState extends State<AtomicSwapsScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('AFK Atomic Swaps'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'XFG Swaps'),
              Tab(text: 'CD Markets'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // XFG Swaps Tab
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cross-chain Swaps (ETH / SOL)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const TextField(decoration: InputDecoration(labelText: 'Amount to Swap')),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: 'ETH',
                            items: const [
                              DropdownMenuItem(value: 'ETH', child: Text('Ethereum (ETH)')),
                              DropdownMenuItem(value: 'SOL', child: Text('Solana (SOL)')),
                            ],
                            onChanged: (v) {},
                            decoration: const InputDecoration(labelText: 'Target Chain'),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {},
                            child: const Text('Initiate Atomic Swap'),
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
            // CD Markets Tab
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CD / XFG Swap Market', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Text('Trade your active Certificates of Deposit directly with other users via smart contracts.'),
                  SizedBox(height: 24),
                  Expanded(
                    child: Center(
                      child: Text('No active CD markets found. Connect wallet to refresh.'),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
