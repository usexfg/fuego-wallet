import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../utils/theme.dart';
import '../../services/cli_service.dart';

class BankingScreen extends StatefulWidget {
  const BankingScreen({super.key});

  @override
  State<BankingScreen> createState() => _BankingScreenState();
}

class _BankingScreenState extends State<BankingScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedBurnOption = 'standard';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Generating STARK proof...'),
          ],
        ),
      ),
    );

    try {
      // Get wallet provider for private key
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      
      // Get the actual private key from the wallet provider
      final wallet = walletProvider.wallet;
      
      if (wallet == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wallet not loaded. Please unlock your wallet first.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      // Try to get private key directly first (if wallet is unlocked)
      String? privateKey = walletProvider.getPrivateKey();
      
      // If not available, prompt for PIN
      if (privateKey == null) {
        final pin = await _showPinDialog(context);
        if (pin == null) {
          return; // User cancelled
        }
        
        // Get private key with PIN verification
        privateKey = await walletProvider.getPrivateKeyForBurn(pin);
        if (privateKey == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to access private key. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
      
      // Validate private key format
      if (!walletProvider.isValidPrivateKey(privateKey)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid private key format. Please check your wallet.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      const String recipientAddress = '0x0000000000000000000000000000000000000000';
      
      // Generate STARK proof using CLI
      final BurnProofResult result = await CLIService.generateBurnProof(
        transactionHash: 'burn_${DateTime.now().millisecondsSinceEpoch}', // Generate a unique transaction hash
        burnAmount: burnAmount.toInt(),
        recipientAddress: recipientAddress,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully burned $burnAmount XFG to mint $heatAmount Ξmbers\nProof Hash: ${result.proofHash}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Show PIN dialog for private key access
  Future<String?> _showPinDialog(BuildContext context) async {
    final pinController = TextEditingController();
    
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Enter PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please enter your PIN to access your private key for the burn transaction:'),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(pinController.text),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text(
          'Banking',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          tabs: const [
            Tab(text: 'Mint HEAT'),
            Tab(text: 'COLD Banking'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMintHeatTab(),
          _buildCDBankingTab(),
        ],
      ),
    );
  }

  Widget _buildMintHeatTab() {
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
                      'Mint Fuego Ξmbers',
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
          const SizedBox(height: 24),

          // Burn Options
          Text(
            'Burn Amount Options',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          // Standard Option
          _buildBurnOptionCard(
            title: 'Standard Burn',
            burnAmount: '0.8 XFG',
            heatAmount: '8 Million HEAT',
            description: 'Standard burn amount for basic uses like C0DL3 gas fees',
            isSelected: _selectedBurnOption == 'standard',
            onTap: () => setState(() => _selectedBurnOption = 'standard'),
          ),
          const SizedBox(height: 16),

          // Large Option
          _buildBurnOptionCard(
            title: 'Large Burn',
            burnAmount: '800 XFG',
            heatAmount: '8 Billion HEAT',
            description: 'Larger HEAT mint. Amounts are kept uniform for higher privacy',
            isSelected: _selectedBurnOption == 'large',
            onTap: () => setState(() => _selectedBurnOption = 'large'),
          ),
          const SizedBox(height: 32),

          // Burn Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _burnXFG(_selectedBurnOption),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.local_fire_department,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Burn ${_selectedBurnOption == 'standard' ? '0.8' : '800'} XFG & Mint HEAT',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

            const SizedBox(height: 24),

          // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.textMuted.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.accentColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Fuego Ξmbers (HEAT) are the atomic equivalent ERC20 token of XFG minted on Ethereum L1 using Arbitrum L2 for gas-efficiency (verifying STARKs is thirsty work). HEAT will function as the gas token for Fuego\'s C0DL3 rollup powering CD, PARA, COLDAO, & Fuego Mob (community) interest yield assets.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCDBankingTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
              ),
              borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  children: [
                    Icon(
                      Icons.account_balance,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'CD Yield Banking',
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
                  'Earn CD interest by depositing XFG certificates',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Current Deposits
                  Text(
            'Your CD Deposits',
                    style: TextStyle(
              fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),

          _buildCDDepositCard(
            amount: '1000 XFG',
            interestRate: '12.5%',
            maturityDate: '2025-06-15',
            daysRemaining: 45,
          ),
          const SizedBox(height: 16),

          // No deposits message if empty
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.textMuted.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  color: AppTheme.textMuted,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Active CD Deposits',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Deposit XFG to start earning interest',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // New Deposit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('New CD deposit functionality coming soon!'),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                );
                      },
                      style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(20),
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Open New CD Deposit',
                        style: TextStyle(
                      fontSize: 18,
                          fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // CD Options
          Text(
            'Available CD Terms',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),

          _buildCDTermCard(
            term: '3 Months',
            interestRate: '8%',
            minimumDeposit: '8 XFG',
          ),
          const SizedBox(height: 12),

          _buildCDTermCard(
            term: '3 Months',
            interestRate: '18%',
            minimumDeposit: '800 XFG',
          ),
          const SizedBox(height: 12),

          _buildCDTermCard(
            term: '3 Months',
            interestRate: '33%',
            minimumDeposit: '8000 XFG',
          ),
        ],
      ),
    );
  }

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
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.1) : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryColor : AppTheme.accentColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.local_fire_department,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Text(
              title,
              style: TextStyle(
                      fontSize: 18,
                fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Burn $burnAmount → Mint $heatAmount',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
                    description,
              style: TextStyle(
                fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppTheme.primaryColor,
                size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCDDepositCard({
    required String amount,
    required String interestRate,
    required String maturityDate,
    required int daysRemaining,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.textMuted.withOpacity(0.3),
        ),
      ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                amount,
                      style: TextStyle(
                  fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                  interestRate,
                        style: TextStyle(
                    color: const Color(0xFF4CAF50),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
          const SizedBox(height: 8),
                Text(
            'Matures: $maturityDate',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
            '$daysRemaining days remaining',
                  style: TextStyle(
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCDTermCard({
    required String term,
    required String interestRate,
    required String minimumDeposit,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.textMuted.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                term,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                'Min: $minimumDeposit',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          Text(
            interestRate,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF4CAF50),
            ),
          ),
        ],
      ),
    );
  }
}
