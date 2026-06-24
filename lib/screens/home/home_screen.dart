import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/wallet/wallet_cubit.dart';
import '../../utils/theme.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/quick_actions.dart';
import '../../widgets/recent_transactions.dart';
import '../transactions/send_screen.dart';
import '../transactions/receive_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _refreshController;
  late Animation<double> _refreshAnimation;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeWallet();
  }

  void _setupAnimations() {
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _refreshAnimation = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _refreshController, curve: Curves.easeInOut));
  }

  Future<void> _initializeWallet() async {
    final cubit = context.read<WalletCubit>();
    await cubit.refreshWallet();
    await cubit.refreshTransactions();
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _refreshController.forward();
    try {
      final cubit = context.read<WalletCubit>();
      await Future.wait([cubit.refreshWallet(), cubit.refreshTransactions()]);
    } finally {
      _refreshController.reset();
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _navigateToSend() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SendScreen()));
  }

  void _navigateToReceive() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReceiveScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WalletCubit, WalletState>(
      builder: (context, state) {
        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
            child: SafeArea(
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: AppTheme.primaryColor,
                backgroundColor: AppTheme.cardColor,
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 120,
                      floating: true,
                      pinned: true,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      flexibleSpace: FlexibleSpaceBar(
                        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                        title: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Fuego Wallet', style: TextStyle(
                                color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.bold)),
                            Text(
                              state.isConnected
                                  ? (state.isSynced ? 'Synchronized' : 'Syncing...')
                                  : 'Offline',
                              style: TextStyle(
                                color: state.isConnected
                                    ? (state.isSynced ? AppTheme.successColor : AppTheme.warningColor)
                                    : AppTheme.errorColor,
                                fontSize: 12, fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      actions: [
                        AnimatedBuilder(
                          animation: _refreshAnimation,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _refreshAnimation.value * 2 * 3.14159,
                              child: IconButton(
                                icon: Icon(Icons.refresh,
                                    color: _isRefreshing ? AppTheme.primaryColor : AppTheme.textSecondary),
                                onPressed: _isRefreshing ? null : _onRefresh,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          const BalanceCard(),
                          const SizedBox(height: 20),
                          QuickActions(
                            onSendTap: _navigateToSend,
                            onReceiveTap: _navigateToReceive,
                            onScanTap: _onScanQR,
                            onMineTap: _onToggleMining,
                          ),
                          const SizedBox(height: 20),
                          if (state.isSyncing && !state.isSynced)
                            _buildSyncProgress(state),
                          const RecentTransactions(),
                          const SizedBox(height: 20),
                          if (state.isMining) _buildMiningStatus(state),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSyncProgress(WalletState state) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.sync, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              const Text('Synchronizing Blockchain', style: TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${state.syncProgress}%',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: state.syncProgress / 100,
              backgroundColor: AppTheme.surfaceColor,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiningStatus(WalletState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.successColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.successColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.memory, color: AppTheme.successColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Mining Active', style: TextStyle(
                    color: AppTheme.successColor, fontWeight: FontWeight.bold)),
                Text('${state.miningSpeed} H/s with ${state.miningThreads} threads',
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.read<WalletCubit>().stopMining(),
            child: const Text('Stop'),
          ),
        ],
      ),
    );
  }

  void _onScanQR() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR scanning coming soon'), backgroundColor: AppTheme.primaryColor),
    );
  }

  void _onToggleMining() {
    final cubit = context.read<WalletCubit>();
    if (cubit.state.isMining) {
      cubit.stopMining();
    } else {
      _showMiningDialog();
    }
  }

  void _showMiningDialog() {
    int threads = 1;
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.cardColor,
              title: const Text('Start Mining', style: TextStyle(color: AppTheme.textPrimary)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Choose the number of CPU threads:',
                      style: TextStyle(color: AppTheme.textSecondary)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Threads:', style: TextStyle(color: AppTheme.textPrimary)),
                      Expanded(
                        child: Slider(
                          value: threads.toDouble(),
                          min: 1, max: 8, divisions: 7,
                          label: threads.toString(),
                          activeColor: AppTheme.primaryColor,
                          onChanged: (v) => setDialogState(() => threads = v.round()),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                ),
                ElevatedButton(
                  onPressed: () {
                    context.read<WalletCubit>().startMining(threads: threads);
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Start Mining'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }
}
