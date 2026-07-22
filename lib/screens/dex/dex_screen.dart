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
  List<Candlestick>? _candles;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPriceData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DexCubit>().init();
    });
  }

  Future<void> _loadPriceData() async {
    final candles = await PriceHistoryService().loadAll();
    if (mounted) setState(() => _candles = candles);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _amountController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final tabH = screenH * 0.38;
    return BlocBuilder<DexCubit, DexState>(
      builder: (context, state) {
        return Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (_candles != null && _candles!.isNotEmpty)
                      SizedBox(
                        height: screenH * 0.35,
                        child: FuegoChart(
                          candles: _candles!,
                          pair: 'XFG/${state.selectedPair.ticker}',
                        ),
                      ),
                    _buildPairBar(state),
                    _buildPriceBar(state),
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Text(state.error!,
                            style: const TextStyle(color: AppTheme.errorColor, fontSize: 11)),
                      ),
                    if (state.lastResult != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Text(state.lastResult!,
                            style: const TextStyle(color: AppTheme.successColor, fontSize: 11)),
                      ),
                  ],
                ),
              ),
            ),
            _buildTabBar(),
            SizedBox(
              height: tabH,
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOrderbook(state),
                  _buildTradeForm(state),
                  _buildRecentTrades(state),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.surfaceColor,
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primaryColor,
        unselectedLabelColor: AppTheme.textMuted,
        indicatorColor: AppTheme.primaryColor,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Orderbook'),
          Tab(text: 'Trade'),
          Tab(text: 'Trades'),
        ],
      ),
    );
  }

  Widget _buildPairBar(DexState state) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: AppTheme.surfaceColor,
      child: Row(
        children: [
          const Icon(Icons.currency_exchange, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 8),
          const Text('XFG/',
              style: TextStyle(
                  color: AppTheme.primaryColor, fontSize: 14, fontWeight: FontWeight.w600)),
          SizedBox(
            width: 90,
            child: DropdownButtonFormField<SwapPairSdk>(
              value: state.selectedPair,
              isExpanded: true,
              dropdownColor: AppTheme.cardColor,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(),
              ),
              items: SwapPairSdk.values
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.ticker)))
                  .toList(),
              onChanged: (p) {
                if (p != null) context.read<DexCubit>().selectPair(p);
              },
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              state.selectedChain.symbol,
              style: const TextStyle(
                  color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.w600),
            ),
          ),
          const Spacer(),
          if (!state.isConnected)
            const Icon(Icons.cloud_off, color: AppTheme.errorColor, size: 16)
          else
            const Icon(Icons.cloud_done, color: AppTheme.successColor, size: 16),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18, color: AppTheme.primaryColor),
            onPressed: () => context.read<DexCubit>().refresh(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBar(DexState state) {
    final p = state.price;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppTheme.surfaceColor.withOpacity(0.4),
      child: Row(
        children: [
          Text('XFG/${state.selectedPair.ticker}',
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          const Spacer(),
          if (p != null) ...[
            Text('TWAP: ${p.twap}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            const SizedBox(width: 12),
            Text('\$${p.xfgUsdMid}',
                style: const TextStyle(
                    color: AppTheme.primaryColor, fontSize: 13, fontWeight: FontWeight.bold)),
          ] else
            const Text('--',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildOrderbook(DexState state) {
    if (!state.isConnected) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off, color: AppTheme.textMuted, size: 48),
            const SizedBox(height: 16),
            Text(
              'fuego-native DEX',
              style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              state.error ?? 'Connecting to fuegod...',
              style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'No KDF required.\nSwap offers sourced from fuego P2P network.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
    if (state.isLoading && state.offers.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }
    if (state.offers.isEmpty) {
      return const Center(
        child: Text('No active offers',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.surfaceColor)),
          ),
          child: Row(
            children: [
              Text('OFFERS (${state.offers.length})',
                  style: const TextStyle(
                      color: AppTheme.primaryColor, fontSize: 10, fontWeight: FontWeight.w600)),
              const Spacer(),
              const Text('XFG', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
              const SizedBox(width: 4),
              const Text('Rate', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
              const SizedBox(width: 4),
              const Text('Time', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: state.offers.length,
            itemBuilder: (context, i) => _offerRow(state.offers[i]),
          ),
        ),
      ],
    );
  }

  Widget _offerRow(SwapOffer o) {
    final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(o.timestamp * 1000));
    final ageStr = age.inHours > 0
        ? '${age.inHours}h'
        : age.inMinutes > 0
            ? '${age.inMinutes}m'
            : '${age.inSeconds}s';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.surfaceColor)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(o.pairLabel,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 2,
            child: Text('${(o.xfgAmount / 1e7).toStringAsFixed(2)} XFG',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
          ),
          Expanded(
            flex: 2,
            child: Text(o.rateNum > 0 ? (o.rate).toStringAsFixed(4) : '--',
                style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11)),
          ),
          Text(ageStr, style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _fillOffer(o),
            child: const Text('FILL',
                style: TextStyle(
                    color: AppTheme.successColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _fillOffer(SwapOffer offer) {
    _amountController.clear();
    _rateController.text = offer.rateNum > 0 ? offer.rate.toStringAsFixed(4) : '';
    _tabController.animateTo(1);
  }

  Widget _buildTradeForm(DexState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Trade XFG/${state.selectedPair.ticker}',
            style: const TextStyle(
                color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'XFG Amount',
              labelStyle: const TextStyle(color: AppTheme.textSecondary),
              hintText: '100.00',
              hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.primaryColor),
              ),
            ),
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _rateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Rate (${state.selectedPair.ticker} per XFG)',
              labelStyle: const TextStyle(color: AppTheme.textSecondary),
              hintText: state.price?.compositeRate ?? '0.00',
              hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.textSecondary.withOpacity(0.3)),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: AppTheme.primaryColor),
              ),
            ),
            style: const TextStyle(color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : () => _submitOffer(state),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: state.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('POST OFFER',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: state.isLoading ? null : () => _requestSwap(state),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: state.isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('REQUEST SWAP',
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.price != null) ...[
            Text(
              'Price Info',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            _infoRow('TWAP', state.price!.twap),
            _infoRow('Composite', state.price!.compositeRate),
            _infoRow('XFG USD', '\$${state.price!.xfgUsdMid}'),
            _infoRow('HEAT/XFG', state.price!.hearthRatio),
            _infoRow('HEAT USD', '\$${state.price!.heatUsd}'),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          const Spacer(),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildRecentTrades(DexState state) {
    if (state.recentTrades.isEmpty) {
      return const Center(
        child: Text('No recent trades',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.surfaceColor)),
          ),
          child: Row(
            children: [
              const Text('RECENT TRADES',
                  style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              const Text('XFG', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
              const SizedBox(width: 4),
              const Text('Rate', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
              const SizedBox(width: 4),
              const Text('Block', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: state.recentTrades.length,
            itemBuilder: (context, i) => _tradeRow(state.recentTrades[i]),
          ),
        ),
      ],
    );
  }

  Widget _tradeRow(TradeRecord t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.surfaceColor)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text('${(t.xfgAmount / 1e7).toStringAsFixed(2)} XFG',
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
          ),
          Expanded(
            flex: 2,
            child: Text(t.rate,
                style: const TextStyle(color: AppTheme.primaryColor, fontSize: 11)),
          ),
          Expanded(
            flex: 2,
            child: Text('#${t.blockHeight}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          ),
        ],
      ),
    );
  }

  void _submitOffer(DexState state) async {
    final amountStr = _amountController.text.trim();
    final rateStr = _rateController.text.trim();
    if (amountStr.isEmpty || rateStr.isEmpty) return;

    final amountXfg = double.tryParse(amountStr);
    final rate = double.tryParse(rateStr);
    if (amountXfg == null || rate == null || amountXfg <= 0 || rate <= 0) return;

    final xfgAmount = (amountXfg * 1e7).toInt();
    final rateNum = (rate * 1e7).toInt();

    context.read<DexCubit>().submitOffer(
          xfgAmount: xfgAmount,
          rateNum: rateNum,
          makerPubKey: '',
          signature: '',
        );
  }

  void _requestSwap(DexState state) async {
    if (state.offers.isEmpty) {
      return;
    }
    final offer = state.offers.first;
    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) return;

    final amountXfg = double.tryParse(amountStr);
    if (amountXfg == null || amountXfg <= 0) return;

    final amount = (amountXfg * 1e7).toInt();

    context.read<DexCubit>().requestSwap(
          offerId: offer.offerId,
          amount: amount,
          takerPubKey: '',
          proofOfFunds: '',
        );
  }
}
