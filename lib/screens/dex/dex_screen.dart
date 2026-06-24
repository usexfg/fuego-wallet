import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fuego_defi_sdk/fuego_defi_sdk.dart';
import '../../bloc/dex/dex_cubit.dart';
import '../../utils/theme.dart';

class DexScreen extends StatefulWidget {
  const DexScreen({super.key});

  @override
  State<DexScreen> createState() => _DexScreenState();
}

class _DexScreenState extends State<DexScreen> {
  final _baseController = TextEditingController(text: 'XFG');
  final _relController = TextEditingController(text: 'KMD');
  final _priceController = TextEditingController();
  final _volumeController = TextEditingController();
  bool _isBuy = true;

  @override
  void dispose() {
    _baseController.dispose();
    _relController.dispose();
    _priceController.dispose();
    _volumeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DexCubit, DexState>(
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          appBar: AppBar(
            title: const Text('DEX'),
            backgroundColor: AppTheme.surfaceColor,
          ),
          body: Column(
            children: [
              _buildPairSelector(context),
              Expanded(child: _buildOrderbook(state)),
              _buildTradeForm(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPairSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      color: AppTheme.surfaceColor,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _baseController,
              decoration: InputDecoration(
                labelText: 'Base',
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('/', style: TextStyle(color: AppTheme.textMuted, fontSize: 20)),
          ),
          Expanded(
            child: TextField(
              controller: _relController,
              decoration: InputDecoration(
                labelText: 'Rel',
                filled: true,
                fillColor: AppTheme.backgroundColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              style: const TextStyle(color: AppTheme.textPrimary),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              context.read<DexCubit>().loadOrderbook(
                    _baseController.text.toUpperCase(),
                    _relController.text.toUpperCase(),
                  );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Icon(Icons.search, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderbook(DexState state) {
    if (state.baseCoin == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 48, color: AppTheme.textMuted),
            SizedBox(height: 8),
            Text('Select a pair to view orderbook', style: TextStyle(color: AppTheme.textMuted)),
          ],
        ),
      );
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 32, color: AppTheme.textMuted),
            const SizedBox(height: 8),
            Text(state.error!, style: const TextStyle(color: AppTheme.errorColor, fontSize: 12)),
          ],
        ),
      );
    }

    final pair = '${state.baseCoin}/${state.relCoin}';

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: AppTheme.surfaceColor,
          child: Text(pair, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              ...state.asks.reversed.map((o) => _orderRow(o, false)),
              const Divider(height: 1, color: AppTheme.textMuted),
              ...state.bids.map((o) => _orderRow(o, true)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _orderRow(Map<String, dynamic> order, bool isBid) {
    final price = order['price']?.toString() ?? '-';
    final volume = order['maxvolume']?.toString() ?? order['volume']?.toString() ?? '-';
    final color = isBid ? AppTheme.successColor : AppTheme.errorColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(price, style: TextStyle(color: color, fontSize: 13, fontFamily: 'monospace')),
          ),
          Text(volume, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildTradeForm(BuildContext context) {
    final state = context.watch<DexCubit>().state;
    final hasPair = state.baseCoin != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(top: BorderSide(color: AppTheme.textMuted.withOpacity(0.2))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isBuy = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isBuy ? AppTheme.successColor : AppTheme.surfaceColor,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                    ),
                    child: const Text('BUY', textAlign: TextAlign.center, style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    )),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isBuy = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_isBuy ? AppTheme.errorColor : AppTheme.surfaceColor,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                    ),
                    child: const Text('SELL', textAlign: TextAlign.center, style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    )),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Price',
                    filled: true,
                    fillColor: AppTheme.backgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _volumeController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Volume',
                    filled: true,
                    fillColor: AppTheme.backgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: hasPair
                  ? () {
                      final price = _priceController.text;
                      final volume = _volumeController.text;
                      if (price.isEmpty || volume.isEmpty) return;
                      final cubit = context.read<DexCubit>();
                      if (_isBuy) {
                        cubit.submitBuyOrder(state.baseCoin!, state.relCoin!, price, volume);
                      } else {
                        cubit.submitSellOrder(state.baseCoin!, state.relCoin!, price, volume);
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isBuy ? AppTheme.successColor : AppTheme.errorColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text(
                _isBuy ? 'BUY ${state.baseCoin ?? ''}' : 'SELL ${state.baseCoin ?? ''}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
