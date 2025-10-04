import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../../utils/theme.dart';
import 'create_wallet_screen.dart';
import 'open_existing_wallet_screen.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutBack,
    ));

    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _slideController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _navigateToCreateWallet() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CreateWalletScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  void _navigateToOpenExistingWallet() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const OpenExistingWalletScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Use different layouts for desktop vs mobile
              bool isDesktop = constraints.maxWidth > 600;

              if (isDesktop) {
                return Row(
                  children: [
                    // Left side - Logo and welcome
                    Expanded(
                      flex: 1,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Padding(
                          padding: const EdgeInsets.all(48.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Logo
                              Container(
                                width: 120,
                                height: 120,
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
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Image.asset(
                                    'assets/logo/fuegologo.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Welcome text
                              AnimatedTextKit(
                                animatedTexts: [
                                  FadeAnimatedText(
                                    'Welcome to XF₲',
                                    textStyle: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                    duration: const Duration(milliseconds: 1200),
                                  ),
                                ],
                                totalRepeatCount: 1,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'Your gateway to private, secure, and decentralized cryptocurrency transactions',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 18,
                                  color: AppTheme.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Right side - Features and buttons (Scrollable)
                    Expanded(
                      flex: 1,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(48.0, 12.0, 48.0, 48.0),
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Features list
                              SlideTransition(
                                position: _slideAnimation,
                                child: Column(
                                  children: [
                                    _buildFeatureItem(
                                      Icons.security,
                                      'Untraceable Transactions',
                                      'Ring signatures for complete privacy',
                                    ),
                                    const SizedBox(height: 16),
                                    _buildFeatureItem(
                                      Icons.local_fire_department,
                                      'HEAT Ξmbers Minting',
                                      'Burn XFG to mint \$HEAT ERC20 tokens for zkC0DL3 gas',
                                    ),
                                    const SizedBox(height: 16),
                                    _buildFeatureItem(
                                      Icons.account_balance,
                                      'Private Banking',
                                      'High-yield CD interest on XFG deposits',
                                    ),
                                    const SizedBox(height: 16),
                                    _buildFeatureItem(
                                      Icons.message_outlined,
                                      'Encrypted Messaging',
                                      'Secure blockchain-based communication',
                                    ),
                                    const SizedBox(height: 16),
                                    _buildFeatureItem(
                                      Icons.account_tree,
                                      'Elderfier Staking',
                                      'Participate in network consensus',
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 48),
                              // Buttons
                              SizedBox(
                                width: 400,
                                child: Column(
                                  children: [
                                    ElevatedButton(
                                      onPressed: _navigateToCreateWallet,
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(double.infinity, 50),
                                      ),
                                      child: const Text('Create New Wallet'),
                                    ),
                                    const SizedBox(height: 16),
                                    OutlinedButton(
                                      onPressed: _navigateToOpenExistingWallet,
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size(double.infinity, 50),
                                      ),
                                      child: const Text('Open Existing Wallet'),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Terms and privacy
                              Text(
                                'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textMuted,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              } else {
                // Mobile layout (original)
                return Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      Expanded(
                        flex: 1,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Logo
                              Container(
                                width: 100,
                                height: 100,
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
                                child: Padding(
                                  padding: const EdgeInsets.all(6.0),
                                  child: Image.asset(
                                    'assets/logo/fuegologo.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              // Welcome text
                              AnimatedTextKit(
                                animatedTexts: [
                                  FadeAnimatedText(
                                    'Welcome to XF₲',
                                    textStyle: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.textPrimary,
                                    ),
                                    duration: const Duration(milliseconds: 1200),
                                  ),
                                ],
                                totalRepeatCount: 1,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Your gateway to private, secure, and decentralized cryptocurrency transactions',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppTheme.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Features list
                              _buildFeatureItem(
                                Icons.security,
                                'Untraceable Transactions',
                                'Ring signatures for complete privacy',
                              ),
                              const SizedBox(height: 16),
                              _buildFeatureItem(
                                Icons.local_fire_department,
                                'HEAT Ξmbers Minting',
                                'Burn XFG to mint \$HEAT ERC20 tokens for zkC0DL3 gas',
                              ),
                              const SizedBox(height: 16),
                              _buildFeatureItem(
                                Icons.account_balance,
                                'Private Banking',
                                'High-yield CD interest on XFG deposits',
                              ),
                              const SizedBox(height: 16),
                              _buildFeatureItem(
                                Icons.message_outlined,
                                'Encrypted Messaging',
                                'Secure blockchain-based communication',
                              ),
                              const SizedBox(height: 16),
                              _buildFeatureItem(
                                Icons.account_tree,
                                'Elderfier Staking',
                                'Participate in network consensus',
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            // Create wallet button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _navigateToCreateWallet,
                                child: const Text('Create New Wallet'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Open existing wallet button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _navigateToOpenExistingWallet,
                                child: const Text('Open Existing Wallet'),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Terms and privacy
                            Text(
                              'By continuing, you agree to our Terms of Service\nand Privacy Policy',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Custom page indicator widget for multi-step processes
class StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const StepIndicator({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index <= currentStep;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? AppTheme.primaryColor : AppTheme.textMuted,
          ),
        );
      }),
    );
  }
}