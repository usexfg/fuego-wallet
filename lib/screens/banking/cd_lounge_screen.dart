import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../sdk/fuego_sdk_service.dart';
import '../../utils/theme.dart';

class CDLoungeScreen extends StatefulWidget {
  const CDLoungeScreen({super.key});

  @override
  _CDLoungeScreenState createState() => _CDLoungeScreenState();
}

class _CDLoungeScreenState extends State<CDLoungeScreen> {
  final _amountController = TextEditingController();
  final _passwordController = TextEditingController();
  final _walletFileController = TextEditingController();

  int _selectedDuration = 30;
  bool _isProcessing = false;
  List<CDInfo> _activeCDs = [];

  static const _durationOptions = {
    30: '30 days',
    60: '60 days',
    90: '90 days',
  };

  static const _apyRates = {
    30: 5.0,
    60: 8.0,
    90: 12.0,
  };

  double get _currentApy => _apyRates[_selectedDuration] ?? 5.0;

  @override
  void initState() {
    super.initState();
    final wallet = context.read<WalletProvider>().wallet;
    if (wallet != null) {
      _loadCDs();
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _passwordController.dispose();
    _walletFileController.dispose();
    super.dispose();
  }

  Future<void> _loadCDs() async {
    setState(() => _isProcessing = true);
    try {
      final updated = <CDInfo>[];
      for (final cd in _activeCDs) {
        try {
          final info = await FuegoSDKService.instance.getCDInfo(cd.txHash);
          updated.add(info);
        } catch (_) {
          updated.add(cd);
        }
      }
      if (mounted) setState(() => _activeCDs = updated);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<String?> _promptPassword() {
    _passwordController.clear();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter Wallet Password'),
        content: TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(_passwordController.text),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _createCD() async {
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty) {
      _showSnack('Please enter an amount', isError: true);
      return;
    }
    final amount = int.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showSnack('Invalid amount', isError: true);
      return;
    }

    final walletFile = _walletFileController.text.trim();
    final password = await _promptPassword();
    if (password == null || password.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      final lockTime = _selectedDuration * 86400;
      final cdInfo = await FuegoSDKService.instance.createCD(
        amount: amount,
        lockTime: lockTime,
        walletFile: walletFile,
        walletPassword: password,
      );
      if (!mounted) return;
      setState(() {
        _activeCDs.add(cdInfo);
        _amountController.clear();
      });
      _showSnack('CD created successfully');
    } catch (e) {
      _showSnack('Failed to create CD: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _redeemCD(CDInfo cd) async {
    final walletFile = _walletFileController.text.trim();
    final password = await _promptPassword();
    if (password == null || password.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      await FuegoSDKService.instance.redeemCD(
        txHash: cd.txHash,
        walletFile: walletFile,
        walletPassword: password,
      );
      if (!mounted) return;
      setState(() => _activeCDs.removeWhere((c) => c.txHash == cd.txHash));
      _showSnack('CD redeemed successfully');
    } catch (e) {
      _showSnack('Failed to redeem CD: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CD Lounge'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Create CD'),
              Tab(text: 'Active CDs'),
              Tab(text: 'CD Info'),
            ],
          ),
        ),
        body: _isProcessing
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildCreateTab(),
                  _buildActiveCDsTab(),
                  _buildInfoTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Create Certificate of Deposit',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Lock HEAT tokens for a fixed term and earn interest.',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _walletFileController,
            decoration: const InputDecoration(
              labelText: 'Wallet File Path',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Amount (HEAT atomic units)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            value: _selectedDuration,
            decoration: const InputDecoration(
              labelText: 'Duration',
              border: OutlineInputBorder(),
            ),
            items: _durationOptions.entries
                .map((e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value),
                    ))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _selectedDuration = v);
            },
          ),
          const SizedBox(height: 12),
          Card(
            color: AppTheme.surfaceLight,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.percent, color: AppTheme.accentColor),
                  const SizedBox(width: 8),
                  Text(
                    'Interest Rate: $_currentApy% APY',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _createCD,
              child: Text(_isProcessing ? 'Creating...' : 'Create CD'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveCDsTab() {
    if (_activeCDs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 64, color: AppTheme.textMuted),
            SizedBox(height: 16),
            Text(
              'No active CDs',
              style: TextStyle(fontSize: 18, color: AppTheme.textMuted),
            ),
            SizedBox(height: 8),
            Text(
              'Create a CD to start earning interest.',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCDs,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _activeCDs.length,
        itemBuilder: (context, index) {
          final cd = _activeCDs[index];
          final isLocked = cd.unlockTime > DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final remaining = cd.unlockTime - DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final remainingDays = remaining > 0 ? remaining ~/ 86400 : 0;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${cd.amount} HEAT',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isLocked
                              ? AppTheme.warningColor.withOpacity(0.2)
                              : AppTheme.successColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isLocked ? 'Locked' : 'Matured',
                          style: TextStyle(
                            color: isLocked
                                ? AppTheme.warningColor
                                : AppTheme.successColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Interest: ${cd.interest} HEAT',
                    style: const TextStyle(color: AppTheme.accentColor),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLocked
                        ? 'Unlocks in $remainingDays days'
                        : 'Ready to redeem',
                    style: const TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'TX: ${cd.txHash.length > 16 ? '${cd.txHash.substring(0, 16)}...' : cd.txHash}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  if (!isLocked) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : () => _redeemCD(cd),
                        child: const Text('Redeem'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current CD Rates',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          ..._durationOptions.entries.map((e) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.value,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lock for ${e.key} days',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '${_apyRates[e.key]}% APY',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
          const SizedBox(height: 24),
          const Card(
            color: AppTheme.surfaceLight,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How CDs Work',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Certificates of Deposit (CDs) let you lock HEAT tokens '
                    'for a fixed period to earn interest. Interest is paid '
                    'in HEAT upon maturity. Longer lock periods earn higher APY.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
