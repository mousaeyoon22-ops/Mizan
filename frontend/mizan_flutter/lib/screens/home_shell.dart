import 'package:flutter/material.dart';
import '../state/mizan_store.dart';
import 'accounts_screen.dart';
import 'inventory_screen.dart';
import 'invoices_screen.dart';
import 'more_screen.dart';
import 'network_hub_screen.dart';
import 'reports_screen.dart';
import 'vouchers_screen.dart';
import 'workspace_screen.dart';

class HomeShell extends StatefulWidget {
  final MizanStore store;
  const HomeShell({super.key, required this.store});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final pages = [
      WorkspaceScreen(store: s, onNavigate: (i) => setState(() => _index = i)),
      AccountsScreen(store: s),
      InvoicesScreen(store: s),
      VouchersScreen(store: s),
      InventoryScreen(store: s),
      NetworkHubScreen(store: s),
      ReportsScreen(store: s),
      MoreScreen(store: s),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index > 4 ? 4 : _index,
        onDestinationSelected: (i) {
          if (i == 4) {
            _showFullMenu(context);
          } else {
            setState(() => _index = i);
          }
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined), selectedIcon: const Icon(Icons.dashboard), label: s.t('nav_home')),
          NavigationDestination(icon: const Icon(Icons.account_tree_outlined), selectedIcon: const Icon(Icons.account_tree), label: s.t('nav_accounts')),
          NavigationDestination(icon: const Icon(Icons.receipt_long_outlined), selectedIcon: const Icon(Icons.receipt_long), label: s.t('nav_invoices')),
          NavigationDestination(icon: const Icon(Icons.swap_horiz_outlined), selectedIcon: const Icon(Icons.swap_horiz), label: s.t('nav_vouchers')),
          NavigationDestination(icon: const Icon(Icons.apps_rounded), selectedIcon: const Icon(Icons.apps_rounded), label: s.t('nav_more')),
        ],
      ),
    );
  }

  void _showFullMenu(BuildContext context) {
    final s = widget.store;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(16),
          children: [
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: Text(s.t('nav_inventory')),
              onTap: () { Navigator.pop(ctx); setState(() => _index = 4); },
            ),
            ListTile(
              leading: const Icon(Icons.hub_outlined),
              title: Text(s.t('nav_network')),
              onTap: () { Navigator.pop(ctx); setState(() => _index = 5); },
            ),
            ListTile(
              leading: const Icon(Icons.analytics_outlined),
              title: Text(s.t('nav_reports')),
              onTap: () { Navigator.pop(ctx); setState(() => _index = 6); },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(s.t('nav_more')),
              onTap: () { Navigator.pop(ctx); setState(() => _index = 7); },
            ),
          ],
        ),
      ),
    );
  }
}
