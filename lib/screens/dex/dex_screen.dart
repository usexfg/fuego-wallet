import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/dex/dex_cubit.dart';
import '../../utils/theme.dart';

class DexScreen extends StatefulWidget {
  const DexScreen({super.key});

  @override
  State<DexScreen> createState() => _DexScreenState();
}

class _DexScreenState extends State<DexScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DexCubit>().loadAvailableCoins();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DexCubit, DexState>(
      builder: (context, state) {
        return Column(
          children: [
            _buildPairBar(state),
            _buildPriceBar(state),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text(state.error!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 11)),
              ),
            Expanded(child: _buildOrderbook(state)),
          ],
        );
      },
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
