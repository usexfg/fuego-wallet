import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import '../../models/network_config.dart';
import '../../providers/wallet_provider.dart';
import '../../services/wallet_daemon_service.dart';
import '../../utils/theme.dart';

class NetworkSelectionScreen extends StatefulWidget {
  const NetworkSelectionScreen({super.key});

  @override
  State<NetworkSelectionScreen> createState() => _NetworkSelectionScreenState();
}

class _NetworkSelectionScreenState extends State<NetworkSelectionScreen> {
  NetworkConfig _selectedNetwork = NetworkConfig.mainnet;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Selection'),
        backgroundColor: AppTheme.backgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Choose Network',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select the Fuego network you want to connect to:',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Mainnet Option
            _buildNetworkCard(
              config: NetworkConfig.mainnet,
              icon: Icons.public,
              color: Colors.green,
              description: 'Production network with real XFG tokens',
            ),

            const SizedBox(height: 16),

            // Testnet Option
            _buildNetworkCard(
              config: NetworkConfig.testnet,
              icon: Icons.science,
              color: Colors.orange,
              description: 'Testing network with test tokens',
            ),

            const SizedBox(height: 32),

            // Network Info Card
            if (_selectedNetwork.isTestnet) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'Testnet Information',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• Test tokens have no real value\n'
                      '• Perfect for testing and development\n'
                      '• Faster block times for testing\n'
                      '• Separate from mainnet funds',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    if (_selectedNetwork.faucetUrl != null) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          // TODO: Open faucet URL
                        },
                        icon: const Icon(Icons.water_drop),
                        label: const Text('Get Test Tokens'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Connect Button
            ElevatedButton(
              onPressed: _isLoading ? null : _connectToNetwork,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedNetwork.isTestnet ? Colors.orange : AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Connecting...'),
                      ],
                    )
                  : Text('Connect to ${_selectedNetwork.name}'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkCard({
    required NetworkConfig config,
    required IconData icon,
    required Color color,
    required String description,
  }) {
    final isSelected = _selectedNetwork == config;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedNetwork = config;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.1)
              : AppTheme.backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppTheme.textSecondary.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildInfoChip('Daemon: ${config.daemonRpcPort}'),
                      const SizedBox(width: 8),
                      _buildInfoChip('Wallet: ${config.walletRpcPort}'),
                    ],
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.textSecondary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }

  Future<void> _connectToNetwork() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get wallet provider
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);

      // Stop any running wallet daemon first
      await WalletDaemonService.stopWalletd();
      debugPrint('Stopped existing wallet daemon');

      // Update network configuration
      await walletProvider.updateNetworkConfig(_selectedNetwork);
      debugPrint('Updated wallet provider network config');

      // Reinitialize wallet daemon service with new configuration
      // Use the first seed node's IP address for the daemon connection
      String daemonAddress;
      if (_selectedNetwork.seedNodes.isNotEmpty) {
        final defaultNode = _selectedNetwork.seedNodes[0];
        if (defaultNode.contains(':')) {
          daemonAddress = defaultNode.split(':')[0];
        } else {
          daemonAddress = defaultNode;
        }
      } else {
        daemonAddress = _selectedNetwork.defaultSeedNode.contains(':')
            ? _selectedNetwork.defaultSeedNode.split(':')[0]
            : _selectedNetwork.defaultSeedNode;
      }

      await WalletDaemonService.initialize(
        daemonAddress: daemonAddress,
        daemonPort: _selectedNetwork.daemonRpcPort,
        networkConfig: _selectedNetwork,
      );
      debugPrint('Reinitialized wallet daemon service');

      // Try to start wallet daemon with new network configuration
      // We need to create a temporary wallet since walletd requires a container file
      final tempDir = await getTemporaryDirectory();
      final tempWalletPath = path.join(tempDir.path, 'temp_wallet_${DateTime.now().millisecondsSinceEpoch}.wallet');

      // Create a temporary wallet for the new network
      final walletCreated = await WalletDaemonService.createWallet(
        walletPath: tempWalletPath,
        password: 'temp_password', // Temporary password for the temporary wallet
      );

      if (walletCreated) {
        // Start wallet daemon with the temporary wallet
        final walletStarted = await WalletDaemonService.startWalletd(
          walletPath: tempWalletPath,
          password: 'temp_password',
        );

        if (walletStarted) {
          debugPrint('Wallet daemon started successfully with new network config and temporary wallet');
          // Add a small delay to ensure the daemon is fully initialized
          await Future.delayed(const Duration(seconds: 2));

          // Clean up the temporary wallet after a delay
          Future.delayed(const Duration(seconds: 10), () {
            try {
              File(tempWalletPath).delete();
              debugPrint('Temporary wallet file deleted: $tempWalletPath');
            } catch (e) {
              debugPrint('Failed to delete temporary wallet file: $e');
            }
          });
        } else {
          debugPrint('Failed to start wallet daemon with temporary wallet');
        }
      } else {
        debugPrint('Failed to create temporary wallet for new network config');
        // Even if we can't create a temporary wallet, we can still update the network config
        // The user will need to unlock their wallet to get full functionality
      }

      // Refresh wallet data with new network
      try {
        await walletProvider.refreshWallet();
        debugPrint('Refreshed wallet data after network switch');
      } catch (e) {
        debugPrint('Failed to refresh wallet data after network switch: $e');
        // Continue anyway, as the network config has been updated
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedNetwork.isTestnet
                ? 'Switched to Testnet. Note: Testnet node may be offline.'
                : 'Switched to Mainnet'),
            backgroundColor: _selectedNetwork.isTestnet ? Colors.orange : Colors.green,
          ),
        );

        // Navigate back or to main screen
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
