import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/cli_service.dart';
import '../../services/wallet_service.dart';
import '../../models/transaction_model.dart';
import '../../providers/wallet_provider.dart';
import '../../models/wallet.dart';
import '../../utils/theme.dart';

class BurnDepositsScreen extends StatefulWidget {
  const BurnDepositsScreen({Key? key}) : super(key: key);

  @override
  _BurnDepositsScreenState createState() => _BurnDepositsScreenState();
}

class _BurnDepositsScreenState extends State<BurnDepositsScreen> {
  final TextEditingController _ethereumAddressController = TextEditingController();
  String _selectedBurnType = 'Standard Burn';
  bool _isAddressValid = false;
  bool _isProcessing = false;
  WalletTransaction? _lastBurnTransaction;

  @override
  void initState() {
    super.initState();
    _fetchLastBurnTransaction();
  }

  Future<void> _fetchLastBurnTransaction() async {
    try {
      // Get wallet provider to access transactions
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      
      // Refresh transactions to get the latest data
      await walletProvider.refreshTransactions();
      
      // Get all transactions and find burn transactions
      final transactions = walletProvider.transactions;
      
      // Filter for burn transactions (outgoing transactions with specific characteristics)
      final burnTransactions = transactions.where((tx) => 
        tx.isSpending && // Outgoing transaction
        tx.amount > 0 && // Has amount
        tx.confirmations > 0 // Confirmed transaction
      ).toList();
      
      if (burnTransactions.isNotEmpty) {
        setState(() {
          _lastBurnTransaction = burnTransactions.last;
        });
      }
    } catch (e) {
      // Log the error but don't block the UI
      debugPrint('Error fetching last burn transaction: $e');
    }
  }

  @override
  void dispose() {
    _ethereumAddressController.dispose();
    super.dispose();
  }

  void _validateEthereumAddress(String address) {
    setState(() {
      _isAddressValid = CLIService.isValidEthereumAddress(address);
    });
  }

  Future<void> _performBurnDeposit() async {
    if (!_isAddressValid) {
      _showErrorSnackBar('Please enter a valid Ethereum address');
      return;
    }

    if (_lastBurnTransaction == null) {
      _showErrorSnackBar('No recent burn transaction found');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // Get the burn amount based on the selected burn type
      final int burnAmount = CLIService.burnDenominations[_selectedBurnType]!;
      final int heatTokens = CLIService.calculateHeatTokens(burnAmount);

      // Use the last burn transaction's hash
      final String transactionHash = _lastBurnTransaction!.txid;

      // Generate burn proof
      final BurnProofResult proofResult = await CLIService.generateBurnProof(
        transactionHash: transactionHash,
        recipientAddress: _ethereumAddressController.text,
        burnAmount: burnAmount,
        burnType: _selectedBurnType,
      );

      // Show success dialog
      _showBurnProofDialog(proofResult, heatTokens);
    } catch (e) {
      _showErrorSnackBar('Burn deposit failed: $e');
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showBurnProofDialog(BurnProofResult proofResult, int heatTokens) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Burn Transaction Successful'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Proof Hash: ${proofResult.proofHash}'),
            Text('Burn Amount: ${proofResult.burnAmount / 1000000} XFG'),
            Text('HEAT Tokens Generated: $heatTokens'),
            Text('Recipient Address: ${proofResult.recipientAddress}'),
            Text('Timestamp: ${proofResult.timestamp}'),
            const SizedBox(height: 16),
            const Text(
              'Transaction Details:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            if (_lastBurnTransaction != null) ...[
              Text('Transaction Hash: ${_lastBurnTransaction!.txid}'),
              Text('Amount: ${_lastBurnTransaction!.amountXFG} XFG'),
              Text('Date: ${_lastBurnTransaction!.dateTime}'),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Burn Transactions'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Burn XFG to Mint Ξmbers (HEAT)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ethereumAddressController,
              decoration: InputDecoration(
                labelText: 'Ethereum Recipient Address',
                hintText: '0x...',
                errorText: _isAddressValid ? null : 'Invalid Ethereum address',
                suffixIcon: _isAddressValid 
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.error, color: Colors.red),
              ),
              onChanged: _validateEthereumAddress,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedBurnType,
              decoration: const InputDecoration(
                labelText: 'Burn Type',
              ),
              items: CLIService.burnDenominations.keys
                  .map((type) => DropdownMenuItem(
                        value: type,
                        child: Text(type),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedBurnType = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            _buildBurnTypeDetails(),
            const SizedBox(height: 16),
            _buildLastBurnTransactionInfo(),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isAddressValid && !_isProcessing && _lastBurnTransaction != null
                  ? _performBurnDeposit 
                  : null,
              child: _isProcessing 
                  ? const CircularProgressIndicator()
                  : const Text('Generate Burn Proof'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBurnTypeDetails() {
    final int burnAmount = CLIService.burnDenominations[_selectedBurnType]!;
    final int heatTokens = CLIService.calculateHeatTokens(burnAmount);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedBurnType,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Burn Amount: ${burnAmount / 1000000} XFG'),
            Text('HEAT Tokens Generated: $heatTokens'),
            const SizedBox(height: 8),
            const Text(
              'Note: Burning XFG will mint an atomically equivalent amount of Ξmbers (HEAT) on Ethereum L1.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLastBurnTransactionInfo() {
    if (_lastBurnTransaction == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No recent burn transaction found',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Last Burn Transaction',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Hash: ${_lastBurnTransaction!.txid}'),
            Text('Amount: ${_lastBurnTransaction!.amountXFG} XFG'),
            Text('Date: ${_lastBurnTransaction!.dateTime}'),
          ],
        ),
      ),
    );
  }
}


