import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../sdk/fuego_sdk_service.dart';
import '../../utils/theme.dart';

class CDPage extends StatefulWidget {
  const CDPage({super.key});

  @override
  State<CDPage> createState() => _CDPageState();
}

class _CDPageState extends State<CDPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _amountController = TextEditingController();
  final _lockTimeController = TextEditingController();
  final _walletFileController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isProcessing = false;
  String? _error;
  String? _successTx;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    final walletProvider = context.read<WalletProvider>();
    if (walletProvider.walletFile.isNotEmpty) {
      _walletFileController.text = walletProvider.walletFile;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _lockTimeController.dispose();
    _walletFileController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _createCD() async {
    final amountText = _amountController.text.trim();
    final lockTimeText = _lockTimeController.text.trim();
    final walletFile = _walletFileController.text.trim();
    final password = _passwordController.text;

    if (amountText.isEmpty || lockTimeText.isEmpty || walletFile.isEmpty || password.isEmpty) {
      _showSnack('All fields are required', isError: true);
      return;
    }

    final amount = double.tryParse(amountText);
    final lockTime = int.tryParse(lockTimeText);

    if (amount == null || amount <= 0) {
      _showSnack('Invalid deposit amount', isError: true);
      return;
    }

    if (lockTime == null || lockTime <= 0) {
      _showSnack('Invalid lock time', isError: true);
      return;
    }

    setState(() {
      _isProcessing = true;
      _error = null;
      _successTx = null;
    });

    try {
      final cdInfo = await FuegoSDKService.instance.createCD(
        amount: (amount * 10000000).round(),
        lockTime: lockTime,
        walletFile: walletFile,
        walletPassword: password,
      );

      if (!mounted) return;
      
      _amountController.clear();
      _lockTimeController.clear();
      _passwordController.clear();
      
      setState(() {
        _successTx = cdInfo.txHash;
      });
      
      HapticFeedback.heavyImpact();
      _showSnack('CD Created Successfully!');
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
        backgroundColor: isError ? AppTheme.errorColor : AppTheme.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WalletProvider>();
    final balance = provider.wallet?.unlockedBalanceXFG ?? 0.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: Text(
          'CD Banking',
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
                Tab(text: 'Create CD'),
                Tab(text: 'My Active CDs'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCreateTab(balance),
          _buildMyCDsTab(),
        ],
      ),
    );
  }

  Widget _buildCreateTab(double balance) {
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
                        Icons.account_balance,
                        color: AppTheme.infoColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Lock XFG into a Certificate of Deposit to earn high-yield block interest.',
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available to Lock',
                      style: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${balance.toStringAsFixed(4)} XFG',
                      style: GoogleFonts.jetBrainsMono(
                        color: AppTheme.primaryColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  style: GoogleFonts.jetBrainsMono(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Deposit Amount (XFG)',
                    hintText: '0.00',
                    hintStyle: GoogleFonts.jetBrainsMono(
                      color: AppTheme.textMuted,
                      fontSize: 24,
                    ),
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _lockTimeController,
                  style: GoogleFonts.jetBrainsMono(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Lock Period (in seconds)',
                    hintText: 'e.g. 2592000 (30 days)',
                    prefixIcon: const Icon(Icons.timer_outlined, size: 20),
                    hintStyle: GoogleFonts.inter(
                      color: AppTheme.textMuted,
                      fontSize: 16,
                    ),
                  ),
                  keyboardType: TextInputType.number,
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
                    onPressed: _isProcessing ? null : _createCD,
                    child: _isProcessing
                        ? const SizedBox(
                            width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('CREATE CD DEPOSIT'),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.errorColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: AppTheme.errorColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.errorColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_successTx != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle, size: 16, color: AppTheme.successColor),
                            const SizedBox(width: 8),
                            Text(
                              'CD Created Successfully',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.successColor),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'TX: ${_successTx!}',
                          style: GoogleFonts.jetBrainsMono(fontSize: 11, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyCDsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: AppTheme.textMuted.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'No Active CDs Found',
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
              'Your active certificates of deposit and their accumulated interest will appear here after creation.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => _tabController.animateTo(0),
            child: const Text('Create New CD'),
          ),
        ],
      ),
    );
  }
}