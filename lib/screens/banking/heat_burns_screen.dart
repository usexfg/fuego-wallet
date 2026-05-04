import 'package:flutter/material.dart';
import '../../services/burn_proof_service.dart';

class HeatBurnsScreen extends StatefulWidget {
  const HeatBurnsScreen({super.key});

  @override
  _HeatBurnsScreenState createState() => _HeatBurnsScreenState();
}

class _HeatBurnsScreenState extends State<HeatBurnsScreen> {
  final _txHashController = TextEditingController();
  final _recipientController = TextEditingController();
  final _commitmentIndexController = TextEditingController();

  String _burnType = 'Standard Burn';
  bool _isGenerating = false;
  BundledBurnProof? _bundledProof;
  String? _errorMessage;

  Future<void> _generateBundledProof() async {
    setState(() {
      _isGenerating = true;
      _bundledProof = null;
      _errorMessage = null;
    });

    try {
      final proof = await BurnProofBundler.generateBundledProof(
        transactionHash: _txHashController.text,
        recipientAddress: _recipientController.text,
        burnAmount: _burnType == 'Standard Burn' ? 800000 : 80000000,
        commitmentIndex: _commitmentIndexController.text,
        burnType: _burnType,
      );

      setState(() {
        _bundledProof = proof;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HEAT Burns & Proof Generation')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Generate Bundled Proofs for HEAT Claims',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _txHashController,
              decoration: const InputDecoration(labelText: 'Burn Transaction Hash', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _recipientController,
              decoration: const InputDecoration(labelText: 'Recipient ETH Address', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _commitmentIndexController,
              decoration: const InputDecoration(labelText: 'Commitment Index', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _burnType,
              items: const [
                DropdownMenuItem(value: 'Standard Burn', child: Text('Standard Burn (0.8 XFG)')),
                DropdownMenuItem(value: 'Large Burn', child: Text('Large Burn (800 XFG)')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _burnType = val);
              },
              decoration: const InputDecoration(labelText: 'Burn Type', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateBundledProof,
                child: _isGenerating
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Generate Bundled Proof'),
              ),
            ),
            const SizedBox(height: 24),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.red.withOpacity(0.1),
                child: Text('Error: $_errorMessage', style: const TextStyle(color: Colors.red)),
              ),
            if (_bundledProof != null)
              Card(
                color: Colors.green.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Proof Generation Successful!', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 8),
                      Text('STARK Proof Hash: ${_bundledProof!.starkProofHash}'),
                      const SizedBox(height: 4),
                      Text('Merkle Proof: ${_bundledProof!.merkleProof}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          // TODO: Claim HEAT
                        },
                        child: const Text('Claim HEAT with Proof'),
                      )
                    ],
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}
