import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../services/cli_service.dart';
import '../../services/walletd_service.dart';
import '../../services/web3_cold_service.dart';
import '../../models/transaction_model.dart';
import '../../providers/wallet_provider.dart';
import '../../models/wallet.dart';
import '../../utils/theme.dart';
import 'burn_deposits_screen.dart';

/// New Banking screen with renamed sections
/// - Ξternal Flame (formerly Burn2Mint)
/// - COLD (formerly COLD Banking)
class BankingScreen extends StatefulWidget {
  const BankingScreen({super.key});

  @override
  State<BankingScreen> createState() => _BankingScreenState();
}

class _BankingScreenState extends State<BankingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Burn tab state
  String _selectedBurnOption = 'standard';
  bool _isBurning = false;

  // COLD tab state
  bool _isConnectingWeb3 = false;
  bool _isWeb3Connected = false;
  String _coldAddress = '';
  Map<String, dynamic>? _coldBalance;
  String _web3Log = '';

  // Walletd integration state
  bool _isWalletdRunning = false;
  bool _isOptimizerRunning = false;
  String _serviceLog = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize services
    _initializeServices();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Initialize all services
  Future<void> _initializeServices() async {
    try {
      // Initialize walletd service
      await WalletdService.instance.initialize();
      WalletdService.instance.setWalletdLogCallback((log) {
        if (mounted) {
          setState(() {
            _serviceLog = 'walletd: $log\n$_serviceLog';
          });
        }
      });
      WalletdService.instance.setOptimizerLogCallback((log) {
        if (mounted) {
          setState(() {
            _serviceLog = 'optimizer: $log\n$_serviceLog';
          });
        }
      });
      WalletdService.instance.setStatusCallbacks(
        onWalletd: (running) {
          if (mounted) setState(() => _isWalletdRunning = running);
        },
        onOptimizer: (running) {
          if (mounted) setState(() => _isOptimizerRunning = running);
        },
      );

      // Initialize Web3 service
      await Web3COLDService.instance.initialize();
      Web3COLDService.instance.setLogCallback((log) {
        if (mounted) {
          setState(() {
            _web3Log = '$log\n$_web3Log';
          });
        }
      });
      Web3COLDService.instance.setConnectionCallback((connected) {
        if (mounted) setState(() => _isWeb3Connected = connected);
      });
      Web3COLDService.instance.setBalanceCallback((balance) {
        if (mounted) {
          setState(() {
            _coldBalance = balance;
          });
        }
      });
    } catch (e) {
      debugPrint('Service initialization error: $e');
    }
  }

  /// Perform XFG burn to mint HEAT
  Future<void> _burnXFG(String option) async {
    double burnAmount;
    String heatAmount;

    if (option == 'standard') {
      burnAmount = 0.8;
      heatAmount = '8 Million HEAT';
    } else {
      burnAmount = 800.0;
      heatAmount = '8 Billion HEAT';
    }

    setState(() {
      _isBurning = true;
    });

    try {
      // Check if walletd is running for integrated optimization
      if (WalletdService.instance.isWalletdRunning) {
        _showInfoDialog(
          'Integrated Burn',
          'Using walletd integrated burn proof generation...\n\n'
          'Amount: $burnAmount XFG\n'
          'Mint: $heatAmount',
        );

        // trigger integrated optimization
        await WalletdService.instance.optimizeWallet();
      } else {
        // Fallback to CLI-based burn proof
        _showInfoDialog(
          'CLI Burn',
          'Generating burn proof using xfg-stark-cli...\n\n'
          'Amount: $burnAmount XFG\n'
          'Mint: $heatAmount',
        );
      }

      // Navigate to burn deposits screen for complete process
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BurnDepositsScreen(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Burn process initiated for $burnAmount XFG to mint $heatAmount'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Burn failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBurning = false;
        });
      }
    }
  }

  /// Start walletd service for integrated operations
  Future<void> _startWalletd() async {
    setState(() {
      _isWalletdRunning = true;
    });

    final started = await WalletdService.instance.startWalletd(
      enableRpc: true,
      daemonAddress: 'localhost:8081',
    );

    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start walletd service'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isWalletdRunning = false;
      });
    }
  }

  /// Stop walletd service
  Future<void> _stopWalletd() async {
    await WalletdService.instance.stopWalletd();
    setState(() {
      _isWalletdRunning = false;
    });
  }

  /// Start optimizer service
  Future<void> _startOptimizer() async {
    setState(() {
      _isOptimizerRunning = true;
    });

    final started = await WalletdService.instance.startOptimizer(
      autoOptimize: true,
      scanInterval: 300,
    );

    if (!started && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to start optimizer service'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isOptimizerRunning = false;
      });
    }
  }

  /// Stop optimizer service
  Future<void> _stopOptimizer() async {
    await WalletdService.instance.stopOptimizer();
    setState(() {
      _isOptimizerRunning = false;
    });
  }

  /// Connect to Web3 for COLD token
  Future<void> _connectWeb3() async {
    if (_coldAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a COLD token address'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!Web3COLDService.instance.isValidEthereumAddress(_coldAddress)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid Ethereum address format'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isConnectingWeb3 = true;
    });

    try {
      // Try auto-connect first
      bool connected = Web3COLDService.instance.isConnected;
      if (!connected) {
        connected = await Web3COLDService.instance.connectAuto();
      }

      if (connected) {
        // Get balance
        final balance = await Web3COLDService.instance.getBalance(_coldAddress);
        if (balance != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('COLD Balance: ${balance['balance']} ${balance['symbol']}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Failed to connect to any Ethereum RPC endpoint');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Web3 connection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnectingWeb3 = false;
        });
      }
    }
  }

  /// Refresh COLD balance
  Future<void> _refreshCOLDalance() async {
    if (_coldAddress.isEmpty || !Web3COLDService.instance.isConnected) return;

    setState(() {
      _isConnectingWeb3 = true;
    });

    try {
      final balance = await Web3COLDService.instance.getBalance(_coldAddress);
      if (balance != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Balance refreshed: ${balance['balance']} ${balance['symbol']}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Refresh failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnectingWeb3 = false;
        });
      }
    }
  }

  /// Show info dialog
  void _showInfoDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Banking'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Ξternal Flame'), // Formerly "Mint HEAT"
            Tab(text: 'COLD Labs'), // Formerly "COLD Banking"
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEternalFlameTab(), // Formerly Mint HEAT
          _buildCOLDTab(), // Formerly COLD Banking
        ],
      ),
    );
  }

  /// Ξternal Flame Tab (Burn to mint HEAT)
  Widget _buildEternalFlameTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Ξternal Flame',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Burn XFG to mint Fuego Ξmbers (HEAT)',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Walletd Integration Panel
          _buildWalletdIntegrationPanel(),

          const SizedBox(height: 16),

          // Burn Options
          Text(
            'Select Burn Amount',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          _buildBurnOptionCard(
            title: 'Standard Burn',
            burnAmount: '0.8 XFG',
            heatAmount: '8 Million HEAT',
            description: 'Standard burn for basic uses like C0DL3 gas fees',
            isSelected: _selectedBurnOption == 'standard',
            onTap: () => setState(() => _selectedBurnOption = 'standard'),
          ),

          const SizedBox(height: 8),

          _buildBurnOptionCard(
            title: 'Large Burn',
            burnAmount: '800 XFG',
            heatAmount: '8 Billion HEAT',
            description: 'Large HEAT mint. Amounts kept uniform for higher privacy',
            isSelected: _selectedBurnOption == 'large',
            onTap: () => setState(() => _selectedBurnOption = 'large'),
          ),

          const SizedBox(height: 20),

          // Burn Action
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isBurning ? null : () => _burnXFG(_selectedBurnOption),
              icon: _isBurning
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.local_fire_department),
              label: Text(
                _isBurning
                  ? 'Processing Burn...'
                  : _selectedBurnOption == 'standard'
                      ? 'Burning 0.8 XFG to Mint 8M HEAT'
                      : 'Burning 800 XFG to Mint 8B HEAT',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Info Card
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
                Text(
                  'About Ξternal Flame (HEAT)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Fuego Ξmbers (HEAT) is an erc20 token of atomic equivalence for the smallest unit of Fuego's native XFG currency- called ħeat '
                  'minted on Ethereum L1 using Arbitrum L2 for gas-efficiency. '
                  'HEAT will function as the gas token (fwei) on Fuego\'s C0DL3 rollup '
                  'powering CD, PARA, COLDAO, & Fuego Mob interest yield assets.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    height: 1.4,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// COLD Tab (COLD token management with Web3)
  Widget _buildCOLDTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF4A90E2),
                  const Color(0xFF2D5F8D),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.savings,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'COLD Interest Lounge',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'COLD Token on Ethereum • Generate Interest via C0DL3',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Web3 Connection Panel
          _buildWeb3ConnectionPanel(),

          const SizedBox(height: 16),

          // COLD Balance Display
          if (_coldBalance != null) ...[
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
                  Text(
                    'COLD Balance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_coldBalance!['balance']} ${_coldBalance!['symbol']}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: AppTheme.primaryColor),
                        onPressed: _isConnectingWeb3 ? null : _refreshCOLDalance,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _coldBalance!['name'],
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Address: ${_coldBalance!['address'].substring(0, 6)}...${_coldBalance!['address'].substring(38)}',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Interest Generation Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4A90E2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.interests, color: const Color(0xFF4A90E2), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'C0DL3 Interest Generation',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF4A90E2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• COLD tokens generate interest via C0DL3 rollup\n'
                    '• Interest paid in HEAT tokens\n'
                    '• Connect your COLD address to track earnings\n'
                    '• Withdraw interest to any Ethereum address',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Empty state
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Center(
                child: Text(
                  'Connect your COLD token address to view balance and manage interest',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Web3 Logs (if connected)
          if (_isWeb3Connected && _web3Log.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Web3 Activity Log',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: 80,
                    child: SingleChildScrollView(
                      child: Text(
                        _web3Log.length > 500 ? _web3Log.substring(0, 500) + '...' : _web3Log,
                        style: TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: AppTheme.textMuted,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Service Integration Section
          if (_isWalletdRunning) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.sync, color: AppTheme.successColor, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Integrated Services',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildServiceIndicator('walletd', _isWalletdRunning),
                      const SizedBox(width: 12),
                      _buildServiceIndicator('optimizer', _isOptimizerRunning),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_serviceLog.isNotEmpty) ...[
                    Container(
                      height: 60,
                      child: SingleChildScrollView(
                        child: Text(
                          _serviceLog.length > 300 ? _serviceLog.substring(0, 300) + '...' : _serviceLog,
                          style: TextStyle(
                            fontSize: 9,
                            fontFamily: 'monospace',
                            color: AppTheme.textMuted,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isConnectingWeb3 ? null : _connectWeb3,
                  icon: _isConnectingWeb3
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.link),
                  label: Text(_isWeb3Connected ? 'Refresh Balance' : 'Connect Web3'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A90E2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isWalletdRunning ? _stopWalletd : _startWalletd,
                  icon: Icon(
                    _isWalletdRunning ? Icons.stop : Icons.play_arrow,
                    size: 20,
                  ),
                  label: Text(_isWalletdRunning ? 'Stop walletd' : 'Start walletd'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isWalletdRunning ? Colors.red : AppTheme.successColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Advanced Services Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isOptimizerRunning ? _stopOptimizer : _startOptimizer,
                  icon: Icon(
                    _isOptimizerRunning ? Icons.stop : Icons.rocket_launch,
                    size: 20,
                  ),
                  label: Text(_isOptimizerRunning ? 'Stop Optimizer' : 'Start Optimizer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isOptimizerRunning ? Colors.red : Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Show modal with COLD address input
                    _showCOLDAddressDialog();
                  },
                  icon: Icon(Icons.edit, size: 18),
                  label: const Text('Set COLD Address'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.interactiveColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build walletd integration panel
  Widget _buildWalletdIntegrationPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isWalletdRunning ? Icons.check_circle : Icons.info_outline,
                color: _isWalletdRunning ? AppTheme.successColor : AppTheme.warningColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Walletd Integration',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Switch(
                value: _isWalletdRunning,
                onChanged: (value) {
                  if (value) {
                    _startWalletd();
                  } else {
                    _stopWalletd();
                  }
                },
                activeColor: AppTheme.successColor,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isWalletdRunning
                ? 'walletd and optimizer are integrated directly into the GUI for seamless operation'
                : 'Enable walletd for integrated optimization and RPC wallet server functionality',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          _buildServiceIndicator('walletd', _isWalletdRunning),
          const SizedBox(height: 4),
          _buildServiceIndicator('optimizer', _isOptimizerRunning),
        ],
      ),
    );
  }

  /// Build Web3 connection panel
  Widget _buildWeb3ConnectionPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isWeb3Connected
              ? AppTheme.successColor.withOpacity(0.3)
              : AppTheme.dividerColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.link,
                color: _isWeb3Connected ? AppTheme.successColor : AppTheme.textMuted,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Ethereum Connection',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _isWeb3Connected
                      ? AppTheme.successColor.withOpacity(0.2)
                      : AppTheme.textMuted.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _isWeb3Connected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    color: _isWeb3Connected ? AppTheme.successColor : AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              labelText: 'COLD Token Address (0x...)',
              hintText: 'Enter your COLD token address',
              prefixIcon: Icon(Icons.account_balance_wallet, size: 18),
              filled: true,
              fillColor: AppTheme.backgroundColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppTheme.dividerColor),
              ),
            ),
            style: TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
            ),
            onChanged: (value) {
              setState(() {
                _coldAddress = value;
              });
            },
            onSubmitted: (_) => _connectWeb3(),
          ),
          if (Web3COLDService.instance.currentRpc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'RPC: ${Web3COLDService.instance.currentRpc}',
              style: TextStyle(
                fontSize: 10,
                color: AppTheme.textMuted,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build burn option card
  Widget _buildBurnOptionCard({
    required String title,
    required String burnAmount,
    required String heatAmount,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '$burnAmount → Mint $heatAmount',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build service status indicator
  Widget _buildServiceIndicator(String service, bool isRunning) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: isRunning ? AppTheme.successColor : AppTheme.textMuted,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          service,
          style: TextStyle(
            fontSize: 11,
            color: isRunning ? AppTheme.textPrimary : AppTheme.textMuted,
            fontWeight: isRunning ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  /// Show COLD address input dialog
  void _showCOLDAddressDialog() {
    final controller = TextEditingController(text: _coldAddress);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('COLD Token Address'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Ethereum Address',
            hintText: '0x...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _coldAddress = controller.text;
              });
              Navigator.of(context).pop();
              _connectWeb3();
            },
            child: const Text('Save & Connect'),
          ),
        ],
      ),
    );
  }
}
