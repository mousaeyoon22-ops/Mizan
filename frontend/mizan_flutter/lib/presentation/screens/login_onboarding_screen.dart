import 'package:flutter/material.dart';
import '../../data/remote/mizan_api_client.dart';

/// Fixes DEF-407: Connects to live `/api/v1/auth/login` via `MizanApiClient`,
/// with an explicit Offline City-Pilot fallback mode when operating without network.
class LoginOnboardingScreen extends StatefulWidget {
  final bool isArabic;
  final MizanApiClient? apiClient;
  final void Function(String emailOrPhone, String role) onAuthenticated;

  const LoginOnboardingScreen({
    super.key,
    required this.isArabic,
    this.apiClient,
    required this.onAuthenticated,
  });

  @override
  State<LoginOnboardingScreen> createState() => _LoginOnboardingScreenState();
}

class _LoginOnboardingScreenState extends State<LoginOnboardingScreen> {
  final TextEditingController _idCtrl = TextEditingController(text: 'owner@seha-pilot.local');
  final TextEditingController _passCtrl = TextEditingController();
  String _selectedRole = 'OWNER';
  bool _submitting = false;
  String? _statusMessage;

  Future<void> _submitServerLogin() async {
    if (widget.apiClient == null || _passCtrl.text.isEmpty) {
      widget.onAuthenticated(_idCtrl.text.trim(), _selectedRole);
      return;
    }
    setState(() {
      _submitting = true;
      _statusMessage = null;
    });
    try {
      await widget.apiClient!.login(emailOrPhone: _idCtrl.text.trim(), password: _passCtrl.text);
      widget.onAuthenticated(_idCtrl.text.trim(), _selectedRole);
    } catch (e) {
      setState(() {
        _statusMessage = widget.isArabic
            ? 'تعذّر الاتصال بالخادم الحي — يمكنك الدخول بوضع الأوفلاين الميداني'
            : 'Live server unreachable — you can continue in Offline Field Mode';
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.isArabic ? 'تسجيل الدخول — ميزان v2.2' : 'Sign In — Mizan v2.2')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            const Icon(Icons.balance, size: 56, color: Color(0xFF0F766E)),
            const SizedBox(height: 12),
            Text(
              widget.isArabic ? 'ميزان — لكل عملية سجل، ولكل رصيد دليل' : 'Mizan — Every Transaction Recorded, Every Balance Proven',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _idCtrl,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: widget.isArabic ? 'البريد الإلكتروني أو رقم الهاتف' : 'Email or Phone',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passCtrl,
              obscureText: true,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: widget.isArabic ? 'كلمة المرور' : 'Password',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedRole,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                labelText: widget.isArabic ? 'الدور الوظيفي' : 'Workspace Role',
              ),
              items: const [
                DropdownMenuItem(value: 'OWNER', child: Text('OWNER — مالك المنشأة')),
                DropdownMenuItem(value: 'ACCOUNTANT', child: Text('ACCOUNTANT — محاسب')),
                DropdownMenuItem(value: 'CASHIER', child: Text('CASHIER — كاشير')),
                DropdownMenuItem(value: 'DRIVER', child: Text('DRIVER — موزع ميداني')),
              ],
              onChanged: (v) => setState(() => _selectedRole = v ?? 'OWNER'),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 10),
              Text(_statusMessage!, style: const TextStyle(color: Colors.orange)),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: const Icon(Icons.login),
              label: Text(_submitting ? '...' : (widget.isArabic ? 'دخول للنظام' : 'Sign In')),
              onPressed: _submitting ? null : _submitServerLogin,
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.offline_bolt_outlined),
              label: Text(widget.isArabic ? 'دخول مباشر بوضع الأوفلاين الميداني' : 'Continue Offline Field Mode'),
              onPressed: () => widget.onAuthenticated(_idCtrl.text.trim(), _selectedRole),
            ),
          ],
        ),
      ),
    );
  }
}
