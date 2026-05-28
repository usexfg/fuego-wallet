import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../services/walletd_service.dart';
import '../../utils/theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isWalletdReady = false;
  bool _isCliReady = false;

  @override
  void initState() {
    super.initState();
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    // Check if binaries are available
    try {
      await WalletdService.instance.initialize();
      setState(() {
        _isWalletdReady = true;
      });
    } catch (e) {
      setState(() {
        _isWalletdReady = false;
      });
    }

    // Check for CLI binary
    try {
      final binaryPath = await _getCliBinaryPath();
      final file = File(binaryPath);
      if (await file.exists()) {
        setState(() {
          _isCliReady = true;
        });
      }
    } catch (e) {
      setState(() {
        _isCliReady = false;
      });
    }
  }

  Future<String> _getCliBinaryPath() async {
    final Directory appDir = await getApplicationSupportDirectory();
    final String binaryName = Platform.isWindows
        ? 'xfg-stark-windows.exe'
        : Platform.isMacOS
            ? 'xfg-stark-macos'
            : 'xfg-stark-linux';
    return path.join(appDir.path, 'bin', binaryName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('fuego-wallet'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showInfoDialog();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 32,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Decentralized Privacy Banking',
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
                    'Your gateway to Fuego ecosystem',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.account_balance,
                    title: 'CD Banking',
                    subtitle: 'Earn Interest',
                    color: const Color(0xFF4A90E2),
                    onPressed: () {
                      Navigator.pushNamed(context, '/cd');
                    },
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.alternate_email,
                    title: 'Fire Aliases',
                    subtitle: 'Wallet Naming',
                    color: AppTheme.infoColor,
                    onPressed: () {
                      Navigator.pushNamed(context, '/aliases');
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Quick Access
            const Text(
              'Quick Access',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),

            const SizedBox(height: 12),

            GridView.count(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildFeatureCard(
                  context,
                  icon: Icons.local_fire_department,
                  title: 'Mint HEAT',
                  subtitle: 'Burn XFG',
                  color: AppTheme.errorColor,
                  onPressed: () {
                    Navigator.pushNamed(context, '/heat');
                  },
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.swap_horiz,
                  title: 'Atomic Swaps',
                  subtitle: 'Trade across chains',
                  color: Colors.orangeAccent,
                  onPressed: () {
                    Navigator.pushNamed(context, '/swaps');
                  },
                ),
                _buildFeatureCard(
                  context,
                  icon: Icons.auto_graph,
                  title: 'Hearth AMM',
                  subtitle: 'Liquidity Pools',
                  color: const Color(0xFF26A69A),
                  onPressed: () {
                    Navigator.pushNamed(context, '/swaps');
                  },
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Service Status
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Service Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildStatusRow('Integrated Walletd', _isWalletdReady),
                  const SizedBox(height: 4),
                  _buildStatusRow('Optimizer (CLI/RPC)', _isCliReady || _isWalletdReady),
                  const SizedBox(height: 4),
                  _buildStatusRow('Burn2Mint (HEAT)', true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Row(
      children: [
        Icon(
          status ? Icons.check_circle : Icons.cancel,
          color: status ? AppTheme.successColor : AppTheme.errorColor,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed,
  ) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About fuego-wallet'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Version: 1.0.1\n\n'
                'Features:\n'
                '• Integrated walletd & optimizer\n'
                '• HEAT Flatcoin (Burn XFG → HEAT)\n'
                '• Hearth AMM\n'
                '• Cross-chain Atomic Swaps\n'
                '• Multi-platform support\n\n'
                'Built for the Fuego ecosystem',
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
