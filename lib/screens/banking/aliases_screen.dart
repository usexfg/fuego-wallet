import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../sdk/fuego_sdk_service.dart';
import '../../utils/theme.dart';

class AliasesScreen extends StatefulWidget {
  const AliasesScreen({super.key});

  @override
  State<AliasesScreen> createState() => _AliasesScreenState();
}

class _AliasesScreenState extends State<AliasesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _aliasController = TextEditingController();
  final _walletFileController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isProcessing = false;
  List<String> _ownedAliases = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Auto-fill wallet path if available from provider
    final walletProvider = context.read<WalletProvider>();
    if (walletProvider.walletFile.isNotEmpty) {
      _walletFileController.text = walletProvider.walletFile;
    }
    
    _loadAliases();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _aliasController.dispose();
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
    final password = _passwordController.text;

    if (walletFile.isEmpty || password.isEmpty) {
      _showSnack('Wallet file path and password are required', isError: true);
      return;
    }

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
      _passwordController.clear();
      _ownedAliases.add(alias);
      _showSnack('Alias registered! TX: ${txHash.length > 16 ? '${txHash.substring(0, 16)}...' : txHash}');
      _tabController.animateTo(0);
    } catch (e) {
      if (mounted) _showSnack('Failed to register alias: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: GoogleFonts.inter(fontWeight: FontWeight.w500),
        ),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'Wallet Aliases',
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppTheme.primaryColor.withOpacity(0.15),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.5)),
              ),
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: AppTheme.textMuted,
              labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'My Aliases'),
                Tab(text: 'Register New'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyAliasesTab(),
          _buildRegisterTab(),
        ],
      ),
    );
  }

  Widget _buildMyAliasesTab() {
    if (_isProcessing && _ownedAliases.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    if (_ownedAliases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.alternate_email, size: 64, color: AppTheme.textMuted.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              'No aliases registered',
              style: GoogleFonts.inter(
                fontSize: 18,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Register a short alias to replace your long wallet address.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => _tabController.animateTo(1),
              child: const Text('Register Alias'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAliases,
      color: AppTheme.primaryColor,
      backgroundColor: AppTheme.cardColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _ownedAliases.length,
        itemBuilder: (context, index) {
          final alias = _ownedAliases[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    alias[0].toUpperCase(),
                    style: GoogleFonts.jetBrainsMono(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
              title: Text(
                '@$alias',
                style: GoogleFonts.jetBrainsMono(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              subtitle: Text(
                'Active & Linked',
                style: GoogleFonts.inter(
                  color: AppTheme.successColor,
                  fontSize: 12,
                ),
              ),
              trailing: const Icon(
                Icons.check_circle,
                color: AppTheme.successColor,
                size: 20,
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryColor.withOpacity(0.15), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.infoColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.alternate_email,
                        color: AppTheme.infoColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Map a human-readable name (max 8 chars) to your wallet address.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _aliasController,
                  maxLength: 8,
                  style: GoogleFonts.jetBrainsMono(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Desired Alias',
                    hintText: 'e.g. Satoshi',
                    prefixText: '@ ',
                    prefixStyle: GoogleFonts.jetBrainsMono(
                      color: AppTheme.primaryColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _walletFileController,
                  style: GoogleFonts.jetBrainsMono(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Wallet File Path',
                    hintText: '/path/to/wallet.file',
                    prefixIcon: Icon(Icons.folder_open, size: 20),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Wallet Password',
                    prefixIcon: Icon(Icons.lock_outline, size: 20),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _registerAlias,
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('REGISTER ALIAS'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
