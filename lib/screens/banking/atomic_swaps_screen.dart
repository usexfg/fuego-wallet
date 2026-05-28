import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:fuego_sdk/fuego_sdk.dart';
import '../../sdk/fuego_sdk_service.dart';
import '../../utils/theme.dart';
import '../../providers/wallet_provider.dart';
import '../../models/wallet.dart';
import '../../widgets/candlestick_chart.dart';
import '../../widgets/trading_pair_header.dart';

class AtomicSwapsScreen extends StatefulWidget {
  const AtomicSwapsScreen({super.key});

  @override
  State<AtomicSwapsScreen> createState() => _AtomicSwapsScreenState();
}

class _AtomicSwapsScreenState extends State<AtomicSwapsScreen>
    with TickerProviderStateMixin {
  final _sdk = FuegoSDKService.instance;

  // Hearth AMM state
  final _payController = TextEditingController();
  final _receiveController = TextEditingController();
  String _payAsset = 'XFG';
  String _receiveAsset = 'HEAT';
  double _poolRate = 100.0;
  PoolReserves? _poolReserves;
  bool _poolLoading = false;
  List<CandleData> _candles = [];
  double _priceChange24h = 0;

  // Cross-chain swap state
  final _ccAmountController = TextEditingController();
  final _ccAddressController = TextEditingController();
  String _targetChain = 'ETH';
  final List<SwapInfo> _activeSwaps = [];

  // Slippage state
  double _selectedSlippage = 0.5;

  // Join swap state
  final _joinSwapIdController = TextEditingController();

  // Polling
  Timer? _pollTimer;

  // Tab controller
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _payController.addListener(_onPayChanged);
    _loadActiveSwaps();
    _startPolling();
    _loadPoolReserves();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    _payController.dispose();
    _receiveController.dispose();
    _ccAmountController.dispose();
    _ccAddressController.dispose();
    _joinSwapIdController.dispose();
    super.dispose();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _refreshActiveSwaps();
    });
  }

  void _onPayChanged() {
    final pay = double.tryParse(_payController.text) ?? 0;
    if (pay <= 0) {
      _receiveController.text = '0.00';
      return;
    }
    _estimateOutput(pay);
  }

  Future<void> _estimateOutput(double pay) async {
    try {
      final payAtomic = (pay * 10000000).round();
      final outputAtomic = await _sdk.getEstimatedPoolOutput(
        inputAsset: _payAsset,
        inputAmount: payAtomic,
      );
      if (mounted) {
        _receiveController.text = (outputAtomic / 10000000.0).toStringAsFixed(6);
      }
    } catch (_) {
      if (mounted) {
        final received = _payAsset == 'XFG' ? pay / _poolRate : pay * _poolRate;
        _receiveController.text = received.toStringAsFixed(6);
      }
    }
  }

  void _swapDirection() {
    setState(() {
      final tempAsset = _payAsset;
      _payAsset = _receiveAsset;
      _receiveAsset = tempAsset;
      final tempText = _payController.text;
      _payController.text = _receiveController.text;
      _receiveController.text = tempText;
    });
  }

  Future<void> _executeSwap() async {
    final amount = double.tryParse(_payController.text) ?? 0;
    if (amount <= 0) return;

    final amountAtomic = (amount * 10000000).round();

    try {
      final result = await _sdk.poolSwap(
        inputAsset: _payAsset,
        inputAmount: amountAtomic,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Swapped ${result.inputDisplay} $_payAsset → ${result.outputDisplay} $_receiveAsset '
              '(fee: ${result.feeDisplay}, impact: ${result.priceImpactPercent.toStringAsFixed(2)}%)'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        final provider = Provider.of<WalletProvider>(context, listen: false);
        await provider.refreshWallet();
        _loadPoolReserves();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Swap failed: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _initiateCrossChainSwap() async {
    final amount = double.tryParse(_ccAmountController.text) ?? 0;
    final address = _ccAddressController.text.trim();
    if (amount <= 0 || address.isEmpty) return;

    final provider = Provider.of<WalletProvider>(context, listen: false);

    try {
      final swapInfo = await _sdk.initiateSwap(
        counterpartyAddress: address,
        xfgAmount: (amount * 10000000).round(),
        counterpartyAmount: (amount * 10000000).round(),
        counterpartyChain: _targetChain,
        walletFile: provider.walletFile,
        walletPassword: provider.walletPassword,
      );
      if (mounted) {
        setState(() => _activeSwaps.insert(0, swapInfo));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Swap initiated: ${swapInfo.swapId}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _joinExistingSwap() async {
    final swapId = _joinSwapIdController.text.trim();
    if (swapId.isEmpty) return;

    final provider = Provider.of<WalletProvider>(context, listen: false);

    try {
      final swapInfo = await _sdk.joinSwap(
        swapId: swapId,
        walletFile: provider.walletFile,
        walletPassword: provider.walletPassword,
      );
      if (mounted) {
        setState(() => _activeSwaps.insert(0, swapInfo));
        _joinSwapIdController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined swap: ${swapInfo.swapId}'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _loadActiveSwaps() async {
    // Try loading from known swap IDs or just show empty state
  }

  Future<void> _loadPoolReserves() async {
    setState(() => _poolLoading = true);
    try {
      final reserves = await _sdk.getPoolReserves();
      if (mounted) {
        setState(() {
          _poolReserves = reserves;
          _poolRate = reserves.heatReserve > 0
              ? reserves.xfgReserve / reserves.heatReserve.toDouble()
              : 100.0;
          _poolLoading = false;
          _seedChartData();
        });
      }
    } catch (_) {
      if (mounted) setState(() => _poolLoading = false);
      _sdk.initializePool(xfgAmount: 100000000000, heatAmount: 1000000000);
      try {
        final reserves = await _sdk.getPoolReserves();
        if (mounted) {
          setState(() {
            _poolReserves = reserves;
            _poolRate = reserves.heatReserve > 0
              ? reserves.xfgReserve / reserves.heatReserve.toDouble()
              : 100.0;
            _poolLoading = false;
            _seedChartData();
          });
        }
      } catch (_) {
        if (mounted) setState(() => _poolLoading = false);
        _seedChartData();
      }
    }
  }

  void _seedChartData() {
    if (_candles.isEmpty) {
      _candles = generateSampleCandles(_poolRate, 48);
      if (_candles.length >= 2) {
        final first = _candles[_candles.length - 25].close;
        final last = _candles.last.close;
        _priceChange24h = first > 0 ? ((last - first) / first) * 100 : 0;
      }
    }
  }

  Future<void> _refreshActiveSwaps() async {
    for (int i = _activeSwaps.length - 1; i >= 0; i--) {
      try {
        final info = await _sdk.getSwapInfo(_activeSwaps[i].swapId);
        if (mounted) {
          setState(() => _activeSwaps[i] = info);
        }
      } catch (_) {
        if (mounted) {
          setState(() => _activeSwaps.removeAt(i));
        }
      }
    }
  }

  Color _swapColor(SwapState state) {
    switch (state) {
      case SwapState.initiated:
        return const Color(0xFFFFD700);
      case SwapState.participantJoined:
        return const Color(0xFFFF9800);
      case SwapState.fundsLocked:
        return const Color(0xFFFF5722);
      case SwapState.completed:
        return AppTheme.successColor;
      case SwapState.refunded:
        return AppTheme.textMuted;
      case SwapState.failed:
        return AppTheme.errorColor;
    }
  }

  String _swapLabel(SwapState state) {
    switch (state) {
      case SwapState.initiated:
        return 'INITIATED';
      case SwapState.participantJoined:
        return 'JOINED';
      case SwapState.fundsLocked:
        return 'FUNDS LOCKED';
      case SwapState.completed:
        return 'COMPLETED';
      case SwapState.refunded:
        return 'REFUNDED';
      case SwapState.failed:
        return 'FAILED';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        title: const Text(
          'Hearth AMM & Atomic Swaps',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryLight, AppTheme.primaryColor],
                ),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textMuted,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              dividerColor: Colors.transparent,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Hearth AMM'),
                Tab(text: 'Cross-chain'),
                Tab(text: 'Join Swap'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildHearthAMMTab(),
          _buildCrossChainTab(),
          _buildJoinSwapTab(),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 1: Hearth AMM
  // ──────────────────────────────────────────────

  Widget _buildHearthAMMTab() {
    final provider = Provider.of<WalletProvider>(context);
    final xfgBal = provider.wallet?.unlockedBalanceXFG ?? 0;
    final heatBal = provider.wallet?.availableBalanceHEAT ?? 0;

    final price = _poolRate;
    final lastCandle = _candles.isNotEmpty ? _candles.last : null;
    final high24h = _candles.isNotEmpty
        ? _candles.map((c) => c.high).reduce(max)
        : price;
    final low24h = _candles.isNotEmpty
        ? _candles.map((c) => c.low).reduce(min)
        : price;
    final vol24h = _candles.isNotEmpty
        ? _candles.map((c) => c.volume).reduce((a, b) => a + b)
        : 0.0;

    return SingleChildScrollView(
      child: Column(
        children: [
          TradingPairHeader(
            baseAsset: _receiveAsset,
            quoteAsset: _payAsset,
            price: price,
            change24h: _priceChange24h,
            high24h: high24h,
            low24h: low24h,
            volume24h: vol24h,
          ),
          SizedBox(
            height: 360,
            child: _candles.isNotEmpty
                ? TradingChart(candles: _candles)
                : const Center(
                    child: Text('Loading chart...',
                        style: TextStyle(color: Color(0xFF6B6B6B))),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: _buildCompactSwapCard(xfgBal, heatBal),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _buildPoolInfoRow(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildCompactSwapCard(double xfgBal, double heatBal) {
    final bal = _payAsset == 'XFG' ? xfgBal : heatBal;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.15),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _buildInputRowCompact(
              label: 'You Pay',
              controller: _payController,
              selectedAsset: _payAsset,
              balance: bal,
              onAssetChanged: (v) {
                if (v != null) {
                  setState(() {
                    _payAsset = v;
                    _receiveAsset = v == 'XFG' ? 'HEAT' : 'XFG';
                    _onPayChanged();
                  });
                }
              },
            ),
            const SizedBox(height: 4),
            Center(
              child: GestureDetector(
                onTap: _swapDirection,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.primaryColor.withOpacity(0.4),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.swap_vert,
                    color: AppTheme.primaryColor,
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _buildInputRowCompact(
              label: 'You Receive',
              controller: _receiveController,
              selectedAsset: _receiveAsset,
              readOnly: true,
              onAssetChanged: (_) {},
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _slippagePill(0.3),
                const SizedBox(width: 6),
                _slippagePill(0.5),
                const SizedBox(width: 6),
                _slippagePill(1.0),
                const Spacer(),
                Text(
                  'Fee: ${_poolReserves != null ? (_poolReserves!.feeBps / 100).toStringAsFixed(2) : '0.30'}%',
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildSwapButton(),
          ],
        ),
      ),
    );
  }

  Widget _slippagePill(double pct) {
    final isSelected = _selectedSlippage == pct;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedSlippage = pct);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor.withOpacity(0.15) : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor.withOpacity(0.5) : AppTheme.textMuted.withOpacity(0.2),
          ),
        ),
        child: Text(
          '${pct}%',
          style: TextStyle(
            color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildInputRowCompact({
    required String label,
    required TextEditingController controller,
    required String selectedAsset,
    required void Function(String?) onAssetChanged,
    bool readOnly = false,
    double balance = 0,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              readOnly: readOnly,
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  hintText: '0.00',
                  hintStyle: GoogleFonts.inter(
                    color: AppTheme.textMuted,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 11)),
                    if (balance > 0) ...[
                      const SizedBox(width: 4),
                      GestureDetector(
                        onTap: !readOnly
                            ? () {
                                controller.text = balance.toStringAsFixed(4);
                                _onPayChanged();
                              }
                            : null,
                        child: Text(
                          'Bal: ${balance.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppTheme.primaryColor.withOpacity(0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          _assetDropdown(selectedAsset, onAssetChanged, readOnly),
        ],
      ),
    );
  }

  Widget _buildPoolInfoRow() {
    final reserves = _poolReserves;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.textMuted.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          _poolStat('XFG', reserves?.xfgDisplay ?? 0, AppTheme.primaryColor),
          Container(
            width: 1,
            height: 14,
            color: AppTheme.textMuted.withOpacity(0.2),
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          _poolStat('HEAT', reserves?.heatDisplay ?? 0, AppTheme.accentColor),
          Container(
            width: 1,
            height: 14,
            color: AppTheme.textMuted.withOpacity(0.2),
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),
          _poolStat('Rate', _poolRate, AppTheme.textSecondary),
          const Spacer(),
          _poolStat('LP', reserves?.lpDisplay ?? 0, AppTheme.textMuted),
        ],
      ),
    );
  }

  Widget _assetDropdown(
    String selected,
    void Function(String?) onChanged,
    bool readOnly,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.textMuted.withOpacity(0.3)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          dropdownColor: AppTheme.cardColor,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          icon: const Icon(Icons.expand_more, color: AppTheme.textSecondary, size: 18),
          items: const [
            DropdownMenuItem(value: 'XFG', child: Text('XFG')),
            DropdownMenuItem(value: 'HEAT', child: Text('HEAT')),
          ],
          onChanged: readOnly ? null : onChanged,
        ),
      ),
    );
  }

  Widget _buildSwapButton() {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [AppTheme.primaryLight, AppTheme.primaryColor],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _executeSwap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.swap_horiz, size: 20),
            SizedBox(width: 8),
            Text(
              'SWAP',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _poolStat(String label, double value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          value >= 1000 ? '${(value / 1000).toStringAsFixed(1)}K' : value.toStringAsFixed(1),
          style: GoogleFonts.jetBrainsMono(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────
  // TAB 2: Cross-chain Swaps
  // ──────────────────────────────────────────────

  Widget _buildCrossChainTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInitiateCard(),
          const SizedBox(height: 24),
          if (_activeSwaps.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active Swaps',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: _refreshActiveSwaps,
                  child: const Icon(Icons.refresh,
                      color: AppTheme.primaryColor, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...List.generate(_activeSwaps.length, (i) {
              return Padding(
                padding: EdgeInsets.only(bottom: i < _activeSwaps.length - 1 ? 10 : 0),
                child: _buildSwapItem(_activeSwaps[i]),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildInitiateCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Cross-chain Bridge',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildNetworkBox('Fuego Network', 'XFG', Icons.local_fire_department),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: const Icon(Icons.arrow_forward_rounded, color: AppTheme.primaryColor, size: 24),
                ),
                Expanded(
                  child: _buildDropdown(
                    label: 'Target Chain',
                    value: _targetChain,
                    items: const ['ETH', 'SOL', 'BTC'],
                    onChanged: (v) {
                      if (v != null) setState(() => _targetChain = v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Amount to Swap (XFG)',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _ccAmountController,
                    style: GoogleFonts.jetBrainsMono(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      filled: false,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: '0.00',
                      hintStyle: GoogleFonts.jetBrainsMono(
                        color: AppTheme.textMuted,
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recipient $_targetChain Address',
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                          // In a real app, use Clipboard
                          // final data = await Clipboard.getData('text/plain');
                          // if (data?.text != null) _ccAddressController.text = data!.text!;
                        },
                        child: const Text(
                          'PASTE',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                    TextField(
                      controller: _ccAddressController,
                      style: GoogleFonts.jetBrainsMono(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        hintText: 'Enter $_targetChain address',
                        hintStyle: GoogleFonts.inter(
                          color: AppTheme.textMuted,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _initiateCrossChainSwap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ).copyWith(
                  elevation: ButtonStyleButton.allOrNull(0.0),
                ),
                child: Ink(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryLight, AppTheme.primaryColor],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text(
                      'INITIATE BRIDGE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkBox(String name, String asset, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.textSecondary, size: 16),
              const SizedBox(width: 6),
              Text(
                name,
                style: const TextStyle(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            asset,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?)? onChanged,
  }) {
    IconData getIcon(String val) {
      switch(val) {
        case 'ETH': return Icons.diamond;
        case 'BTC': return Icons.currency_bitcoin;
        case 'SOL': return Icons.wb_sunny;
        default: return Icons.link;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: AppTheme.cardColor,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
              icon: const Icon(Icons.expand_more,
                  color: AppTheme.primaryColor, size: 18),
              items: items.map((e) {
                return DropdownMenuItem(
                  value: e, 
                  child: Row(
                    children: [
                      Icon(getIcon(e), size: 16, color: AppTheme.textPrimary),
                      const SizedBox(width: 8),
                      Text(e),
                    ],
                  )
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwapItem(SwapInfo swap) {
    final color = _swapColor(swap.state);
    final provider = Provider.of<WalletProvider>(context, listen: false);
    
    // Progress calculation
    double progress = 0.0;
    switch (swap.state) {
      case SwapState.initiated: progress = 0.2; break;
      case SwapState.participantJoined: progress = 0.4; break;
      case SwapState.fundsLocked: progress = 0.8; break;
      case SwapState.completed: progress = 1.0; break;
      case SwapState.refunded: progress = 1.0; break;
      case SwapState.failed: progress = 1.0; break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  swap.state == SwapState.completed ? Icons.check_circle : 
                  swap.state == SwapState.failed || swap.state == SwapState.refunded ? Icons.cancel : Icons.sync,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Swap ${swap.swapId.length > 8 ? swap.swapId.substring(0, 8) : swap.swapId}...',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(swap.xfgAmount / 10000000).toStringAsFixed(2)} XFG → ${swap.counterpartyChain}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withOpacity(0.4)),
                ),
                child: Text(
                  _swapLabel(swap.state),
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Magical Progress Bar
          Stack(
            children: [
              Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: 4,
                width: MediaQuery.of(context).size.width * 0.8 * progress,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (swap.state == SwapState.initiated || swap.state == SwapState.participantJoined || swap.state == SwapState.fundsLocked) ...[
            const SizedBox(height: 16),
            if (swap.state == SwapState.initiated)
              _actionButton(
                label: 'LOCK FUNDS',
                color: AppTheme.primaryColor,
                fullWidth: true,
                onTap: () async {
                  final result = await _sdk.lockSwapFunds(
                    swapId: swap.swapId,
                    walletFile: provider.walletFile,
                    walletPassword: provider.walletPassword,
                  );
                  if (result == FuegoError.FUEGO_OK && mounted) {
                    _refreshActiveSwaps();
                  }
                },
              ),
            if (swap.state == SwapState.participantJoined)
              _actionButton(
                label: 'LOCK COUNTERPARTY',
                color: AppTheme.warningColor,
                fullWidth: true,
                onTap: () async {
                  final result = await _sdk.lockCounterpartySwapFunds(
                    swapId: swap.swapId,
                    counterpartyTxHash: '',
                  );
                  if (result == FuegoError.FUEGO_OK && mounted) {
                    _refreshActiveSwaps();
                  }
                },
              ),
            if (swap.state == SwapState.fundsLocked)
              Row(
                children: [
                  _actionButton(
                    label: 'COMPLETE',
                    color: AppTheme.successColor,
                    onTap: () async {
                      final result = await _sdk.completeSwap(
                        swapId: swap.swapId,
                        walletFile: provider.walletFile,
                        walletPassword: provider.walletPassword,
                      );
                      if (result == FuegoError.FUEGO_OK && mounted) {
                        _refreshActiveSwaps();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  _actionButton(
                    label: 'REFUND',
                    color: AppTheme.warningColor,
                    onTap: () async {
                      final result = await _sdk.refundSwap(
                        swapId: swap.swapId,
                        walletFile: provider.walletFile,
                        walletPassword: provider.walletPassword,
                      );
                      if (result == FuegoError.FUEGO_OK && mounted) {
                        _refreshActiveSwaps();
                      }
                    },
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    final child = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.4)),
          color: color.withOpacity(0.08),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
    if (fullWidth) return SizedBox(width: double.infinity, child: child);
    return Expanded(child: child);
  }

  // ──────────────────────────────────────────────
  // TAB 3: Join Swap
  // ──────────────────────────────────────────────

  Widget _buildJoinSwapTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppTheme.accentColor.withOpacity(0.2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Join Existing Swap',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Enter the swap ID shared by the initiator to join their atomic swap.',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Swap ID',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _joinSwapIdController,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            filled: false,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Paste swap ID here',
                            hintStyle: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _joinExistingSwap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'JOIN SWAP',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (_activeSwaps.isNotEmpty) ...[
            const Text(
              'Your Active Swaps',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(_activeSwaps.length, (i) {
              return Padding(
                padding: EdgeInsets.only(bottom: i < _activeSwaps.length - 1 ? 10 : 0),
                child: _buildSwapItem(_activeSwaps[i]),
              );
            }),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────
  // TAB 4: CD Markets
  // ──────────────────────────────────────────────

