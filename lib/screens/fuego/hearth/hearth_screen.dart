import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../bloc/hearth/hearth_cubit.dart';
import '../../../models/candlestick.dart';
import '../../../models/heat_amm.dart';
import '../../../services/price_history_service.dart';
import '../../../utils/theme.dart';
import '../../../widgets/fuego_chart.dart';
import 'liquidity_dialogs.dart';

class HearthScreen extends StatefulWidget {
  const HearthScreen({super.key});

  @override
  State<HearthScreen> createState() => _HearthScreenState();
}

class _HearthScreenState extends State<HearthScreen> {
  final _amountController = TextEditingController();
  final _priceController = TextEditingController();
  bool _sellXfg = true;
  List<Candlestick>? _candles;

  @override
  void initState() {
    super.initState();
    context.read<HearthCubit>().loadPool();
    _loadPriceData();
  }

  Future<void> _loadPriceData() async {
    final candles = await PriceHistoryService().loadAll();
    if (mounted) setState(() => _candles = candles);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _showAddLiquidity(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<HearthCubit>(),
        child: const AddLiquidityDialog(),
      ),
    );
  }

  void _showRemoveLiquidity(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<HearthCubit>(),
        child: const RemoveLiquidityDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return BlocBuilder<HearthCubit, HearthState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: const Text('Hearth Exchange'),
            backgroundColor: AppTheme.surfaceColor,
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (_candles != null && _candles!.isNotEmpty)
                        SizedBox(
                          height: screenH * 0.30,
                          child: FuegoChart(
                            candles: _candles!,
                            pair: 'XFG/HEAT',
                          ),
                        ),
                      if (state.pool != null) _buildPoolStats(state.pool!),
                      const SizedBox(height: 12),
                      _buildOrderTypeToggle(state),
                      const SizedBox(height: 12),
                      if (state.orderBook != null)
                        _buildOrderBook(state.orderBook!, state),
                      const SizedBox(height: 12),
                      _buildTradeForm(context, state),
                      const SizedBox(height: 20),
                      _buildLiquidityActions(context),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildPoolStats(PoolInfo pool) {
    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(child: _statItem('XFG', pool.xfgReserve)),
            Container(width: 1, height: 36, color: AppTheme.textMuted.withOpacity(0.2)),
            Expanded(child: _statItem('HEAT', pool.heatReserve)),
            Container(width: 1, height: 36, color: AppTheme.textMuted.withOpacity(0.2)),
            Expanded(child: _statItem('Vol 24h', pool.volume24h)),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _buildOrderTypeToggle(HearthState state) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          Expanded(
            child: _tabBtn('Market', state.orderType == OrderType.market, () {
              context.read<HearthCubit>().setOrderType(OrderType.market);
              _priceController.clear();
            }),
          ),
          Expanded(
            child: _tabBtn('Limit', state.orderType == OrderType.limit, () {
              context.read<HearthCubit>().setOrderType(OrderType.limit);
            }),
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: active ? Colors.white : AppTheme.textMuted,
        )),
      ),
    );
  }

  Widget _buildOrderBook(OrderBook book, HearthState state) {
    final spot = book.lastPrice;
    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Order Book', style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
                const Spacer(),
                Text('XFG/HEAT ${spot.toStringAsFixed(4)}', style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('Price', style: TextStyle(fontSize: 10, color: AppTheme.textMuted))),
                const Expanded(child: Text('Amount', style: TextStyle(fontSize: 10, color: AppTheme.textMuted), textAlign: TextAlign.right)),
                const Expanded(child: Text('Total', style: TextStyle(fontSize: 10, color: AppTheme.textMuted), textAlign: TextAlign.right)),
              ],
            ),
            const SizedBox(height: 4),
            ...book.asks.map((l) => _depthRow(l, false, book)),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 4),
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.swap_vert, size: 14, color: AppTheme.primaryColor),
                  const SizedBox(width: 6),
                  Text('Spread ${spot.toStringAsFixed(4)}', style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                ],
              ),
            ),
            ...book.bids.map((l) => _depthRow(l, true, book)),
          ],
        ),
      ),
    );
  }

  Widget _depthRow(OrderBookLevel level, bool isBid, OrderBook book) {
    final maxTotal = book.asks.isNotEmpty
        ? book.asks.map((e) => e.total).reduce((a, b) => a > b ? a : b)
        : 1.0;
    final pct = (level.total / maxTotal).clamp(0.0, 1.0);
    final color = isBid ? AppTheme.successColor : AppTheme.errorColor;
    return Stack(
      children: [
        Positioned.fill(
          child: Align(
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: pct,
              child: Container(color: color.withOpacity(0.08)),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              Expanded(child: Text(
                level.price.toStringAsFixed(4),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: color),
              )),
              Expanded(child: Text(
                level.amount.toStringAsFixed(2),
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                textAlign: TextAlign.right,
              )),
              Expanded(child: Text(
                level.total.toStringAsFixed(2),
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                textAlign: TextAlign.right,
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTradeForm(BuildContext context, HearthState state) {
    final isLimit = state.orderType == OrderType.limit;
    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _assetBtn('XFG', _sellXfg, () => setState(() {
                    _sellXfg = true;
                    _amountController.clear();
                  })),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, color: AppTheme.textMuted, size: 18),
                ),
                Expanded(
                  child: _assetBtn('HEAT', !_sellXfg, () => setState(() {
                    _sellXfg = false;
                    _amountController.clear();
                  })),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _sellXfg ? 'Sell XFG Amount' : 'Sell HEAT Amount',
                filled: true,
                fillColor: AppTheme.surfaceColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            if (isLimit) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Price (XFG/HEAT)',
                  hintText: state.pool?.spotPrice ?? '1.5800',
                  filled: true,
                  fillColor: AppTheme.surfaceColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: () {
                  final amount = _amountController.text.trim();
                  if (amount.isEmpty) return;
                  if (isLimit) {
                    final price = _priceController.text.trim();
                    if (price.isEmpty) return;
                    context.read<HearthCubit>().placeLimitOrder(
                      sellXfg: _sellXfg, amount: amount, price: price,
                    );
                  } else {
                    context.read<HearthCubit>().getQuote(
                      sellXfg: _sellXfg, amount: amount,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _sellXfg ? AppTheme.errorColor : AppTheme.successColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  isLimit
                      ? (_sellXfg ? 'Place Sell Order' : 'Place Buy Order')
                      : (_sellXfg ? 'Swap XFG → HEAT' : 'Swap HEAT → XFG'),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (!isLimit && state.quote != null) ...[
              const SizedBox(height: 12),
              _buildQuoteDisplay(state.quote!),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    final cubit = context.read<HearthCubit>();
                    final q = cubit.state.quote!;
                    cubit.executeSwap(
                      sellXfg: _sellXfg,
                      inputAmount: q.inputAmount,
                      minOutput: q.outputAmount,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Confirm Swap', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _assetBtn(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isSelected ? Colors.white : AppTheme.textMuted.withOpacity(0.5),
        )),
      ),
    );
  }

  Widget _buildQuoteDisplay(AmmQuote quote) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('You receive', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              Text(quote.outputAmount, style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('Fee', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              Text(quote.fee, style: const TextStyle(color: AppTheme.textSecondary)),
              Text('Impact: ${quote.priceImpact}%',
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiquidityActions(BuildContext context) {
    return Card(
      color: AppTheme.cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Liquidity', style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showAddLiquidity(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRemoveLiquidity(context),
                    icon: const Icon(Icons.remove, size: 18),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textMuted,
                      side: BorderSide(color: AppTheme.textMuted.withOpacity(0.3)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
