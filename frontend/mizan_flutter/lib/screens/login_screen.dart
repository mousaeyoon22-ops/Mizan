import 'package:flutter/material.dart';
import '../l10n/mizan_l10n.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';

class LoginScreen extends StatefulWidget {
  final MizanStore store;
  const LoginScreen({super.key, required this.store});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController _emailCtrl;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.store.currentUserEmail);
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.balance_rounded, size: 64, color: MizanColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    s.t('app_title'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s.t('login_subtitle'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: MizanColors.muted),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: MizanL10n.supported.map((lang) {
                      final selected = lang.code == s.languageCode;
                      return ChoiceChip(
                        label: Text(lang.nativeName),
                        selected: selected,
                        onSelected: (_) => s.setLanguage(lang.code),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _emailCtrl,
                    decoration: InputDecoration(
                      labelText: s.t('email'),
                      prefixIcon: const Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => s.login(_emailCtrl.text),
                    icon: const Icon(Icons.login_rounded),
                    label: Text(s.t('login_btn')),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${s.t('sqlite_active')} (${s.activeSqliteTables})',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: MizanColors.success, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
