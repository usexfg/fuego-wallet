import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/security_service.dart';
import '../../utils/theme.dart';
import '../../widgets/pin_input_widget.dart';
import '../main/main_screen.dart';
import '../wallet_setup/setup_screen.dart';

class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({super.key});

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen>
    with TickerProviderStateMixin {
  final SecurityService _securityService = SecurityService();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _isLoading = false;
  String? _errorMessage;
  bool _isPasswordMode = false; // Toggle between PIN and password
  int _failedAttempts = 0;
  static const int maxFailedAttempts = 69;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    // Remove biometric auth initialization
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _fadeController.forward();
  }

  // Removed biometric authentication methods

  Future<void> _onPinComplete(String pin) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isValid = await _securityService.verifyPIN(pin);

      if (isValid) {
        await _unlockWallet(pin);
      } else {
        _handleFailedAttempt();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Authentication failed. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _unlockWallet(String credentials) async {
    try {
      final walletProvider = Provider.of<WalletProvider>(context, listen: false);
      final success = await walletProvider.unlockWallet(credentials);

      if (success && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      } else {
        setState(() {
          _errorMessage = walletProvider.error ?? 'Failed to unlock wallet';
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

  void _handleFailedAttempt() {
    setState(() {
      _failedAttempts++;
      _isLoading = false;

      if (_failedAttempts >= maxFailedAttempts) {
        _errorMessage = 'Too many failed attempts. Please restore your wallet.';
      } else {
        final remainingAttempts = maxFailedAttempts - _failedAttempts;
        _errorMessage = _isPasswordMode
            ? 'Incorrect password. Please enter the same password you used during setup. $remainingAttempts attempts remaining.'
            : 'Incorrect PIN. $remainingAttempts attempts remaining.';
      }
    });
  }

  void _onForgotPin() {
    _showResetWalletDialog();
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
                _isPasswordMode
                    ? 'If you\'ve forgotten your password, you\'ll need to reset your wallet using your backup phrase.'
                    : 'If you\'ve forgotten your PIN, you\'ll need to reset your wallet using your backup phrase.',
                style: const TextStyle(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.warningColor.withOpacity(0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: AppTheme.warningColor,
                      size: 20,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This will remove the current wallet from this device.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
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
              onPressed: () {
                Navigator.of(context).pop();
                _resetWallet();
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
    try {
      await _securityService.clearWalletData();

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const SetupScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error resetting wallet: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryColor.withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_fire_department,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Welcome Back',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isPasswordMode
                            ? 'Enter your password to unlock your wallet'
                            : 'Enter your PIN to unlock your wallet',
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isPasswordMode
                            ? 'Enter the same password you used during setup.\nIf you used a 6-digit PIN, click "Use 6-digit PIN instead".'
                            : 'Enter the same 6-digit PIN you used during setup.\nIf you used a text password, click "Use text password instead".',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textMuted,
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isLoading)
                        const Column(
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryColor,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Unlocking wallet...',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        )
                      else if (_isPasswordMode) ...[
                        _buildPasswordInput(),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isPasswordMode = false;
                                });
                              },
                              child: const Text('Use 6-digit PIN instead'),
                            ),
                          ],
                        ),
                      ] else ...[
                        PinInputWidget(
                          onComplete: _onPinComplete,
                          errorMessage: _errorMessage,
                          showForgotPin: _failedAttempts >= 3,
                          onForgotPin: _onForgotPin,
                          canUseBiometric: false, // Disable biometric
                          onBiometric: null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isPasswordMode = true;
                                });
                              },
                              child: const Text('Use text password instead'),
                            ),
                          ],
                        ),

                        // Failed attempts counter
                        if (_failedAttempts > 0) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warningColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Failed attempts: $_failedAttempts/$maxFailedAttempts',
                              style: const TextStyle(
                                color: AppTheme.warningColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                // Footer
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Your wallet is encrypted and stored securely on this device',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // Add password input widget
  Widget _buildPasswordInput() {
    final passwordController = TextEditingController();

    return Column(
      children: [
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.errorColor.withOpacity(0.3),
              ),
            ),
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppTheme.errorColor,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text(
                'Enter Password',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Enter the same password you used during wallet setup.\nIf you used a 6-digit PIN, click "Use 6-digit PIN instead".',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    _onPasswordComplete(value);
                  }
                },
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  if (passwordController.text.isNotEmpty) {
                    _onPasswordComplete(passwordController.text);
                  }
                },
                child: const Text('Unlock Wallet'),
              ),
              if (_failedAttempts >= 3)
                TextButton(
                  onPressed: _onForgotPin,
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(color: AppTheme.errorColor),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _onPasswordComplete(String password) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isValid = await _securityService.verifyPIN(password);

      if (isValid) {
        await _unlockWallet(password);
      } else {
        _handleFailedAttempt();
      }
    } catch (e) {
      setState(() {
        _errorMessage = _isPasswordMode
            ? 'Incorrect password. Please enter the same password you used during setup.'
            : 'Authentication failed. Please try again.';
        _isLoading = false;
      });
    }
  }
}
