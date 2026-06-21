import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/theme.dart';

class HeatPage extends StatefulWidget {
  const HeatPage({super.key});

  @override
  State<HeatPage> createState() => _HeatPageState();
}

class _HeatPageState extends State<HeatPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isBurning = false;
  String? _burnError;
  String? _burnSuccess;

  double get _burnAmount => double.tryParse(_amountController.text.trim()) ?? 0.0;

  @override
  void dispose() {
    _amountController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleBurn() async {
    final amountText = _amountController.text.trim();
    final password = _passwordController.text;

    if (amountText.isEmpty || password.isEmpty) {
      setState(() => _burnError = 'Amount and password are required');
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      setState(() => _burnError = 'Invalid amount');
      return;
    }

    setState(() {
      _isBurning = true;
      _burnError = null;
      _burnSuccess = null;
    });

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final sdkService = walletProvider.sdkService;

      final amountAtomic = (_burnAmount * 10000000).round();
      final txHash = await sdkService.wallet.burnXfg(amountAtomic);

      if (!mounted) return;
      setState(() {
        _isBurning = false;
        _burnSuccess = 'Burn transaction submitted: $txHash';
      });
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBurning = false;
        _burnError = 'Burn transaction failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<WalletProvider>(context);
    final xfgBal = provider.wallet?.unlockedBalanceXFG ?? 0.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Mint HEAT',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'HEAT Flatcoin Protocol',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary.withOpacity(0.7),
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.primaryColor.withOpacity(0.15),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.warningColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.local_fire_department,
                          color: AppTheme.warningColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Burn XFG to mint HEAT flatcoin. HEAT is pegged to the USD value.',
                          style: TextStyle(
                            fontSize: 14,
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
                        'Available Balance',
                        style: GoogleFonts.inter(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${xfgBal.toStringAsFixed(4)} XFG',
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
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      hintText: '0.00 XFG',
                      hintStyle: GoogleFonts.jetBrainsMono(
                        color: AppTheme.textMuted,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppTheme.surfaceColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      hintText: 'Wallet Password',
                      hintStyle: GoogleFonts.inter(
                        color: AppTheme.textMuted,
                        fontSize: 16,
                      ),
                      prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textMuted),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _isBurning ? null : _handleBurn,
                      icon: _isBurning
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.local_fire_department),
                      label: Text(
                        _isBurning ? 'Processing...' : 'BURN XFG',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          letterSpacing: 1.0,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  if (_burnError != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.errorColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, size: 16, color: AppTheme.errorColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _burnError!,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.errorColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                   if (_burnSuccess != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.successColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle, size: 16, color: AppTheme.successColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _burnSuccess!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.successColor,
                              ),
                            ),
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
      ),
    );
  }
}
