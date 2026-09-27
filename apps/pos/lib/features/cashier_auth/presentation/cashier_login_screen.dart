import 'package:flutter/material.dart';

import '../domain/cashier_login_service.dart';

class CashierLoginScreen extends StatefulWidget {
  const CashierLoginScreen({
    super.key,
    required this.onLogin,
    required this.onResult,
  });

  final Future<CashierLoginResult> Function(String cashierId, String pin)
      onLogin;
  final void Function(String cashierId, CashierLoginResult result) onResult;

  @override
  State<CashierLoginScreen> createState() => _CashierLoginScreenState();
}

class _CashierLoginScreenState extends State<CashierLoginScreen> {
  final _cashierId = TextEditingController();
  final _pin = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _cashierId.dispose();
    _pin.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final cashierId = _cashierId.text.trim();
    if (_busy) return;
    if (cashierId.isEmpty || _pin.text.isEmpty) {
      setState(() => _error = 'Enter cashier ID and PIN');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.onLogin(cashierId, _pin.text);
      _pin.clear();
      if (result.status == CashierLoginStatus.invalidPin) {
        if (mounted) setState(() => _error = 'Incorrect PIN');
      } else if (result.status == CashierLoginStatus.cooldown) {
        if (mounted) {
          setState(() => _error = 'Too many attempts. Try again shortly.');
        }
      } else {
        widget.onResult(cashierId, result);
      }
    } catch (error) {
      if (mounted) setState(() => _error = 'Sign-in failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Cashier sign in')),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                const Text('Enter your cashier ID and PIN to start a session.'),
                const SizedBox(height: 20),
                TextField(
                    controller: _cashierId,
                    decoration: const InputDecoration(labelText: 'Cashier ID')),
                TextField(
                    controller: _pin,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'PIN'),
                    onSubmitted: (_) => _login()),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: _busy ? null : _login,
                    child: Text(_busy ? 'Checking…' : 'Sign in')),
              ]),
        )),
      );
}
