import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<WalletProvider>(
      builder: (context, provider, _) {
        final wallet = provider.wallet;
        final connected = provider.isConnected;
        final syncing = provider.isSyncing;

        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            backgroundColor: AppTheme.backgroundColor,
            elevation: 0,
            title: Text(
              'Fuego Wallet',
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: connected
                            ? AppTheme.successColor
                            : AppTheme.errorColor,
                        boxShadow: [
                          BoxShadow(
                            color: (connected ? AppTheme.successColor : AppTheme.errorColor)
                                .withOpacity(0.6),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      connected ? 'Connected' : 'Offline',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: connected ? AppTheme.successColor : AppTheme.errorColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, color: AppTheme.textMuted),
                onPressed: _showInfoDialog,
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Wallet Balance Card — replaces the useless banner
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: wallet != null
                      ? _buildBalanceContent(wallet, connected, syncing)
                      : _buildNoWalletContent(),
                ),
                const SizedBox(height: 24),

                // Quick Access Grid
                Text(
                  'Quick Access',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 12),

                GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.8,
                  children: [
                    _buildFeatureCard(
                      icon: Icons.local_fire_department,
                      title: 'Mint HEAT',
                      subtitle: 'Burn XFG',
                      color: AppTheme.primaryColor,
                      onTap: () => Navigator.pushNamed(context, '/heat'),
                    ),
                    _buildFeatureCard(
                      icon: Icons.swap_horiz,
                      title: 'SwapXFG',
                      subtitle: 'Atomic Swaps Protocol',
                      color: Colors.orangeAccent,
                      onTap: () => Navigator.pushNamed(context, '/swaps'),
                    ),
                    _buildFeatureCard(
                      icon: Icons.account_balance,
                      title: 'CD Banking',
                      subtitle: 'Earn Block Interest',
                      color: const Color(0xFF4A90E2),
                      onTap: () => Navigator.pushNamed(context, '/cd'),
                    ),
                    _buildFeatureCard(
                      icon: Icons.alternate_email,
                      title: 'Fire Aliases',
                      subtitle: 'Wallet Naming',
                      color: AppTheme.infoColor,
                      onTap: () => Navigator.pushNamed(context, '/aliases'),
                    ),
                    _buildFeatureCard(
                      icon: Icons.candlestick_chart,
                      title: 'Price Chart',
                      subtitle: 'XFG/USD History',
                      color: const Color(0xFFE8B84B),
                      onTap: () => Navigator.pushNamed(context, '/price-chart'),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Node Connection
                if (wallet != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.dividerColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Node Status',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildStatusRow(
                          provider.isConnected
                              ? 'Connected to 207.244.247.64:18180'
                              : 'Not connected — check daemon',
                          connected,
                        ),
                        const SizedBox(height: 4),
                        _buildStatusRow(
                          syncing
                              ? 'Syncing blocks... ${wallet!.localHeight}/${wallet!.blockchainHeight}'
                              : wallet!.synced
                                  ? 'Synced — Height ${wallet!.blockchainHeight}'
                                  : 'Wallet ready',
                          wallet!.synced,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBalanceContent(
      dynamic wallet, bool connected, bool syncing) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wallet address
        Row(
          children: [
            const Icon(Icons.account_balance_wallet, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                wallet.address.isNotEmpty
                    ? '${wallet.address.substring(0, 12)}...${wallet.address.substring(wallet.address.length - 8)}'
                    : 'Address loading...',
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // XFG Balance
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              wallet.balanceXFG.toStringAsFixed(8),
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                'XFG',
                style: TextStyle(
                  color: Color(0xFFFFD700),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Available: ${wallet.unlockedBalanceXFG.toStringAsFixed(8)} XFG',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 12),

        // HEAT Balance
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              wallet.totalBalanceHEAT.toStringAsFixed(4),
              style: GoogleFonts.jetBrainsMono(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(bottom: 3),
              child: Text(
                'HⲶ∆T',
                style: TextStyle(
                  color: Colors.orangeAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Available: ${wallet.availableBalanceHEAT.toStringAsFixed(4)} HEAT',
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildNoWalletContent() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.account_balance_wallet, color: Colors.white, size: 32),
            SizedBox(width: 12),
            Text(
              'No Wallet Loaded',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          'Create or restore a wallet to view your balances',
          style: TextStyle(fontSize: 14, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool ok) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.cancel,
          color: ok ? AppTheme.successColor : AppTheme.errorColor,
          size: 14,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text(
          'Fuego Wallet',
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Version: 5.0.0\n\n'
                'Fuego Network Features:\n'
                '• XFG & HⲶ∆T dual-asset wallet\n'
                '• HⲶ∆T Flatcoin — Burn XFG to mint\n'
                '• Hearth AMM — Decentralized exchange\n'
                '• Certificate of Deposit (CD) Banking\n'
                '• Atomic Swaps via SwapXFG protocol\n'
                '• Fire Aliases — Human-readable addresses\n'
                '• Encrypted Blockchain Messaging\n\n'
                'Built on the Fuego L1 protocol.\n'
                'Connected via daemon at 207.244.247.64:18180',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
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
}
