import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../main.dart' as app;
import '../../services/daemon_event_bus.dart';
import '../../utils/theme.dart';
import '../home/home_screen.dart';
import '../dex/dex_screen.dart';
import '../dex/peer_swap_screen.dart';
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
    PeerSwapScreen(),
    SettingsScreen(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Icons.account_balance_wallet, label: 'Wallet'),
    _NavItem(icon: Icons.swap_horiz, label: 'Hearth'),
    _NavItem(icon: Icons.savings, label: 'CDs'),
    _NavItem(icon: Icons.storefront, label: 'DEX'),
    _NavItem(icon: Icons.handshake, label: 'Swaps'),
    _NavItem(icon: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Daemon status bar — driven by EventBus health
          ValueListenableBuilder<DaemonHealthSnapshot>(
            valueListenable: app.daemonManager.eventBus.health,
            builder: (context, health, _) {
              // Show bar if any daemon is down, or startup error exists
              if (health.allHealthy && app.daemonError == null) return const SizedBox.shrink();
              final hasStartupError = app.daemonError != null;
              final hasIssues = !health.allHealthy;
              if (!hasStartupError && !hasIssues) return const SizedBox.shrink();

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
                          child: SelectableText(
                            hasStartupError
                                ? app.daemonError!
                                : health.displayText,
                            style: const TextStyle(color: AppTheme.errorColor, fontSize: 11),
                            maxLines: 1,
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
                        // Unified daemon status
                        _daemonDetail('Unified', app.daemonManager.unifiedRunning ? null : 'not running'),
                        // Individual daemon statuses
                        if (!health.fuegodRunning)
                          _daemonDetail('  fuegod', health.fuegodError),
                        if (!health.walletdRunning)
                          _daemonDetail('  walletd', health.walletdError),
                        if (!health.swapdRunning)
                          _daemonDetail('  xfg-swapd', health.swapdError),
                        if (hasStartupError)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Tip: Check that unified binary exists next to the app, or set FUEGO_USE_LOCAL_NODE=0 for remote mode.',
                              style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.8), fontSize: 10),
                            ),
                          ),
                        // Copy button for error reporting
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: GestureDetector(
                            onTap: () {
                              final text = hasStartupError ? app.daemonError! : health.displayText;
                              Clipboard.setData(ClipboardData(text: text));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Status copied to clipboard'), duration: Duration(seconds: 1)),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy, size: 12, color: AppTheme.textMuted.withValues(alpha: 0.6)),
                                const SizedBox(width: 4),
                                Text('Copy status', style: TextStyle(color: AppTheme.textMuted.withValues(alpha: 0.6), fontSize: 10)),
                              ],
                            ),
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
