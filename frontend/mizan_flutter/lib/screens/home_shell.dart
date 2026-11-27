import 'package:flutter/material.dart';
import '../state/mizan_store.dart';
import '../models/mizan_models.dart';
import '../theme/mizan_theme.dart';
import 'workspace_screen.dart';
import 'invoice_screen.dart';
import 'inventory_screen.dart';
import 'accounts_screen.dart';
import 'vouchers_screen.dart';
import 'qr_cart_screen.dart';
import 'gates_screen.dart';
import 'fx_screen.dart';
import 'more_screen.dart';

class HomeShell extends StatefulWidget {
  final MizanStore store;
  const HomeShell({super.key, required this.store});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _openQuickSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('إجراء سريع', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _sheetBtn(ctx, 'فاتورة بيع / شراء', Icons.receipt_long_rounded, MizanColors.primary, () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => InvoiceBuilderScreen(store: widget.store)));
                  }),
                  _sheetBtn(ctx, 'سند قبض / صرف', Icons.payments_rounded, MizanColors.success, () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => VouchersScreen(store: widget.store)));
                  }),
                  _sheetBtn(ctx, 'إضافة صنف / جرد', Icons.inventory_2_rounded, MizanColors.info, () {
                    Navigator.pop(ctx);
                    setState(() => _index = 2);
                  }),
                  _sheetBtn(ctx, 'عميل / صندوق', Icons.account_balance_wallet_rounded, MizanColors.accent, () {
                    Navigator.pop(ctx);
                    setState(() => _index = 3);
                  }),
                  _sheetBtn(ctx, 'مصارفة (IAS 21)', Icons.currency_exchange_rounded, const Color(0xFF7C3AED), () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => FxScreen(store: widget.store)));
                  }),
                  _sheetBtn(ctx, 'مسح QR والسلة', Icons.qr_code_scanner_rounded, MizanColors.primaryDark, () {
                    Navigator.pop(ctx);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => QrCartScreen(store: widget.store)));
                  }),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sheetBtn(BuildContext ctx, String label, IconData icon, Color c, VoidCallback onTap) {
    return SizedBox(
      width: (MediaQuery.of(ctx).size.width - 42) / 2,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: c,
          side: BorderSide(color: c.withValues(alpha: 0.4)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        ),
        icon: Icon(icon, size: 20),
        label: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      WorkspaceScreen(
        store: widget.store,
        onNavigateTab: (i) => setState(() => _index = i),
      ),
      InvoicesHubScreen(store: widget.store),
      InventoryScreen(store: widget.store),
      AccountsScreen(store: widget.store),
      MoreScreen(store: widget.store),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: _openQuickSheet,
              backgroundColor: MizanColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('عملية جديدة', style: TextStyle(fontWeight: FontWeight.w700)),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard_rounded), label: 'العمل'),
          NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'الفواتير'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2_rounded), label: 'المخازن'),
          NavigationDestination(icon: Icon(Icons.account_balance_outlined), selectedIcon: Icon(Icons.account_balance_rounded), label: 'الحسابات'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune_rounded), label: 'المزيد'),
        ],
      ),
    );
  }
}
