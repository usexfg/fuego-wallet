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
          title: const Text('Hearth AMM & Atomic Swaps'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Hearth AMM (HEAT/XFG)'),
              Tab(text: 'Cross-chain Swaps'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Hearth AMM Tab
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Hearth AMM Liquidity Pools', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Instantly swap between XFG and HEAT using the decentralized Hearth AMM.'),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          const TextField(decoration: InputDecoration(labelText: 'Amount to Swap')),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: 'XFG_TO_HEAT',
                            items: const [
                              DropdownMenuItem(value: 'XFG_TO_HEAT', child: Text('XFG -> HEAT')),
                              DropdownMenuItem(value: 'HEAT_TO_XFG', child: Text('HEAT -> XFG')),
                            ],
                            onChanged: (v) {},
                            decoration: const InputDecoration(labelText: 'Swap Direction'),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: () {},
                            child: const Text('Execute AMM Swap'),
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
            // Cross-chain Swaps Tab
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cross-chain Swaps (ETH / SOL)', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('Trustlessly swap XFG for assets on other blockchains using atomic swaps and adaptor signatures.'),
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
          ],
        ),
      ),
    );
  }
}
