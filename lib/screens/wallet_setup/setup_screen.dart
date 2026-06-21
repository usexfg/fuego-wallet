import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import '../../utils/theme.dart';
import '../../providers/wallet_provider.dart';
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
              bool isDesktop = constraints.maxWidth > 600;

              if (isDesktop) {
                return _buildDesktopLayout();
              } else {
                return _buildMobileLayout();
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.all(48.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLogo(120),
                  const SizedBox(height: 32),
                  AnimatedTextKit(
                    animatedTexts: [
                      FadeAnimatedText(
                        'Welcome to Fuego Wallet',
                        textStyle: GoogleFonts.inter(
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
                    'Your gateway to secure, private banking and untraceable transactions.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildNetworkStatusBanner(),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(48.0, 12.0, 48.0, 48.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      children: [
                        _buildFeatureItem(
                          Icons.security,
                          'Untraceable Transactions',
                          'RingCT privacy for highest-possible confidentiality',
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureItem(
                          Icons.local_fire_department,
                          'HⲶ∆T Flatcoin',
                          'Burn XFG to mint HⲶ∆T — pegged to USD value',
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureItem(
                          Icons.account_balance,
                          'HⲶ∆T Certificates of Deposit',
                          'Lock HⲶ∆T to earn block interest on your deposits',
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureItem(
                          Icons.auto_graph,
                          'Hearth AMM',
                          'Swap XFG/HⲶ∆T through the embedded liquidity pool',
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureItem(
                          Icons.swap_horiz,
                          'SwapXFG Protocol',
                          'Trustless atomic swaps across blockchains',
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureItem(
                          Icons.alternate_email,
                          'Fire Aliases',
                          'Human-readable wallet addresses',
                        ),
                        const SizedBox(height: 12),
                        _buildFeatureItem(
                          Icons.message_outlined,
                          'Encrypted Messaging',
                          'Secure blockchain-based communication',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildActionButtons(),
                  const SizedBox(height: 32),
                  _buildDisclaimer(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
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
                  _buildLogo(100),
                  const SizedBox(height: 24),
                  AnimatedTextKit(
                    animatedTexts: [
                      FadeAnimatedText(
                        'Welcome to Fuego Wallet',
                        textStyle: GoogleFonts.inter(
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
                    'Your Fuego L1 gateway to secure, private banking and untraceable transactions.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
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
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildFeatureItem(
                      Icons.security,
                      'Untraceable Transactions',
                      'RingCT privacy for highest-possible confidentiality',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      Icons.local_fire_department,
                      'HⲶ∆T Flatcoin',
                      'Burn XFG to mint HⲶ∆T — pegged to USD value',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      Icons.account_balance,
                      'HⲶ∆T Certificates of Deposit',
                      'Lock HⲶ∆T to earn block interest on your deposits',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      Icons.auto_graph,
                      'Hearth AMM',
                      'Swap XFG/HⲶ∆T through the embedded liquidity pool',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      Icons.swap_horiz,
                      'SwapXFG Protocol',
                      'Trustless atomic swaps across blockchains',
                    ),
                    const SizedBox(height: 12),
                    _buildFeatureItem(
                      Icons.alternate_email,
                      'Fire Aliases',
                      'Human-readable wallet addresses',
                    ),
                  ],
                ),
              ),
            ),
          ),
          _buildNetworkStatusBanner(),
          const SizedBox(height: 16),
          _buildActionButtons(),
          const SizedBox(height: 16),
          _buildDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildLogo(double size) {
    return Container(
      width: size,
      height: size,
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
    );
  }

  Widget _buildNetworkStatusBanner() {
    return Consumer<WalletProvider>(
      builder: (context, provider, _) {
        final connected = provider.isConnected;
        final syncing = provider.isSyncing;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: connected
                ? AppTheme.successColor.withOpacity(0.1)
                : AppTheme.warningColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: connected
                  ? AppTheme.successColor.withOpacity(0.3)
                  : AppTheme.warningColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: connected ? AppTheme.successColor : AppTheme.warningColor,
                  boxShadow: [
                    BoxShadow(
                      color: (connected ? AppTheme.successColor : AppTheme.warningColor)
                          .withOpacity(0.6),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected ? 'Connected to Fuego Network' : 'Connecting to Fuego Network...',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: connected ? AppTheme.successColor : AppTheme.warningColor,
                      ),
                    ),
                    if (syncing)
                      Text(
                        'Syncing blockchain data...',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              if (!connected)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.warningColor),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.15),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryColor,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _navigateToCreateWallet,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Create New Wallet'),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _navigateToOpenExistingWallet,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Open Existing Wallet'),
          ),
        ),
      ],
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Fuego developers are unable to access or recover your private keys or mnemonic phrase. Please keep them safe and secure. Protecting access to your keys, protects access to your money.',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: AppTheme.textMuted,
        height: 1.4,
      ),
    );
  }
}
