import 'package:flutter/material.dart';
import '../state/mizan_store.dart';
import '../theme/mizan_theme.dart';
import '../widgets/mizan_widgets.dart';

class LoginScreen extends StatefulWidget {
  final MizanStore store;
  const LoginScreen({super.key, required this.store});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController(text: 'owner@seha-pilot.local');
  final _passCtrl = TextEditingController();
  String _role = 'OWNER — مالك المنشأة';

  final _roles = const [
    'OWNER — مالك المنشأة',
    'ACCOUNTANT — محاسب مالي',
    'CASHIER — أمين صندوق / كاشير',
    'DISTRIBUTOR — موزع ميداني',
  ];

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [MizanColors.primaryDark, MizanColors.primary],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.balance_rounded, color: Colors.white, size: 42),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'ميزان v3.0',
                          style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'لكل عملية سجل، ولكل رصيد دليل',
                          style: TextStyle(color: Color(0xFFD9F2EC), fontSize: 13.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  MizanCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'البريد الإلكتروني أو رقم الهاتف',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'كلمة المرور',
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _role,
                          decoration: const InputDecoration(
                            labelText: 'الدور الوظيفي',
                            prefixIcon: Icon(Icons.verified_user_outlined),
                          ),
                          items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                          onChanged: (v) => setState(() => _role = v ?? _role),
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: () => widget.store.login(
                            email: _emailCtrl.text.trim(),
                            role: _role,
                            offline: false,
                          ),
                          icon: const Icon(Icons.login_rounded),
                          label: const Text('دخول للنظام'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => widget.store.login(
                            email: _emailCtrl.text.trim(),
                            role: _role,
                            offline: true,
                          ),
                          icon: const Icon(Icons.bolt_rounded),
                          label: const Text('دخول مباشر بوضع الأوفلاين الميداني'),
                        ),
                      ],
                    ),
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
