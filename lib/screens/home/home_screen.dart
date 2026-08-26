import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/core.dart';
import '../../bloc/wallet/wallet_cubit.dart';
import '../../bloc/mining/mining_cubit.dart';
import '../../utils/theme.dart';
import '../transactions/transaction_details_screen.dart';
import '../transactions/send_screen.dart';
import '../transactions/mint_heat_screen.dart';
import '../transactions/receive_screen.dart';
import '../../utils/xfg_ticker.dart';

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

  static const _obsidian = Color(0xFF0C0C0F);
  static const _champagne = Color(0xFFC9A96A);
  static const _platinum = Color(0xFFE9E7E2);

  /// Thin-space thousands grouping for prestige figures.
  String _grouped(String fixed) {
    final parts = fixed.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}\u2009',
    );
    return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  }

  Widget _balanceCard(WalletState state) {
    return Container(
      decoration: BoxDecoration(
        color: _obsidian,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.55),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: const _GuillochePainter())),
            // Inner champagne bezel
            Padding(
              padding: const EdgeInsets.all(5),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: _champagne.withOpacity(0.25),
                    width: 0.8,
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      xfgText(
                        'XFG BALANCE',
                        style: TextStyle(
                          color: _champagne.withOpacity(0.75),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 4,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _showBalance = !_showBalance),
                        child: Icon(
                          _showBalance
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: _champagne.withOpacity(0.55),
                          size: 17,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _showBalance
                              ? _grouped(state.balanceXfg
                                  .toStringAsFixed(decimalPlaces))
                              : '••••••••',
                          style: TextStyle(
                            color: _platinum,
                            fontSize: 42,
                            fontWeight: FontWeight.w300,
                            height: 1.0,
                            letterSpacing: -0.5,
                            fontFamily: AppTheme.numberFontFamily,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: xfgText(
                            'XFG',
                            style: TextStyle(
                              color: _champagne,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(height: 0.8, color: Colors.white.withOpacity(0.06)),
                  const SizedBox(height: 12),
                  _statementRow(
                    'AVAILABLE',
                    _showBalance
                        ? _grouped(state.unlockedBalanceXfg
                            .toStringAsFixed(decimalPlaces))
                        : '••••••••',
                  ),
                  if (state.totalHeatXfg > 0) ...[
                    const SizedBox(height: 8),
                    _statementRow(
                      'ΗΞΔŦ UNLOCKED',
                      _showBalance
                          ? _grouped(state.unlockedHeatXfg
                              .toStringAsFixed(decimalPlaces))
                          : '••••••••',
                      valueColor: AppTheme.accentColor,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(height: 0.8, color: Colors.white.withOpacity(0.06)),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _actionBtn('Send', Icons.arrow_upward, () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => const SendScreen()),
                          );
                        }),
                        const SizedBox(width: 16),
                        _actionBtn('Mint ΗΞΔŦ', Icons.arrow_upward, () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const MintHeatScreen(),
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _statementRow(
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.38),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 3,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            color: valueColor ?? _platinum.withOpacity(0.92),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: AppTheme.numberFontFamily,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
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
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                SelectableText(
                  addr,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 11,
                    fontFamily: 'IBMPlexMono',
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
        final miningCubit = context.read<MiningCubit>();
        final miningSupported = miningCubit.isMiningSupported;
        final addr = state.address;
        final canMine = miningSupported && addr != null && addr.isNotEmpty;

        String statusText;
        String? miningHashrate;
        Color statusColor;
        if (!miningSupported) {
          statusText = 'Pool mining unavailable on iOS due to Appstore policy';
          statusColor = AppTheme.textMuted;
        } else {
          switch (mining.status) {
            case 'connecting':
              statusText =
                  'Connecting to ${mining.poolHost}:${mining.poolPort}...';
              statusColor = Colors.orange;
            case 'connected':
              statusText = 'Connected — waiting for jobs';
              statusColor = Colors.cyanAccent;
            case 'mining':
              statusText = 'Mining — ';
              statusColor = AppTheme.successColor;
              miningHashrate = '${mining.hashrate} H/s';
            case 'error':
              statusText = mining.error ?? 'Connection failed';
              statusColor = AppTheme.errorColor;
            default:
              statusText = 'Pool Miner (${mining.poolHost}:${mining.poolPort})';
              statusColor = AppTheme.textMuted;
          }
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
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(color: statusColor, fontSize: 14),
                        children: [
                          TextSpan(text: statusText),
                          if (miningHashrate != null)
                            TextSpan(
                              text: miningHashrate,
                              style: TextStyle(
                                fontFamily: AppTheme.numberFontFamily,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
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
              if (miningSupported) ...[
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
                        items: miningCubit.coreOptions
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
                                  context.read<MiningCubit>().setCoreCount(
                                    cores,
                                  );
                                }
                              },
                      ),
                    ),
                  ],
                ),
              ],
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
                      fontFamily: 'IBMPlexMono',
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
            xfgText(
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

/// Engine-turned guilloché texture: fine concentric ring sets from two
/// off-canvas centres, evoking a hand-lacquered watch dial at ~3% ink.
class _GuillochePainter extends CustomPainter {
  const _GuillochePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final white = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = Colors.white.withOpacity(0.035);
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7
      ..color = const Color(0xFFC9A96A).withOpacity(0.05);

    void rings(Offset center, int count, double step, Paint paint) {
      for (var i = 1; i <= count; i++) {
        canvas.drawCircle(center, i * step, paint);
      }
    }

    rings(Offset(size.width * 0.88, -size.height * 0.30), 26, 15, white);
    rings(const Offset(-30, 0), 14, 17, white);
    rings(
      Offset(size.width * 0.88, -size.height * 0.30),
      9,
      42,
      gold,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
