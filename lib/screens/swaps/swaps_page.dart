import 'package:flutter/material.dart';
import '../../services/web3_multi_chain_service.dart';

class SwapsPage extends StatefulWidget {
  const SwapsPage({super.key});

  @override
  State<SwapsPage> createState() => _SwapsPageState();
}

class _SwapsPageState extends State<SwapsPage> {
  final Web3MultiChainService _web3Service = Web3MultiChainService();

  String _fromNetwork = 'Ethereum';
  String _toNetwork = 'Solana';
  String _fromToken = 'HEAT (ERC20)';
  String _toToken = 'HEAT (SPL)';

  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _privateKeyController = TextEditingController(); // For demo only!

  bool _isSwapping = false;
  String _statusMessage = '';

  final List<String> _networks = ['Ethereum', 'Solana', 'Fuego'];
  final List<String> _tokens = ['HEAT (ERC20)', 'HEAT (SPL)', '100XFG (SPL)', 'XFG'];

  void _executeSwap() async {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) {
      setState(() => _statusMessage = 'Please enter a valid amount.');
      return;
    }
    if (_addressController.text.isEmpty || _privateKeyController.text.isEmpty) {
      setState(() => _statusMessage = 'Address and private key required.');
      return;
    }

    setState(() {
      _isSwapping = true;
      _statusMessage = 'Initiating swap...';
    });

    try {
      final result = await _web3Service.executeAtomicSwap(
        fromNetwork: _fromNetwork,
        toNetwork: _toNetwork,
        fromToken: _fromToken,
        toToken: _toToken,
        amount: amount,
        userAddress: _addressController.text,
        privateKey: _privateKeyController.text,
      );

      setState(() {
        _statusMessage = 'Success! TX: ${result['txHash']}';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: $e';
      });
    } finally {
      setState(() {
        _isSwapping = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Atomic Swaps (HEAT / XFG)'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Cross-Chain Swap Interface',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // From Network / Token
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _fromNetwork,
                      decoration: const InputDecoration(labelText: 'From Network'),
                      items: _networks.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                      onChanged: (val) => setState(() => _fromNetwork = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _fromToken,
                      decoration: const InputDecoration(labelText: 'From Token'),
                      items: _tokens.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setState(() => _fromToken = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // To Network / Token
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _toNetwork,
                      decoration: const InputDecoration(labelText: 'To Network'),
                      items: _networks.map((n) => DropdownMenuItem(value: n, child: Text(n))).toList(),
                      onChanged: (val) => setState(() => _toNetwork = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _toToken,
                      decoration: const InputDecoration(labelText: 'To Token'),
                      items: _tokens.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (val) => setState(() => _toToken = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount to Swap',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Your Wallet Address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _privateKeyController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Your Private Key (Demo Only)',
                  border: OutlineInputBorder(),
                  helperText: 'Required to sign real transactions',
                ),
              ),
              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _isSwapping ? null : _executeSwap,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSwapping
                    ? const CircularProgressIndicator()
                    : const Text('Execute Swap', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 24),

              if (_statusMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: _statusMessage.startsWith('Error')
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  child: Text(
                    _statusMessage,
                    style: TextStyle(
                      color: _statusMessage.startsWith('Error') ? Colors.red : Colors.green[800],
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
