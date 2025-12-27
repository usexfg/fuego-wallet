import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../utils/theme.dart';
import '../../services/walletd_service.dart';
import '../../services/web3_cold_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isWalletdReady = false;
  bool _isWeb3Ready = false;
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

    try {
      await Web3COLDService.instance.initialize();
      setState(() {
        _isWeb3Ready = true;
      });
    } catch (e) {
      setState(() {
        _isWeb3Ready = false;
      });
    }

    // Check for CLI binary
    try {
      final binaryPath = await _getCliBinaryPath();
      final file = await File(binaryPath);
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
        ? 'xfg-stark-cli.exe'
        : Platform.isMacOS
            ? 'xfg-stark-cli-macos'
            : 'xfg-stark-cli-linux';
    return path.join(appDir.path, 'bin', binaryName);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('XF₲ Wallet'),
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
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome card
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: Colors.white,
                        size: 32.w,
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        'Decentralized Privacy Banking',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Your gateway to Fuego ecosystem',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // Quick Access
            Text(
              'Quick Access',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),

            SizedBox(height: 12.h),

            Expanded(
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 2,
                crossAxisSpacing: 12.w,
                mainAxisSpacing: 12.h,
                children: [
                  _buildFeatureCard(
                    context,
                    icon: Icons.local_fire_department,
                    title: 'Ξternal Flame',
                    subtitle: 'Mint HEAT',
                    color: AppTheme.errorColor,
                    onPressed: () {
                      Navigator.pushNamed(context, '/banking');
                    },
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.savings,
                    title: 'COLD Interest',
                    subtitle: 'Lounge',
                    color: const Color(0xFF4A90E2),
                    onPressed: () {
                      Navigator.pushNamed(context, '/banking');
                    },
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.sync,
                    title: 'Walletd',
                    subtitle: _isWalletdReady ? 'Available' : 'Not Found',
                    color: _isWalletdReady ? AppTheme.successColor : AppTheme.textMuted,
                    onPressed: () {
                      Navigator.pushNamed(context, '/banking');
                    },
                  ),
                  _buildFeatureCard(
                    context,
                    icon: Icons.rocket_launch,
                    title: 'Optimizer',
                    subtitle: _isCliReady ? 'Ready' : 'CLI Only',
                    color: _isCliReady ? Colors.orange : AppTheme.textMuted,
                    onPressed: () {
                      Navigator.pushNamed(context, '/banking');
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: 24.h),

            // Service Status
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Service Status',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  _buildStatusRow('Integrated Walletd', _isWalletdReady),
                  SizedBox(height: 4.h),
                  _buildStatusRow('Optimizer (CLI/RPC)', _isCliReady || _isWalletdReady),
                  SizedBox(height: 4.h),
                  _buildStatusRow('Web3 COLD Connection', _isWeb3Ready),
                  SizedBox(height: 4.h),
                  _buildStatusRow('Burn2Mint (Ξternal Flame)', true),
                ],
              ),
            ),

            SizedBox(height: 16.h),

            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: _buildQuickAction(
                    'Ξternal Flame',
                    Icons.local_fire_department,
                    AppTheme.errorColor,
                    () => Navigator.pushNamed(context, '/banking'),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: _buildQuickAction(
                    'COLD',
                    Icons.savings,
                    const Color(0xFF4A90E2),
                    () => Navigator.pushNamed(context, '/banking'),
                  ),
                ),
              ],
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
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32.w, color: color),
              SizedBox(height: 8.h),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 4.h),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.sp,
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
          size: 16.w,
        ),
        SizedBox(width: 8.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
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
      icon: Icon(icon, size: 20.w),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
        textStyle: TextStyle(
          fontSize: 14.sp,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About XF₲ Wallet'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Version: 1.0.1\n\n'
                'Features:\n'
                '• Integrated walletd & optimizer\n'
                '• Ξternal Flame (Burn XFG → HEAT)\n'
                '• COLD Interest Lounge (Web3)\n'
                '• C0DL3 rollup integration\n'
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
