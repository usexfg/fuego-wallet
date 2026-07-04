import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/dex/dex_cubit.dart';
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
  final _priceController = TextEditingController();
  final _volumeController = TextEditingController();
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
    _priceController.dispose();
    _volumeController.dispose();
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
                          pair: state.baseCoin != null && state.relCoin != null
                              ? '${state.baseCoin}/${state.relCoin}'
                              : 'XFG/USD',
                        ),
                      ),
                    _buildPairBar(state),
                    _buildPriceBar(state),
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Text(state.error!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 11)),
                      ),
                    if (state.lastOrderResult != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        child: Text(state.lastOrderResult!, style: const TextStyle(color: AppTheme.successColor, fontSize: 11)),
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
                  _buildOpenOrders(state),
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
          Tab(text: 'Orders'),
        ],
      ),
    );
  }

  Widget _buildPairBar(DexState state) {
    final coins = state.availableCoins;
    return Container(
      padding: const EdgeInsets.all(8),
      color: AppTheme.surfaceColor,
      child: Row(
        children: [
          const Icon(Icons.currency_exchange, color: AppTheme.primaryColor, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: _coinDropdown(
              value: state.baseCoin,
              hint: 'Base coin',
              coins: coins,
              onChanged: (c) {
                if (state.relCoin != null && state.relCoin != c) {
                  context.read<DexCubit>().selectPair(c, state.relCoin!);
                } else {
                  context.read<DexCubit>().selectPair(c, c);
                }
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('/', style: TextStyle(color: AppTheme.textMuted, fontSize: 18, fontWeight: FontWeight.w300)),
          ),
          Expanded(
            child: _coinDropdown(
              value: state.relCoin,
              hint: 'Quote coin',
              coins: coins,
              onChanged: (c) {
                if (state.baseCoin != null && state.baseCoin != c) {
                  context.read<DexCubit>().selectPair(state.baseCoin!, c);
                } else {
                  context.read<DexCubit>().selectPair(c, c);
                }
              },
            ),
          ),
          if (state.baseCoin != null && state.relCoin != null) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18, color: AppTheme.primaryColor),
              onPressed: () => context.read<DexCubit>().selectPair(state.baseCoin!, state.relCoin!),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ],
      ),
    );
  }

  Widget _coinDropdown({
    required String? value,
    required String hint,
    required List<String> coins,
    required ValueChanged<String> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value != null && coins.contains(value) ? value : null,
      hint: Text(hint, style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
      isExpanded: true,
      dropdownColor: AppTheme.cardColor,
      style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
      decoration: const InputDecoration(
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        border: OutlineInputBorder(),
      ),
      items: coins.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
      onChanged: (c) { if (c != null) onChanged(c); },
    );
  }

  Widget _buildPriceBar(DexState state) {
    if (state.baseCoin == null || state.relCoin == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: AppTheme.surfaceColor.withOpacity(0.4),
      child: Row(
        children: [
          Text(state.baseCoin!,
              style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          Text('/${state.relCoin!}',
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
          const Spacer(),
          if (state.spread != null)
            Text('spread ${state.spread!.toStringAsFixed(7)}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          const SizedBox(width: 12),
          if (state.bestBid != null)
            Text(state.bestBid!.toStringAsFixed(7),
                style: const TextStyle(color: AppTheme.successColor, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          if (state.bestAsk != null)
            Text(state.bestAsk!.toStringAsFixed(7),
                style: const TextStyle(color: AppTheme.errorColor, fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildOrderbook(DexState state) {
    if (state.baseCoin == null || state.relCoin == null) {
      if (state.error != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.swap_horiz, color: AppTheme.textMuted, size: 48),
                const SizedBox(height: 16),
                Text(
                  'DEX requires KDF',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  state.error!,
                  style: const TextStyle(color: AppTheme.errorColor, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Configure a KDF server in Settings > DEX Server',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Or run KDF locally:\n./kdf --rpcip 0.0.0.0 --rpcport 7783 --rpc_password PASS --allow_weak_password',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 10, fontFamily: 'monospace'),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }
      return const Center(
        child: Text('Select a trading pair above', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)));
    }
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor));
    }

    return Row(
      children: [
        Expanded(child: _orderColumn('BIDS', state.bids, AppTheme.successColor, isAsk: false)),
        Container(width: 1, color: AppTheme.surfaceColor),
        Expanded(child: _orderColumn('ASKS', state.asks, AppTheme.errorColor, isAsk: true)),
      ],
    );
  }

  Widget _buildTradeForm(DexState state) {
    if (state.baseCoin == null || state.relCoin == null) {
      return const Center(
        child: Text('Select a trading pair first', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Trade ${state.baseCoin}/${state.relCoin}',
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Price (${state.relCoin})',
              labelStyle: const TextStyle(color: AppTheme.textSecondary),
              hintText: state.bestAsk?.toStringAsFixed(7) ?? '0.0000000',
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
            controller: _volumeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Amount (${state.baseCoin})',
              labelStyle: const TextStyle(color: AppTheme.textSecondary),
              hintText: '0.0000000',
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
                  onPressed: state.isSubmitting ? null : () {
                    final price = _priceController.text.trim();
                    final volume = _volumeController.text.trim();
                    if (price.isEmpty || volume.isEmpty) return;
                    context.read<DexCubit>().takerBuy(volume: volume, price: price);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: state.isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('BUY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: state.isSubmitting ? null : () {
                    final price = _priceController.text.trim();
                    final volume = _volumeController.text.trim();
                    if (price.isEmpty || volume.isEmpty) return;
                    context.read<DexCubit>().takerSell(volume: volume, price: price);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: state.isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('SELL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: state.isSubmitting ? null : () {
              final price = _priceController.text.trim();
              final volume = _volumeController.text.trim();
              if (price.isEmpty || volume.isEmpty) return;
              context.read<DexCubit>().placeMakerOrder(price: price, volume: volume);
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppTheme.primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: state.isSubmitting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Place Limit Order', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildOpenOrders(DexState state) {
    if (state.openOrders.isEmpty) {
      return const Center(
        child: Text('No open orders', style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Text('${state.openOrders.length} orders', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const Spacer(),
              TextButton(
                onPressed: () => context.read<DexCubit>().cancelAllOrders(),
                child: const Text('Cancel All', style: TextStyle(color: AppTheme.errorColor, fontSize: 12)),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: state.openOrders.length,
            itemBuilder: (context, i) {
              final order = state.openOrders[i];
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.surfaceColor)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${order.base}/${order.rel}',
                            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Price: ${order.price}  Vol: ${order.volume}',
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: AppTheme.errorColor),
                      onPressed: () => context.read<DexCubit>().cancelOrder(order.uuid),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _orderColumn(String title, List<OrderRow> orders, Color color, {required bool isAsk}) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.surfaceColor)),
          ),
          child: Row(
            children: [
              Text(title, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
              const Spacer(),
              const Text('Price', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
              const SizedBox(width: 4),
              const Text('Vol', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
              const SizedBox(width: 4),
              const Text('Σ', style: TextStyle(color: AppTheme.textMuted, fontSize: 9)),
            ],
          ),
        ),
        Expanded(
          child: orders.isEmpty
              ? Center(child: Text('-', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)))
              : ListView.builder(
                  itemCount: orders.length > 30 ? 30 : orders.length,
                  itemExtent: 22,
                  itemBuilder: (_, i) => _orderRow(orders[i], color),
                ),
        ),
      ],
    );
  }

  Widget _orderRow(OrderRow o, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        border: o.isMine ? Border.all(color: AppTheme.primaryColor.withOpacity(0.5), width: 0.5) : null,
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: o.depthPct.clamp(0.0, 1.0),
                child: Container(color: color.withOpacity(0.07)),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(o.price, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w500)),
              ),
              Expanded(
                flex: 2,
                child: Text(o.volume, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
              ),
              Expanded(
                flex: 2,
                child: Text('${(o.depthPct * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 9)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
