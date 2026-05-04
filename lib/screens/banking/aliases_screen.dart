import 'package:flutter/material.dart';

class AliasesScreen extends StatefulWidget {
  const AliasesScreen({super.key});

  @override
  _AliasesScreenState createState() => _AliasesScreenState();
}

class _AliasesScreenState extends State<AliasesScreen> {
  final _aliasController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fire Aliases')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Register an Alias',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Register an 8-character public address alias. This alias can be used in place of your 98-character wallet address when receiving funds or swaps.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _aliasController,
              maxLength: 8,
              decoration: const InputDecoration(
                labelText: 'Desired Alias (8 characters max)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Implement on-chain registration
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Alias registration logic coming soon')),
                  );
                },
                child: const Text('Register Alias on-chain'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
