import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../providers/wallet_provider.dart';
import '../../services/security_service.dart';
import '../../utils/theme.dart';
import '../main/main_screen.dart';
import '../../widgets/pin_input_widget.dart';

class PinSetupScreen extends StatefulWidget {
  final String mnemonic;
  final bool isRestore;

  const PinSetupScreen({
    super.key,
    required this.mnemonic,
    this.isRestore = false,
  });

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  String _firstPin = '';
  String _confirmPin = '';
  bool _isLoading = false;
  String? _errorMessage;
  final SecurityService _securityService = SecurityService();

  @override
  void initState() {
    super.initState();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _createWallet();
    }
  }



  void _onFirstPinComplete(String pin) {
    setState(() {
      _firstPin = pin;
      _errorMessage = null;
    });

    _nextPage();
  }

  void _onConfirmPinComplete(String pin) {
    setState(() {
      _confirmPin = pin;
      _errorMessage = null;
    });

    if (_firstPin == _confirmPin) {
      _nextPage();
    } else {
      setState(() {
        _errorMessage = 'PINs do not match. Please try again.';
        _confirmPin = '';
      });
    }
  }

  Future<void> _createWallet() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);

      bool success;
      if (widget.isRestore || widget.mnemonic.isEmpty) {
        // For restored or existing wallets, just store the PIN
        await _securityService.setPIN(_firstPin);
        success = true;
      } else {
        // For new wallets, create both the mnemonic storage and wallet file
        success = await walletProvider.createWallet(
          pin: _firstPin,
          mnemonic: widget.mnemonic,
        );

        // Create wallet file for new wallet
        if (success) {
          final tempDir = await getTemporaryDirectory();
          final walletPath = path.join(tempDir.path, 'wallet_${DateTime.now().millisecondsSinceEpoch}.wallet');
          final walletCreated = await walletProvider.createWalletFile(
            walletPath: walletPath,
            password: _firstPin,
          );
          if (!walletCreated) {
            throw Exception('Failed to create wallet file');
          }
        }
      }

      if (success) {
        // Navigate to main screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const MainScreen()),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to create wallet';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isRestore ? 'Restore Wallet' : 'Create Wallet'),
        backgroundColor: AppTheme.backgroundColor,
      ),
      body: Column(
        children: [
          // Step indicator
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: index <= _currentPage
                        ? AppTheme.primaryColor
                        : AppTheme.textMuted,
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              children: [
                _buildSetupPinPage(),
                _buildConfirmPinPage(),
                _buildSecurityOptionsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetupPinPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(
            Icons.lock,
            size: 80,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 24),
          const Text(
            'Create Your PIN',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Create a 6-digit PIN to secure your wallet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 48),
          PinInputWidget(
            onComplete: _onFirstPinComplete,
            errorMessage: _errorMessage,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildConfirmPinPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(
            Icons.lock,
            size: 80,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 24),
          const Text(
            'Confirm Your PIN',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your PIN again to confirm',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 48),
          PinInputWidget(
            onComplete: _onConfirmPinComplete,
            errorMessage: _errorMessage,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _errorMessage = null;
                  _confirmPin = '';
                });
              },
              child: const Text('Try Again'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityOptionsPage() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 32),
          const Icon(
            Icons.security,
            size: 80,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(height: 24),
          const Text(
            'Security Options',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your PIN is the only way to access your wallet. Store it securely.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 48),

          // Security tips
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warningColor.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: AppTheme.warningColor,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Important Security Notice',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.warningColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '• Never share your PIN with anyone\n'
                  '• If you forget your PIN, you\'ll need your backup phrase to restore your wallet\n'
                  '• Fuego cannot recover lost PINs',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          // Create wallet button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _createWallet,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(widget.isRestore ? 'Restore Wallet' : 'Create Wallet'),
            ),
          ),

          if (_errorMessage != null) ...[
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
                    Icons.error_outline,
                    color: AppTheme.errorColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.errorColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
