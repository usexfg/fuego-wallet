import 'package:flutter/material.dart';
import '../../main.dart' as app;
import '../../services/daemon_manager.dart';
import '../../utils/theme.dart';
import '../home/home_screen.dart';
import '../dex/dex_screen.dart';
import '../fuego/cd/cd_overview_screen.dart';
import '../fuego/hearth/hearth_screen.dart';
import '../settings/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  bool _showDaemonDetails = false;

  final List<Widget> _screens = const [
    HomeScreen(),
    HearthScreen(),
    CdOverviewScreen(),
    DexScreen(),
    SettingsScreen(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.account_balance_wallet, label: 'Wallet'),
    _NavItem(icon: Icons.swap_horiz, label: 'Hearth'),
    _NavItem(icon: Icons.savings, label: 'CDs'),
    _NavItem(icon: Icons.swap_calls, label: 'DEX'),
    _NavItem(icon: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Daemon status bar
          ValueListenableBuilder<DaemonStatus>(
            valueListenable: app.daemonManager.status,
            builder: (context, status, _) {
              if (status.allHealthy && app.daemonError == null) return const SizedBox.shrink();
              final issues = <String>[];
              if (!status.fuegodRunning) issues.add('Node');
              if (!status.walletdRunning) issues.add('Wallet');
              if (!status.swapdRunning) issues.add('Swap');
              final hasStartupError = app.daemonError != null;
              final hasDaemonErrors = issues.isNotEmpty;
              if (!hasStartupError && !hasDaemonErrors) return const SizedBox.shrink();

              return GestureDetector(
                onTap: () => setState(() => _showDaemonDetails = !_showDaemonDetails),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  color: AppTheme.errorColor.withValues(alpha: 0.12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.error_outline, color: AppTheme.errorColor, size: 14),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            hasStartupError
                                ? app.daemonError!
                                : '${issues.join(", ")} offline',
                            style: const TextStyle(color: AppTheme.errorColor, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          _showDaemonDetails ? Icons.expand_less : Icons.expand_more,
                          color: AppTheme.errorColor,
                          size: 16,
                        ),
                      ]),
                      if (_showDaemonDetails) ...[
                        const SizedBox(height: 6),
                        if (!status.fuegodRunning)
                          _daemonDetail('Node (fuegod)', status.fuegodError),
                        if (!status.walletdRunning)
                          _daemonDetail('Wallet (walletd)', status.walletdError),
                        if (!status.swapdRunning)
                          _daemonDetail('Swap (xfg-swapd)', status.swapdError),
                        if (hasStartupError)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Tip: Check that binaries exist next to the app, or set FUEGO_USE_LOCAL_NODE=0 for remote mode.',
                              style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.8), fontSize: 10),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          // Main content
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          border: Border(
            top: BorderSide(
              color: AppTheme.textMuted.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (i) {
                final isSelected = _currentIndex == i;
                return GestureDetector(
                  onTap: () => setState(() => _currentIndex = i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _navItems[i].icon,
                          color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _navItems[i].label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _daemonDetail(String name, String? error) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, color: AppTheme.errorColor, size: 6),
          const SizedBox(width: 6),
          Text('$name: ', style: const TextStyle(color: AppTheme.textMuted, fontSize: 10)),
          Expanded(
            child: Text(
              error ?? 'binary not found or port conflict',
              style: const TextStyle(color: AppTheme.errorColor, fontSize: 10),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
