import 'package:flutter/material.dart';

class CDLoungeScreen extends StatefulWidget {
  const CDLoungeScreen({super.key});

  @override
  _CDLoungeScreenState createState() => _CDLoungeScreenState();
}

class _CDLoungeScreenState extends State<CDLoungeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interest Lounge - Certificates of Deposit'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Welcome to the Interest Lounge',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Card(
              elevation: 4,
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How Certificates of Deposit (CDs) Work',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Certificates of Deposit allow you to lock up your XFG or COLD tokens for a specific period of time. In exchange for providing liquidity and stability, you earn a fixed interest rate (C0DL3 interest) payable in HEAT tokens or compounded back into your principal.\n\n'
                      '1. Choose the asset you want to lock up.\n'
                      '2. Select a duration (e.g., 3 months, 6 months, 1 year).\n'
                      '3. Confirm your CD creation and start earning yield immediately.',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Active CDs',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Placeholder for active CDs list
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text('No active CDs found. Start by creating one below!'),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement CD creation modal/flow
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CD Creation Coming Soon')),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Create New CD'),
            ),
          ],
        ),
      ),
    );
  }
}
