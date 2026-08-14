import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/core.dart';
import '../../bloc/wallet/wallet_cubit.dart';
import '../../bloc/mining/mining_cubit.dart';
import '../../utils/theme.dart';
import '../transactions/transaction_details_screen.dart';
import '../transactions/send_screen.dart';
import '../transactions/send_heat_screen.dart';
import '../transactions/receive_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showBalance = true;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletCubit, WalletState>(
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: () => context.read<WalletCubit>().refreshWallet(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _balanceCard(state),
              const SizedBox(height: 16),
              if (state.address != null) _addressCard(state),
              const SizedBox(height: 16),
              _infoRow(state),
              const SizedBox(height: 16),
              _miningControls(state),
              const SizedBox(height: 16),
              const Text(
                'Recent Transactions',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (state.transactions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No transactions yet',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...state.transactions.take(10).map((tx) => _txCard(tx)),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    state.error!,
                    style: const TextStyle(
                      color: AppTheme.errorColor,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _balanceCard(WalletState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'XFG BALANCE',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  letterSpacing: 1,
                ),
              ),
              IconButton(
                icon: Icon(
                  _showBalance ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () => setState(() => _showBalance = !_showBalance),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _showBalance
                  ? state.balanceXfg.toStringAsFixed(decimalPlaces)
                  : '••••••••',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _showBalance
                  ? '${state.unlockedBalanceXfg.toStringAsFixed(decimalPlaces)} available'
                  : '••••••••',
              style: const TextStyle(color: Colors.white60, fontSize: 13),
            ),
          ),
          const SizedBox(height: 12),
          // HEAT balance row
          if (state.totalHeatXfg > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'HEAT',
                    style: TextStyle(
                      color: AppTheme.accentColor,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        _showBalance
                            ? state.unlockedHeatXfg.toStringAsFixed(
                                decimalPlaces,
                              )
                            : '••••••••',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionBtn('Send', Icons.arrow_upward, () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const SendScreen()),
                  );
                }),
                const SizedBox(width: 16),
                _actionBtn('Send HEAT', Icons.arrow_upward, () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const SendHeatScreen(),
                    ),
                  );
                }, color: AppTheme.accentColor),
                const SizedBox(width: 16),
                _actionBtn('Receive', Icons.arrow_downward, () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ReceiveScreen(),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _addressCard(WalletState state) {
    final addr = state.address ?? '';
    final alias = state.alias; // Assuming alias is in WalletState
    if (addr.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.wallet, color: AppTheme.primaryColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (alias != null)
                  Text(
                    '@$alias',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                SelectableText(
                  addr,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: addr));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Address copied'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Icon(Icons.copy, color: AppTheme.textMuted, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    String label,
    IconData icon,
    VoidCallback onTap, {
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: (color ?? Colors.white).withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: color ?? Colors.white, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(WalletState state) {
    return Row(
      children: [
        _infoTile('Peers', '${state.peerCount}', Icons.people),
        const SizedBox(width: 8),
        _infoTile('Min Fee', formatXfg(txFee), Icons.receipt),
        const SizedBox(width: 8),
        _infoTile('Height', '${state.blockHeight}', Icons.tag),
      ],
    );
  }

  Widget _infoTile(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primaryColor, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              label,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _miningControls(WalletState state) {
    return BlocBuilder<MiningCubit, MiningState>(
      builder: (context, mining) {
        final addr = state.address;
        final canMine = addr != null && addr.isNotEmpty;

        String statusText;
        Color statusColor;
        switch (mining.status) {
          case 'connecting':
            statusText =
                'Connecting to ${mining.poolHost}:${mining.poolPort}...';
            statusColor = Colors.orange;
          case 'connected':
            statusText = 'Connected — waiting for jobs';
            statusColor = Colors.cyanAccent;
          case 'mining':
            statusText = 'Mining — ${mining.hashrate} H/s';
            statusColor = AppTheme.successColor;
          case 'error':
            statusText = mining.error ?? 'Connection failed';
            statusColor = AppTheme.errorColor;
          default:
            statusText = 'Pool Miner (${mining.poolHost}:${mining.poolPort})';
            statusColor = AppTheme.textMuted;
        }

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  if (mining.status == 'connecting')
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(
                      Icons.memory,
                      color: mining.isMining
                          ? AppTheme.successColor
                          : AppTheme.textMuted,
                      size: 18,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusText,
                      style: TextStyle(color: statusColor, fontSize: 12),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: !canMine
                        ? null
                        : () {
                            if (mining.isMining) {
                              context.read<MiningCubit>().stopMining();
                            } else {
                              context.read<MiningCubit>().startMining(
                                walletAddress: addr,
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: mining.isMining
                          ? AppTheme.errorColor
                          : AppTheme.successColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      disabledBackgroundColor: AppTheme.textMuted.withOpacity(
                        0.3,
                      ),
                    ),
                    child: Text(mining.isMining ? 'Stop' : 'Start'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Cores',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: mining.coreCount,
                      dropdownColor: AppTheme.cardColor,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 11,
                      ),
                      isDense: true,
                      items: context
                          .read<MiningCubit>()
                          .coreOptions
                          .map(
                            (cores) => DropdownMenuItem<int>(
                              value: cores,
                              child: Text('$cores'),
                            ),
                          )
                          .toList(),
                      onChanged: mining.isMining
                          ? null
                          : (cores) {
                              if (cores != null) {
                                context.read<MiningCubit>().setCoreCount(cores);
                              }
                            },
                    ),
                  ),
                ],
              ),
              if (mining.sharesAccepted > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Shares: ${mining.sharesAccepted}',
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ),
              if (!canMine)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: const Text(
                    'Wallet address not available',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 10),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _txCard(FuegoTransaction tx) {
    final isIn = tx.isIncoming;
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => TransactionDetailsScreen(transaction: tx),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              isIn ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIn ? AppTheme.successColor : AppTheme.errorColor,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.txHash.substring(0, 16) + '...',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                  Text(
                    tx.dateTime.toString().substring(0, 19),
                    style: const TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '${isIn ? '+' : '-'}${tx.amount.toStringAsFixed(decimalPlaces)} XFG',
              style: TextStyle(
                color: isIn ? AppTheme.successColor : AppTheme.errorColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
