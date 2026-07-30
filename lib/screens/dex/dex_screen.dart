import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/dex/dex_cubit.dart';
import '../../models/swap_models.dart';
import '../../models/candlestick.dart';
import '../../services/price_history_service.dart';
import '../../utils/theme.dart';
import '../../widgets/fuego_chart.dart';

class DexScreen extends StatefulWidget {
  const DexScreen({super.key});
  @override
  State<DexScreen> createState() => _DexScreenState();
}

class _DexScreenState extends State<DexScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _amountController = TextEditingController();
  final _rateController = TextEditingController();
  final _peerController = TextEditingController();
  String _selectedSpvPair = 'BTC';
  List<Candlestick>? _candles;

  static const Map<String, String> _spvPairNames = {
    'BTC': 'Bitcoin', 'LTC': 'Litecoin', 'KMD': 'Komodo', 'BCH': 'Bitcoin Cash',
    'ETH': 'Ethereum', 'ARB': 'Arbitrum', 'BASE': 'Base', 'BSC': 'BNB Chain',
    'SOL': 'Solana', 'POLY': 'Polygon', 'DCR': 'Decred', 'XMR': 'Monero',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadPriceData();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<DexCubit>().init());
  }

  Future<void> _loadPriceData() async {
    final candles = await PriceHistoryService().loadAll();
    if (mounted) setState(() => _candles = candles);
  }

  @override
  void dispose() {
    _tabController.dispose(); _amountController.dispose(); _rateController.dispose(); _peerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final tabH = screenH * 0.38;
    return BlocBuilder<DexCubit, DexState>(
      builder: (context, state) => Column(children: [
        Expanded(child: SingleChildScrollView(child: Column(children: [
          if (_candles != null && _candles!.isNotEmpty) SizedBox(height: screenH * 0.35, child: FuegoChart(candles: _candles!, pair: 'XFG/${state.selectedPair.ticker}')),
          _buildPairBar(state), _buildPriceBar(state),
          if (state.error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Text(state.error!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 11))),
          if (state.lastResult != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Text(state.lastResult!, style: const TextStyle(color: AppTheme.successColor, fontSize: 11))),
        ]))),
        _buildTabBar(),
        SizedBox(height: tabH, child: TabBarView(controller: _tabController, children: [
          _buildOrderbook(state), _buildTradeForm(state), _buildRecentTrades(state), _buildSpvSwapSection(state),
        ])),
      ]),
    );
  }

  Widget _buildTabBar() => Container(
    color: AppTheme.surfaceColor,
    child: TabBar(
      controller: _tabController, labelColor: AppTheme.primaryColor, unselectedLabelColor: AppTheme.textMuted,
      indicatorColor: AppTheme.primaryColor, labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      tabs: const [Tab(text: 'Orderbook'), Tab(text: 'Trade'), Tab(text: 'Trades'), Tab(text: 'Cross-Chain')],
    ),
  );

  Widget _buildPairBar(DexState state) => Container(
    padding: const EdgeInsets.all(8), color: AppTheme.surfaceColor,
    child: Row(children: [
      const Icon(Icons.currency_exchange, color: AppTheme.primaryColor, size: 20), const SizedBox(width: 8),
      const Text('XFG/', style: TextStyle(color: AppTheme.primaryColor, fontSize: 14, fontWeight: FontWeight.w600)),
      SizedBox(width: 90, child: DropdownButtonFormField<SwapPairSdk>(
        value: state.selectedPair, isExpanded: true, dropdownColor: AppTheme.cardColor,
        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
        decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6), border: OutlineInputBorder()),
        items: SwapPairSdk.values.map((p) => DropdownMenuItem(value: p, child: Text(p.ticker))).toList(),
        onChanged: (p) { if (p != null) context.read<DexCubit>().selectPair(p); },
      )),
      const SizedBox(width: 8),
      Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
        child: Text(state.selectedChain.symbol, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.w600))),
      const Spacer(),
      if (!state.isConnected) const Icon(Icons.cloud_off, color: AppTheme.errorColor, size: 16) else const Icon(Icons.cloud_done, color: AppTheme.successColor, size: 16),
      const SizedBox(width: 4),
      IconButton(icon: const Icon(Icons.refresh, size: 18, color: AppTheme.primaryColor), onPressed: () => context.read<DexCubit>().refresh(), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 32, minHeight: 32)),
    ]),
  );

  Widget _buildPriceBar(DexState state) {
    final p = state.price;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), color: AppTheme.surfaceColor.withOpacity(0.4),
      child: Row(children: [
        Text('XFG/${state.selectedPair.ticker}', style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)), const Spacer(),
        if (p != null) ...[
          Text('Last: ${p.last}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)), const SizedBox(width: 12),
          Text('\$${p.last}', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.bold)),
        ] else const Text('--', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ]),
    );
  }

  Widget _buildOrderbook(DexState state) {
    if (!state.isConnected) return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.cloud_off, color: AppTheme.textMuted, size: 48), const SizedBox(height: 16),
      Text('fuego-native DEX', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text(state.error ?? 'Connecting to fuegod...', style: const TextStyle(color: AppTheme.errorColor, fontSize: 13), textAlign: TextAlign.center),
      const SizedBox(height: 16),
      Text('No KDF required.\nSwap offers sourced from fuego P2P network.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12), textAlign: TextAlign.center),
    ]));
    if (state.isLoading && state.offers.isEmpty) return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    if (state.offers.isEmpty) return const Center(child: Text('No active offers', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)));
    return Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.surfaceColor))),
        child: Row(children: [
          Text('OFFERS (${state.offers.length})', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.w600)), const Spacer(),
          const Text('XFG', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)), const SizedBox(width: 4),
          const Text('Rate', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)), const SizedBox(width: 4),
          const Text('Time', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
        ])),
      Expanded(child: ListView.builder(itemCount: state.offers.length, itemBuilder: (context, i) => _offerRow(state.offers[i]))),
    ]);
  }

  Widget _offerRow(SwapOfferSdk o) {
    final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(o.createdAt * 1000));
    final ageStr = age.inHours > 0 ? '${age.inHours}h' : age.inMinutes > 0 ? '${age.inMinutes}m' : '${age.inSeconds}s';
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.surfaceColor))),
      child: Row(children: [
        Expanded(flex: 3, child: Text(o.pairLabel, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w500))),
        Expanded(flex: 2, child: Text('${(o.amount / 1e7).toStringAsFixed(2)} XFG', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11))),
        Expanded(flex: 2, child: Text(o.rateNum > 0 ? (o.rate).toStringAsFixed(4) : '--', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11))),
        Text(ageStr, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)), const SizedBox(width: 8),
        GestureDetector(onTap: () => _fillOffer(o), child: const Text('FILL', style: TextStyle(color: AppTheme.successColor, fontSize: 10, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  void _fillOffer(SwapOfferSdk offer) { _amountController.clear(); _rateController.text = offer.rateNum > 0 ? offer.rate.toStringAsFixed(4) : ''; _tabController.animateTo(1); }

  Widget _buildTradeForm(DexState state) => Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('Trade XFG/${state.selectedPair.ticker}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)), const SizedBox(height: 16),
    TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: 'XFG Amount', labelStyle: const TextStyle(color: AppTheme.textSecondary), hintText: '100.00', hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3))), focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor))),
      style: const TextStyle(color: AppTheme.textPrimary)),
    const SizedBox(height: 12),
    TextField(controller: _rateController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: 'Rate (${state.selectedPair.ticker} per XFG)', labelStyle: const TextStyle(color: AppTheme.textSecondary), hintText: state.price?.ask ?? '0.00', hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3))), focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor))),
      style: const TextStyle(color: AppTheme.textPrimary)),
    const SizedBox(height: 20),
    Row(children: [
      Expanded(child: ElevatedButton(onPressed: state.isLoading ? null : () => _submitOffer(state), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, padding: const EdgeInsets.symmetric(vertical: 14)),
        child: state.isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('POST OFFER', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      const SizedBox(width: 12),
      Expanded(child: ElevatedButton(onPressed: state.isLoading ? null : () => _requestSwap(state), style: ElevatedButton.styleFrom(backgroundColor: AppTheme.successColor, padding: const EdgeInsets.symmetric(vertical: 14)),
        child: state.isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('REQUEST SWAP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
    ]),
    const SizedBox(height: 16),
    if (state.price != null) ...[
      Text('Price Info', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)), const SizedBox(height: 4),
      _infoRow('Bid', state.price!.bid), _infoRow('Ask', state.price!.ask), _infoRow('Last', '\$${state.price!.last}'),
      _infoRow('24h Volume', state.price!.volume24h), _infoRow('24h Change', state.price!.change24h),
    ],
  ]));

  Widget _infoRow(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Row(children: [
    Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)), const Spacer(),
    Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
  ]));

  Widget _buildRecentTrades(DexState state) {
    if (state.recentTrades.isEmpty) return const Center(child: Text('No recent trades', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)));
    return Column(children: [
      Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.surfaceColor))),
        child: Row(children: [
          const Text('RECENT TRADES', style: TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.w600)), const Spacer(),
          const Text('XFG', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)), const SizedBox(width: 4),
          const Text('Rate', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)), const SizedBox(width: 4),
          const Text('Block', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
        ])),
      Expanded(child: ListView.builder(itemCount: state.recentTrades.length, itemBuilder: (context, i) => _tradeRow(state.recentTrades[i]))),
    ]);
  }

  Widget _tradeRow(SwapTradeSdk t) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.surfaceColor))),
    child: Row(children: [
      Expanded(flex: 2, child: Text('${(t.amount / 1e7).toStringAsFixed(2)} XFG', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11))),
      Expanded(flex: 2, child: Text(t.price > 0 ? (t.amount / t.price).toStringAsFixed(4) : '--', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11))),
      Expanded(flex: 2, child: Text('#${t.timestamp}', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10))),
    ]));

  void _submitOffer(DexState state) async {
    final amountStr = _amountController.text.trim(); final rateStr = _rateController.text.trim();
    if (amountStr.isEmpty || rateStr.isEmpty) return;
    final amountXfg = double.tryParse(amountStr); final rate = double.tryParse(rateStr);
    if (amountXfg == null || rate == null || amountXfg <= 0 || rate <= 0) return;
    context.read<DexCubit>().submitOffer(xfgAmount: (amountXfg * 1e7).toInt(), rateNum: (rate * 1e7).toInt(), makerPubKey: '', signature: '');
  }

  void _requestSwap(DexState state) async {
    if (state.offers.isEmpty) return;
    final amountStr = _amountController.text.trim(); if (amountStr.isEmpty) return;
    final amountXfg = double.tryParse(amountStr); if (amountXfg == null || amountXfg <= 0) return;
    context.read<DexCubit>().requestSwap(offerId: state.offers.first.offerId, amount: (amountXfg * 1e7).toInt(), takerPubKey: '', proofOfFunds: '');
  }

  // ── Cross-Chain Swap Section ───────────────────────────────────────

  Widget _buildSpvSwapSection(DexState state) {
    final active = state.spvSwaps.where((s) => !s.isTerminal).toList();
    final history = state.spvSwaps.where((s) => s.isTerminal).toList();
    final isEvmOrSol = const {'ETH', 'ARB', 'BASE', 'BSC', 'SOL', 'POLY'}.contains(_selectedSpvPair);
    final isUtxo = const {'BTC', 'LTC', 'KMD', 'BCH', 'DCR'}.contains(_selectedSpvPair);
    final isMonero = _selectedSpvPair == 'XMR';

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (!state.isSwapDaemonConnected && isUtxo && !isMonero)
        Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: AppTheme.errorColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.errorColor.withOpacity(0.3))),
          child: Row(children: const [
            Icon(Icons.error_outline, color: AppTheme.errorColor, size: 16), SizedBox(width: 8),
            Expanded(child: Text('xfg-swapd not running — start it from Settings > Cross-Chain Swaps', style: TextStyle(color: AppTheme.errorColor, fontSize: 12))),
          ])),

      // Chain selector
      Row(children: [
        const Text('Chain', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)), const SizedBox(width: 8),
        Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(border: Border.all(color: AppTheme.textSecondary.withOpacity(0.3)), borderRadius: BorderRadius.circular(8)),
          child: DropdownButtonHideUnderline(child: DropdownButton<String>(
            value: _selectedSpvPair, isExpanded: true, dropdownColor: AppTheme.cardColor,
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
            items: _spvPairNames.keys.map((k) => DropdownMenuItem(value: k, child: Text('$k — ${_spvPairNames[k]}'))).toList(),
            onChanged: (v) { if (v != null) { setState(() => _selectedSpvPair = v); context.read<DexCubit>().loadBalance(); } },
          )))),
      ]),

      if (isEvmOrSol) ...[const SizedBox(height: 10),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppTheme.surfaceColor)),
          child: Row(children: [
            const Icon(Icons.account_balance_wallet, color: AppTheme.primaryColor, size: 16), const SizedBox(width: 8),
            const Text('Balance:', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)), const SizedBox(width: 8),
            if (state.isBalanceLoading) const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primaryColor))
            else Text('${state.evmBalance.toStringAsFixed(4)} $_selectedSpvPair', style: const TextStyle(color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.refresh, size: 16, color: AppTheme.textMuted), onPressed: () => context.read<DexCubit>().loadBalance(), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 28, minHeight: 28)),
          ]))],

      const SizedBox(height: 12),

      TextField(controller: _amountController, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: 'XFG Amount', labelStyle: const TextStyle(color: AppTheme.textSecondary), hintText: '10.00', hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3))), focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor))),
        style: const TextStyle(color: AppTheme.textPrimary)),
      const SizedBox(height: 12),

      if (isUtxo) ...[
        TextField(controller: _peerController,
          decoration: InputDecoration(labelText: 'Peer Endpoint', labelStyle: const TextStyle(color: AppTheme.textSecondary), hintText: '192.168.1.100:18901', hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)), enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3))), focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor))),
          style: const TextStyle(color: AppTheme.textPrimary)),
      ],
      const SizedBox(height: 16),

      ElevatedButton(
        onPressed: (state.isSwapInitiating || (isUtxo && !state.isSwapDaemonConnected)) ? null : () => _initiateSpvSwap(state),
        style: ElevatedButton.styleFrom(backgroundColor: isEvmOrSol ? AppTheme.successColor : AppTheme.primaryColor, padding: const EdgeInsets.symmetric(vertical: 14)),
        child: state.isSwapInitiating ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(isEvmOrSol ? 'LOCK HTLC' : isMonero ? 'INITIATE (XMR)' : 'INITIATE SWAP', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),

      if (state.lastResult != null) ...[const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.successColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(state.lastResult!, style: const TextStyle(color: AppTheme.successColor, fontSize: 12)))],
      if (state.error != null) ...[const SizedBox(height: 12),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.errorColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Text(state.error!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 12)))],
      if (isEvmOrSol && state.htlcTxHash != null) ...[const SizedBox(height: 10),
        Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('HTLC Transaction', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)), const SizedBox(height: 4),
          Text(state.htlcTxHash!, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontFamily: 'monospace')),
        ]))],

      if (active.isNotEmpty) ...[const SizedBox(height: 20),
        const Text('Active Swaps', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
        ...active.map((swap) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(8)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(0.15), borderRadius: BorderRadius.circular(4)), child: Text(swap.pairName, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.bold))),
            const SizedBox(width: 8), Text(swap.state, style: TextStyle(color: AppTheme.textSecondary, fontSize: 11)), const Spacer(),
            TextButton(onPressed: () => context.read<DexCubit>().refundSpvSwap(swap.swapId), child: const Text('Refund', style: TextStyle(color: AppTheme.errorColor, fontSize: 11))),
          ]),
          const SizedBox(height: 6),
          Text('${swap.xfgAmountDecimal.toStringAsFixed(2)} XFG \u2192 ${swap.ctrAmountDecimal.toStringAsFixed(4)} ${swap.pairName}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13)),
          Text('ID: ${swap.swapId.substring(0, 12)}\u2026', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
        ]))),
      ],

      if (history.isNotEmpty) ...[const SizedBox(height: 20),
        const Text('History', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)), const SizedBox(height: 8),
        ...history.map((swap) {
          final isRefunded = swap.state.contains('REFUND') || swap.state.contains('FAILED');
          return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.cardColor, borderRadius: BorderRadius.circular(8)), child: Row(children: [
            Icon(isRefunded ? Icons.replay : Icons.check_circle, color: isRefunded ? AppTheme.warningColor : AppTheme.successColor, size: 16), const SizedBox(width: 8),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${swap.xfgAmountDecimal.toStringAsFixed(2)} XFG \u2192 ${swap.pairName}', style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12)),
              Text(swap.state, style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            ])),
          ]));
        }),
      ],
    ]));
  }

  void _initiateSpvSwap(DexState state) {
    final amountStr = _amountController.text.trim(); if (amountStr.isEmpty) return;
    final amountXfg = double.tryParse(amountStr); if (amountXfg == null || amountXfg <= 0) return;
    final xfgAmount = (amountXfg * 1e7).toInt();
    final isEvmOrSol = const {'ETH', 'ARB', 'BASE', 'BSC', 'SOL', 'POLY'}.contains(_selectedSpvPair);
    final isUtxo = const {'BTC', 'LTC', 'KMD', 'BCH', 'DCR'}.contains(_selectedSpvPair);
    if (isEvmOrSol) { context.read<DexCubit>().loadBalance(); }
    else if (isUtxo) {
      final peer = _peerController.text.trim(); if (peer.isEmpty) return;
      context.read<DexCubit>().initiateSpvSwap(pair: _selectedSpvPair, xfgAmount: xfgAmount, ctrAmount: xfgAmount, peer: peer);
    }
  }
}
