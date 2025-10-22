import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/fuego_rpc_service.dart';
import '../../services/security_service.dart';
import '../../models/network_config.dart';
import '../../utils/theme.dart';
import '../wallet_setup/setup_screen.dart';
import 'network_selection_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SecurityService _securityService = SecurityService();
  bool _biometricEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final biometricEnabled = await _securityService.isBiometricEnabled();
    setState(() {
      _biometricEnabled = biometricEnabled;
    });
  }

  Future<void> _toggleBiometric(bool enabled) async {
    if (enabled) {
      final canUseBiometric = await _securityService.isBiometricAvailable();
      if (!canUseBiometric) {
        _showError('Biometric authentication not available on this device');
        return;
      }
      
      final authenticated = await _securityService.authenticateWithBiometrics(
        reason: 'Enable biometric authentication for XF₲ Wallet',
      );
      
      if (!authenticated) {
        return; // User cancelled or authentication failed
      }
    }

    await _securityService.setBiometricEnabled(enabled);
    setState(() {
      _biometricEnabled = enabled;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled 
              ? 'Biometric authentication enabled'
              : 'Biometric authentication disabled',
        ),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  void _showResetWalletDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: const Text(
            'Reset Wallet',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will permanently remove your wallet from this device. Make sure you have your backup phrase saved!',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.errorColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning,
                      color: AppTheme.errorColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action cannot be undone!',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _resetWallet();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorColor,
              ),
              child: const Text('Reset Wallet'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _resetWallet() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _securityService.clearWalletData();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SetupScreen()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to reset wallet: $e');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showNodeSelectionDialog() {
    final TextEditingController customNodeController = TextEditingController();
    String selectedNode = FuegoRPCService.defaultRemoteNodes.first;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardColor,
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.cloud,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Select Node',
                    style: TextStyle(color: AppTheme.textPrimary),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose a Fuego network node to connect to:',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ...FuegoRPCService.defaultRemoteNodes.map((node) => RadioListTile<String>(
                    title: Text(
                      node,
                      style: const TextStyle(color: AppTheme.textPrimary),
                    ),
                    value: node,
                    groupValue: selectedNode,
                    onChanged: (value) {
                      setState(() {
                        selectedNode = value!;
                        customNodeController.clear();
                      });
                    },
                    activeColor: AppTheme.primaryColor,
                  )),
                  const SizedBox(height: 16),
                  const Text(
                    'Or enter custom node:',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: customNodeController,
                    decoration: InputDecoration(
                      hintText: 'node.example.com:18180',
                      hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppTheme.primaryColor),
                      ),
                    ),
                    style: const TextStyle(color: AppTheme.textPrimary),
                    onChanged: (value) {
                      if (value.isNotEmpty) {
                        setState(() {
                          selectedNode = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();

                    final walletProvider = Provider.of<WalletProvider>(context, listen: false);
                    final nodeUrl = selectedNode.contains(':')
                        ? 'http://$selectedNode'
                        : 'http://$selectedNode:${FuegoRPCService.defaultRpcPort}';

                    await walletProvider.connectToNode(nodeUrl);

                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Connecting to $selectedNode...',
                            style: const TextStyle(color: Colors.white),
                          ),
                          backgroundColor: AppTheme.primaryColor,
                        ),
                      );
                    }
                  },
                  child: const Text('Connect'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.cardColor,
          title: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.local_fire_department,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'XF₲ Wallet',
                style: TextStyle(color: AppTheme.textPrimary),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Version 1.0.0',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'A privacy-focused cryptocurrency wallet for XF₲ (XFG)',
                style: TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              const Text(
                'Features:',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '• Private transactions with ring signatures\n'
                '• Encrypted blockchain messaging\n'
                '• Elderfier node participation\n'
                '• Built-in mining capabilities\n'
                '• Advanced security features',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
      ),
      body: Consumer<WalletProvider>(
        builder: (context, walletProvider, child) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Account section
              _buildSectionHeader('Account'),
              _buildSettingsTile(
                icon: Icons.account_balance_wallet,
                title: 'Wallet Address',
                subtitle: _truncateAddress(walletProvider.wallet?.address ?? 'Not available'),
                onTap: () {
                  // TODO: Show full address with QR code
                },
              ),
              _buildSettingsTile(
                icon: Icons.key,
                title: 'Backup Phrase',
                subtitle: 'View your wallet backup phrase',
                onTap: () {
                  // TODO: Show backup phrase with authentication
                },
                trailing: const Icon(Icons.chevron_right),
              ),
              
              const SizedBox(height: 24),
              
              // Security section
              _buildSectionHeader('Security'),
              _buildSettingsTile(
                icon: Icons.fingerprint,
                title: 'Biometric Authentication',
                subtitle: 'Use fingerprint or face recognition',
                trailing: Switch(
                  value: _biometricEnabled,
                  onChanged: _toggleBiometric,
                ),
              ),
              _buildSettingsTile(
                icon: Icons.lock_reset,
                title: 'Change PIN',
                subtitle: 'Update your wallet PIN',
                onTap: () {
                  // TODO: Implement PIN change flow
                },
                trailing: const Icon(Icons.chevron_right),
              ),
              
              const SizedBox(height: 24),
              
              // Network section
              _buildSectionHeader('Network'),
              _buildSettingsTile(
                icon: Icons.cloud,
                title: 'Node Connection',
                subtitle: walletProvider.isConnected
                    ? 'Connected to ${walletProvider.nodeUrl?.replaceAll('http://', '') ?? 'remote node'}'
                    : 'Disconnected',
                trailing: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: walletProvider.isConnected 
                        ? AppTheme.successColor 
                        : AppTheme.errorColor,
                    shape: BoxShape.circle,
                  ),
                ),
                onTap: _showNodeSelectionDialog,
              ),
              _buildSettingsTile(
                icon: walletProvider.networkConfig.isTestnet ? Icons.science : Icons.public,
                title: 'Network',
                subtitle: walletProvider.networkConfig.name,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: walletProvider.networkConfig.isTestnet 
                        ? Colors.orange.withOpacity(0.2)
                        : Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: walletProvider.networkConfig.isTestnet 
                          ? Colors.orange 
                          : Colors.green,
                      width: 1,
                    ),
                  ),
                  child: Text(
                    walletProvider.networkConfig.isTestnet ? 'TESTNET' : 'MAINNET',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: walletProvider.networkConfig.isTestnet 
                          ? Colors.orange 
                          : Colors.green,
                    ),
                  ),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const NetworkSelectionScreen(),
                    ),
                  );
                },
              ),
              _buildSettingsTile(
                icon: Icons.sync,
                title: 'Sync Status',
                subtitle: walletProvider.isWalletSynced 
                    ? 'Synchronized' 
                    : 'Syncing ${(walletProvider.syncProgress * 100).toStringAsFixed(1)}%',
                onTap: () {
                  // TODO: Show sync details
                },
              ),
              
              const SizedBox(height: 24),
              
              // App section
              _buildSectionHeader('App'),
              _buildSettingsTile(
                icon: Icons.info,
                title: 'About',
                subtitle: 'Version and app information',
                onTap: _showAboutDialog,
                trailing: const Icon(Icons.chevron_right),
              ),
              _buildSettingsTile(
                icon: Icons.help,
                title: 'Help & Support',
                subtitle: 'Get help using XF₲ Wallet',
                onTap: () {
                  // TODO: Open help/support
                },
                trailing: const Icon(Icons.chevron_right),
              ),
              
              const SizedBox(height: 32),
              
              // Danger zone
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.errorColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: AppTheme.errorColor,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Danger Zone',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _showResetWalletDialog,
                        icon: _isLoading 
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppTheme.errorColor,
                                  ),
                                ),
                              )
                            : const Icon(Icons.delete_forever),
                        label: const Text('Reset Wallet'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.errorColor,
                          side: const BorderSide(color: AppTheme.errorColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppTheme.primaryColor,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  String _truncateAddress(String address) {
    if (address.length <= 20) return address;
    return '${address.substring(0, 10)}...${address.substring(address.length - 10)}';
  }
}