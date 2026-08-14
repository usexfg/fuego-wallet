import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/dex/dex_cubit.dart';
import '../../models/chain_info.dart';
import '../../utils/theme.dart';

/// Direct peer-to-peer atomic swaps with a CHOSEN counterparty.
///
/// This is intentionally NOT an orderbook or a swap-widget: there is no
/// automatic liquidity here. Both parties negotiate out-of-band (chat,
/// forum, trade desk) and exchange the swap endpoint + amounts first.
class PeerSwapScreen extends StatefulWidget {
  const PeerSwapScreen({super.key});

  @override
  State<PeerSwapScreen> createState() => _PeerSwapScreenState();
}

class _PeerSwapScreenState extends State<PeerSwapScreen> {
  final _amountController = TextEditingController();
  final _peerController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _peerController.dispose();
    super.dispose();
  }

  void _initiateSwap(DexState state, String ticker) {
    final amountStr = _amountController.text.trim();
    if (amountStr.isEmpty) return;
    final amountXfg = double.tryParse(amountStr);
    if (amountXfg == null || amountXfg <= 0) return;
    final peer = _peerController.text.trim();
    if (peer.isEmpty) return;
    context.read<DexCubit>().initiateCrossChainSwap(
      pair: ticker,
      xfgAmount: (amountXfg * 1e7).toInt(),
      ctrAmount: (amountXfg * 1e7).toInt(),
      peer: peer,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DexCubit, DexState>(
      builder: (context, state) {
        final ticker = state.selectedPair.ticker;
        final active = state.spvSwaps.where((s) => !s.isTerminal).toList();
        final history = state.spvSwaps.where((s) => s.isTerminal).toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _whatIsThis(),
              const SizedBox(height: 16),
              _chainSelector(state),
              const SizedBox(height: 16),
              _form(state, ticker, active),
              if (state.lastResult != null) ...[
                const SizedBox(height: 12),
                _statusCard(state.lastResult!, false),
              ],
              if (state.error != null) ...[
                const SizedBox(height: 12),
                _statusCard(state.error!, true),
              ],
              if (active.isNotEmpty) ...[
                const SizedBox(height: 20),
                _activeSection(active),
              ],
              if (history.isNotEmpty) ...[
                const SizedBox(height: 20),
                _historySection(history),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _whatIsThis() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.primaryColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.handshake_outlined,
              color: AppTheme.primaryColor,
              size: 18,
            ),
            SizedBox(width: 8),
            Text(
              'Direct peer swap',
              style: TextStyle(
                color: AppTheme.primaryColor,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          'This is for atomic swaps with a specific counterparty you already know. '
          'You must agree the amounts out-of-band and exchange endpoints first.\n\n'
          'To fill an open offer from the orderbook, use the Accept tab.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            height: 1.4,
          ),
        ),
      ],
    ),
  );

  Widget _chainSelector(DexState state) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: ChainInfo.swapableChains.map((t) {
      final selected = t == state.selectedPair.ticker;
      final color = ChainInfo.colors[t] ?? AppTheme.primaryColor;
      return GestureDetector(
        onTap: () => context.read<DexCubit>().selectPairById(t),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? color.withValues(alpha: 0.2) : AppTheme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? color : AppTheme.surfaceColor),
          ),
          child: Text(
            t,
            style: TextStyle(
              color: selected ? color : AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }).toList(),
  );

  Widget _form(DexState state, String ticker, List active) {
    final connected = state.isSwapDaemonConnected;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!connected)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppTheme.errorColor.withValues(alpha: 0.3),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline, color: AppTheme.errorColor, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'xfg-swapd not running — start it from Settings',
                    style: TextStyle(color: AppTheme.errorColor, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'XFG Amount',
            labelStyle: const TextStyle(color: AppTheme.textSecondary),
            hintText: '100.00',
            hintStyle: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryColor),
            ),
          ),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _peerController,
          decoration: InputDecoration(
            labelText: 'Peer Endpoint (from your counterparty)',
            labelStyle: const TextStyle(color: AppTheme.textSecondary),
            hintText: '192.168.1.100:18901',
            hintStyle: TextStyle(
              color: AppTheme.textSecondary.withValues(alpha: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: AppTheme.textSecondary.withValues(alpha: 0.3),
              ),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryColor),
            ),
          ),
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: (state.isSwapInitiating || !connected)
              ? null
              : () => _initiateSwap(state, ticker),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: state.isSwapInitiating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'INITIATE SWAP',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _statusCard(String text, bool isError) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: (isError ? AppTheme.errorColor : AppTheme.successColor).withValues(
        alpha: 0.1,
      ),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: isError ? AppTheme.errorColor : AppTheme.successColor,
        fontSize: 12,
      ),
    ),
  );

  Widget _activeSection(List active) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Active Swaps',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      ...active.map(
        (swap) => Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      swap.pairName,
                      style: const TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    swap.state,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  if (swap.state == 'INITIATED')
                    TextButton(
                      onPressed: () =>
                          context.read<DexCubit>().acceptSwap(swap.swapId),
                      child: const Text(
                        'Accept',
                        style: TextStyle(
                          color: AppTheme.successColor,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  TextButton(
                    onPressed: () =>
                        context.read<DexCubit>().refundSpvSwap(swap.swapId),
                    child: const Text(
                      'Refund',
                      style: TextStyle(
                        color: AppTheme.errorColor,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${swap.xfgAmountDecimal.toStringAsFixed(2)} XFG \u2192 ${swap.ctrAmountDecimal.toStringAsFixed(4)} ${swap.pairName}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                ),
              ),
              Text(
                'ID: ${swap.swapId.substring(0, 12)}\u2026',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Widget _historySection(List history) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'History',
        style: TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      ...history.map((swap) {
        final isRefunded =
            swap.state.contains('REFUND') || swap.state.contains('FAILED');
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                isRefunded ? Icons.replay : Icons.check_circle,
                color: isRefunded
                    ? AppTheme.warningColor
                    : AppTheme.successColor,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${swap.xfgAmountDecimal.toStringAsFixed(2)} XFG \u2192 ${swap.pairName}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                  ),
                ),
              ),
              Text(
                swap.state,
                style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
              ),
            ],
          ),
        );
      }),
    ],
  );
}
