import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/wallet_provider.dart';
import '../../services/heat_metrics_service.dart';
import '../../services/cli_service.dart';
import '../../utils/theme.dart';

class HeatPage extends StatefulWidget {
  const HeatPage({super.key});

  @override
  State<HeatPage> createState() => _HeatPageState();
}

class _HeatPageState extends State<HeatPage> with TickerProviderStateMixin {
  final HeatMetricsService _metricsService = HeatMetricsService.instance;

  HeatMetrics _metrics = HeatMetrics.empty;
  AMMPoolInfo _pool = AMMPoolInfo.empty;
  Map<String, dynamic> _nodeInfo = {};
  bool _isConnected = false;
  bool _isLoading = true;

  Timer? _refreshTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  final TextEditingController _walletPathController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _ethAddressController = TextEditingController();
  String _selectedBurnType = 'Standard Burn';
  bool _isBurning = false;
  BurnProofResult? _proofResult;
  String? _burnError;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _refreshData();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _pulseController.dispose();
    _glowController.dispose();
    _walletPathController.dispose();
    _passwordController.dispose();
    _ethAddressController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    try {
      final results = await Future.wait([
        _metricsService.getMetrics(),
        _metricsService.getAMMPoolInfo(),
        _metricsService.getNodeInfo(),
        _metricsService.testConnection(),
      ]);

      if (!mounted) return;
      setState(() {
        _metrics = results[0] as HeatMetrics;
        _pool = results[1] as AMMPoolInfo;
        _nodeInfo = results[2] as Map<String, dynamic>;
        _isConnected = results[3] as bool;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleBurn() async {
    final walletPath = _walletPathController.text.trim();
    final password = _passwordController.text;
    final ethAddress = _ethAddressController.text.trim();

    if (walletPath.isEmpty || password.isEmpty || ethAddress.isEmpty) {
      setState(() => _burnError = 'All fields are required');
      return;
    }

    if (!CLIService.isValidEthereumAddress(ethAddress)) {
      setState(() => _burnError = 'Invalid Ethereum address');
      return;
    }

    final burnAmount =
        CLIService.burnDenominations[_selectedBurnType] ?? 800000;

    setState(() {
      _isBurning = true;
      _burnError = null;
      _proofResult = null;
    });

    try {
      final result = await CLIService.generateBurnProof(
        transactionHash: 'tx_${DateTime.now().millisecondsSinceEpoch}',
        recipientAddress: ethAddress,
        burnAmount: burnAmount,
        burnType: _selectedBurnType,
      );

      if (!mounted) return;
      setState(() {
        _proofResult = result;
        _isBurning = false;
      });
      HapticFeedback.heavyImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _burnError = e.toString();
        _isBurning = false;
      });
    }
  }

  String _formatLargeNumber(double value) {
    if (value >= 1e9) return '${(value / 1e9).toStringAsFixed(1)}B';
    if (value >= 1e6) return '${(value / 1e6).toStringAsFixed(1)}M';
    if (value >= 1e3) return '${(value / 1e3).toStringAsFixed(1)}K';
    return value.toStringAsFixed(2);
  }

  String _formatNumber(double value) {
    if (value >= 1e9) {
      return '${(value / 1e9).toStringAsFixed(2)}B';
    }
    if (value >= 1e6) {
      return '${(value / 1e6).toStringAsFixed(2)}M';
    }
    if (value >= 1e3) {
      return '${(value / 1e3).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(4);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: _buildAppBar(),
      body: _isLoading ? _buildLoading() : _buildBody(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.backgroundColor,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mil\u00e6sandra',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            'HEAT Protocol Dashboard',
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary.withOpacity(0.7),
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
      actions: [
        _buildConnectionDot(),
        const SizedBox(width: 16),
      ],
    );
  }

  Widget _buildConnectionDot() {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isConnected
                ? AppTheme.successColor
                : AppTheme.errorColor,
            boxShadow: [
              BoxShadow(
                color: (_isConnected
                        ? AppTheme.successColor
                        : AppTheme.errorColor)
                    .withOpacity(_glowAnimation.value),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: AppTheme.primaryColor),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _refreshData,
      color: AppTheme.primaryColor,
      backgroundColor: AppTheme.surfaceColor,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSupplySection(),
          const SizedBox(height: 16),
          _buildPoolSection(),
          const SizedBox(height: 16),
          _buildTreasurySection(),
          const SizedBox(height: 16),
          _buildMintSection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: AppTheme.primaryColor),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhaseBadge() {
    String label;
    Color color;

    if (_metrics.isActivated) {
      label = 'ACTIVATED (\$1.50-\$2.50 band)';
      color = AppTheme.successColor;
    } else {
      label = 'BOOTSTRAP (fixed 0.2)';
      color = AppTheme.warningColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color ?? AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDarkCard({
    required Widget child,
    Color? borderColor,
    EdgeInsetsGeometry? padding,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor?.withOpacity(0.3) ??
                    AppTheme.primaryColor.withOpacity(0.15),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (borderColor ?? AppTheme.primaryColor)
                      .withOpacity(0.05),
                  blurRadius: 20,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildSupplySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('HEAT Supply', icon: Icons.whatshot),
        _buildDarkCard(
          borderColor: AppTheme.primaryColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildPhaseBadge(),
                  Text(
                    'Height: ${_nodeInfo['height'] ?? '--'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.whatshot,
                      iconColor: AppTheme.primaryColor,
                      label: 'HEAT Supply',
                      value: '${_formatLargeNumber(_metrics.heatSupply)} HEAT',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.local_fire_department,
                      iconColor: AppTheme.warningColor,
                      label: 'Burned XFG',
                      value: '${_formatNumber(_metrics.burnedXfg)} XFG',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Redemption Price',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '1 XFG = ${_formatNumber(_metrics.redemptionPrice)} HEAT',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(1.0 / (_metrics.redemptionPrice > 0 ? _metrics.redemptionPrice : 1)).toStringAsFixed(6)} XFG/HEAT',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 12,
                        color: AppTheme.textMuted.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoolSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Hearth AMM Pool', icon: Icons.auto_graph),
        _buildDarkCard(
          borderColor: AppTheme.accentColor,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildPoolReserve(
                      label: 'XFG Reserve',
                      value: '${_formatNumber(_pool.reserveXfg)} XFG',
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.compare_arrows,
                      color: AppTheme.textMuted.withOpacity(0.5),
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: _buildPoolReserve(
                      label: 'HEAT Reserve',
                      value: '${_formatNumber(_pool.reserveHeat)} HEAT',
                      color: AppTheme.accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.1),
                      AppTheme.accentColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Pool Ratio',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_pool.poolRatio.toStringAsFixed(2)} : 1',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'XFG / HEAT',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textMuted.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _buildStatRow('LP Shares',
                  _formatNumber(_pool.totalLpShares)),
              _buildStatRow('Accumulated Fees',
                  '${_formatNumber(_pool.accumulatedLpFees)} XFG',
                  color: AppTheme.successColor),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPoolReserve({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTreasurySection() {
    String modeLabel;
    Color modeColor;

    if (_pool.poolRatio > 4) {
      modeLabel = 'MINT MODE: Minting HEAT';
      modeColor = AppTheme.successColor;
    } else if (_pool.poolRatio > 2) {
      modeLabel = 'ROUTING: 40% \u2192 Treasury';
      modeColor = AppTheme.warningColor;
    } else {
      modeLabel = 'BUY MODE: Buying HEAT from Hearth';
      modeColor = AppTheme.primaryColor;
    }

    final rebalancerActive = _pool.poolRatio > 3;

    final cdYield = _metrics.epochSwapFees * 0.4;
    final treasuryAmount = _metrics.epochSwapFees * 0.6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Treasury & CD Yield', icon: Icons.account_balance),
        _buildDarkCard(
          borderColor: modeColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.savings,
                      iconColor: AppTheme.accentColor,
                      label: 'Treasury Balance',
                      value: '${_formatNumber(_metrics.treasuryBalance)} XFG',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildMetricTile(
                      icon: Icons.percent,
                      iconColor: _metrics.coverage > 50
                          ? AppTheme.successColor
                          : AppTheme.warningColor,
                      label: 'Coverage',
                      value: '${_metrics.coverage.toStringAsFixed(1)}%',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: modeColor.withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.alt_route,
                            size: 14, color: modeColor),
                        const SizedBox(width: 6),
                        Text(
                          'Yield Routing',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: _buildFlowChip(
                              'CD Yield Pool', cdYield.toStringAsFixed(2)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildFlowChip('Treasury',
                              treasuryAmount.toStringAsFixed(2)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: modeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.circle,
                              size: 6, color: modeColor),
                          const SizedBox(width: 6),
                          Text(
                            modeLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: modeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    rebalancerActive
                        ? Icons.check_circle
                        : Icons.pause_circle,
                    size: 14,
                    color: rebalancerActive
                        ? AppTheme.successColor
                        : AppTheme.textMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Rebalancer: ${rebalancerActive ? "ACTIVE" : "idle"}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: rebalancerActive
                          ? AppTheme.successColor
                          : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlowChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.cardDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          Text(
            '$value XFG',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMintSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Mint HEAT', icon: Icons.currency_exchange),
        _buildDarkCard(
          borderColor: AppTheme.successColor,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.warningColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.local_fire_department,
                      color: AppTheme.warningColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Burn XFG to mint HEAT tokens. A STARK proof is generated and submitted to the MintEngine.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _walletPathController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Wallet File Path',
                  hintText: '/path/to/wallet.file',
                  prefixIcon: Icon(Icons.folder_open, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Wallet Password',
                  prefixIcon: Icon(Icons.lock_outline, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _ethAddressController,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Ethereum Address',
                  hintText: '0x...',
                  prefixIcon: Icon(Icons.token, size: 20),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildBurnTypeChip('Standard Burn', '0.8 XFG'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildBurnTypeChip('Large Burn', '800 XFG'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isBurning ? null : _handleBurn,
                  icon: _isBurning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.rocket_launch),
                  label: Text(
                    _isBurning
                        ? 'Generating Proof...'
                        : 'Burn & Mint HEAT',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              if (_burnError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.errorColor.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 16, color: AppTheme.errorColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _burnError!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.errorColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (_proofResult != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.successColor.withOpacity(0.1),
                        AppTheme.successColor.withOpacity(0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.successColor.withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.check_circle,
                              size: 16, color: AppTheme.successColor),
                          const SizedBox(width: 8),
                          const Text(
                            'Proof Generated Successfully',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.successColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildStatRow('Proof Hash',
                          _proofResult!.proofHash.length > 40
                              ? '${_proofResult!.proofHash.substring(0, 40)}...'
                              : _proofResult!.proofHash),
                      _buildStatRow('Burn Amount',
                          '${_proofResult!.burnAmount} sat'),
                      _buildStatRow('HEAT to Mint',
                          '${CLIService.calculateHeatTokens(_proofResult!.burnAmount)} HEAT'),
                      _buildStatRow('Recipient',
                          '${_proofResult!.recipientAddress.substring(0, 20)}...'),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBurnTypeChip(String label, String sublabel) {
    final selected = _selectedBurnType == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedBurnType = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withOpacity(0.15)
              : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor.withOpacity(0.5)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 10,
                color: selected
                    ? AppTheme.primaryLight
                    : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
