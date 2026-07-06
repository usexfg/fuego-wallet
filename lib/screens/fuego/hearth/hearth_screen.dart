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
  final _xfgAmount = TextEditingController();
  final _heatAmount = TextEditingController();
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
    _xfgAmount.dispose();
    _heatAmount.dispose();
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
            title: const Text('Hearth AMM'),
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
                          height: screenH * 0.35,
                          child: FuegoChart(
                            candles: _candles!,
                            pair: 'XFG/HEAT',
                          ),
                        ),
                      if (state.pool != null) _buildPoolStats(state.pool!),
                      const SizedBox(height: 20),
                      _buildSwapForm(context),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('Pool Reserves', style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textMuted)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _statItem('XFG', pool.xfgReserve)),
                Container(width: 1, height: 40, color: AppTheme.textMuted.withOpacity(0.2)),
                Expanded(child: _statItem('HEAT', pool.heatReserve)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _statItem('Spot Price', pool.spotPrice)),
                Expanded(child: _statItem('24h Volume', pool.volume24h)),
                Expanded(child: _statItem('LP Fees', pool.lpFees24h)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
      ],
    );
  }

  Widget _buildSwapForm(BuildContext context) {
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
                  child: _tokenButton('XFG', !_sellXfg, () => setState(() => _sellXfg = true)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Icon(Icons.swap_horiz, color: AppTheme.textMuted),
                ),
                Expanded(
                  child: _tokenButton('HEAT', _sellXfg, () => setState(() => _sellXfg = false)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _sellXfg ? _xfgAmount : _heatAmount,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: _sellXfg ? 'XFG Amount' : 'HEAT Amount',
                filled: true,
                fillColor: AppTheme.surfaceColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  final amount = _sellXfg ? _xfgAmount.text : _heatAmount.text;
                  if (amount.isNotEmpty) {
                    context.read<HearthCubit>().getQuote(
                      sellXfg: _sellXfg,
                      amount: amount,
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Get Quote', style: TextStyle(fontSize: 16)),
              ),
            ),
            if (context.watch<HearthCubit>().state.quote != null) ...[
              const SizedBox(height: 12),
              _buildQuoteDisplay(context.watch<HearthCubit>().state.quote!),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    final cubit = context.read<HearthCubit>();
                    final quote = cubit.state.quote!;
                    cubit.executeSwap(
                      sellXfg: _sellXfg,
                      inputAmount: quote.inputAmount,
                      minOutput: quote.outputAmount,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.successColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('SWAP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuoteDisplay(AmmQuote quote) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(10),
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
              Text('Price impact: ${quote.priceImpact}%',
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tokenButton(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFF5722) : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, textAlign: TextAlign.center, style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: isActive ? Colors.black : AppTheme.textMuted,
        )),
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
