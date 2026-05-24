import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../sdk/fuego_sdk_service.dart';
import '../../utils/theme.dart';

class AliasesScreen extends StatefulWidget {
  const AliasesScreen({super.key});

  @override
  _AliasesScreenState createState() => _AliasesScreenState();
}

class _AliasesScreenState extends State<AliasesScreen> {
  final _aliasController = TextEditingController();
  final _addressController = TextEditingController();
  final _walletFileController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isProcessing = false;
  List<String> _ownedAliases = [];

  @override
  void initState() {
    super.initState();
    final wallet = context.read<WalletProvider>().wallet;
    if (wallet != null) {
      _addressController.text = wallet.address;
      _loadAliases();
    }
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _addressController.dispose();
    _walletFileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadAliases() async {
    final wallet = context.read<WalletProvider>().wallet;
    if (wallet == null) return;

    setState(() => _isProcessing = true);
    try {
      final aliases = await FuegoSDKService.instance.getOwnedAliases(wallet.address);
      if (mounted) setState(() => _ownedAliases = aliases);
    } catch (e) {
      if (mounted) _showSnack('Failed to load aliases: $e', isError: true);
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

  Future<void> _registerAlias() async {
    final alias = _aliasController.text.trim();
    if (alias.isEmpty) {
      _showSnack('Please enter an alias', isError: true);
      return;
    }
    if (alias.length > 8) {
      _showSnack('Alias must be 8 characters or less', isError: true);
      return;
    }

    final wallet = context.read<WalletProvider>().wallet;
    if (wallet == null) {
      _showSnack('Wallet not available', isError: true);
      return;
    }

    final walletFile = _walletFileController.text.trim();
    if (walletFile.isEmpty) {
      _showSnack('Wallet file path required', isError: true);
      return;
    }

    final password = await _promptPassword();
    if (password == null || password.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      final txHash = await FuegoSDKService.instance.registerAlias(
        alias: alias,
        walletAddress: wallet.address,
        walletFile: walletFile,
        walletPassword: password,
      );
      if (!mounted) return;
      _aliasController.clear();
      _ownedAliases.add(alias);
      _showSnack('Alias registered! TX: ${txHash.length > 16 ? '${txHash.substring(0, 16)}...' : txHash}');
    } catch (e) {
      if (mounted) _showSnack('Failed to register alias: $e', isError: true);
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
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Fire Aliases'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'My Aliases'),
              Tab(text: 'Register'),
            ],
          ),
        ),
        body: _isProcessing
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildMyAliasesTab(),
                  _buildRegisterTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildMyAliasesTab() {
    if (_ownedAliases.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.alternate_email, size: 64, color: AppTheme.textMuted),
            SizedBox(height: 16),
            Text(
              'No aliases registered',
              style: TextStyle(fontSize: 18, color: AppTheme.textMuted),
            ),
            SizedBox(height: 8),
            Text(
              'Register an alias to replace your long wallet address.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAliases,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _ownedAliases.length,
        itemBuilder: (context, index) {
          final alias = _ownedAliases[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                child: Text(
                  alias[0].toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                alias,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 18,
                ),
              ),
              subtitle: const Text(
                'Active',
                style: TextStyle(color: AppTheme.successColor),
              ),
              trailing: const Icon(
                Icons.check_circle,
                color: AppTheme.successColor,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRegisterTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Register a New Alias',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'An alias is a short, human-readable name (max 8 characters) '
            'that maps to your wallet address. Use it to receive funds '
            'instead of sharing your full 98-character address.',
            style: TextStyle(color: AppTheme.textSecondary, height: 1.5),
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
            controller: _aliasController,
            maxLength: 8,
            decoration: const InputDecoration(
              labelText: 'Desired Alias (max 8 characters)',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _addressController,
            decoration: const InputDecoration(
              labelText: 'Wallet Address',
              border: OutlineInputBorder(),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isProcessing ? null : _registerAlias,
              child: Text(_isProcessing ? 'Registering...' : 'Register Alias'),
            ),
          ),
        ],
      ),
    );
  }
}
