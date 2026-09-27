import 'package:flutter/material.dart';

import '../domain/cashier_login_service.dart';

class ChangeTemporaryPinScreen extends StatefulWidget {
  const ChangeTemporaryPinScreen({
    super.key,
    required this.cashierId,
    required this.onChange,
    required this.onResult,
  });

  final String cashierId;
  final Future<CashierLoginResult> Function(
      String cashierId, String currentPin, String newPin) onChange;
  final void Function(CashierLoginResult result) onResult;

  @override
  State<ChangeTemporaryPinScreen> createState() =>
      _ChangeTemporaryPinScreenState();
}

class _ChangeTemporaryPinScreenState extends State<ChangeTemporaryPinScreen> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _change() async {
    if (_busy) return;
    if (!RegExp(r'^\d{4,6}$').hasMatch(_next.text) ||
        _current.text == _next.text) {
      setState(() => _error = 'Choose a different 4–6 digit PIN');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.onChange(
        widget.cashierId,
        _current.text,
        _next.text,
      );
      _current.clear();
      _next.clear();
      widget.onResult(result);
    } catch (error) {
      if (mounted) setState(() => _error = 'Unable to change PIN: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Change temporary PIN')),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                const Text('Set a permanent PIN before using this POS.'),
                const SizedBox(height: 20),
                TextField(
                    controller: _current,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Temporary PIN')),
                TextField(
                    controller: _next,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'New PIN')),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: _busy ? null : _change,
                    child: Text(_busy ? 'Saving…' : 'Save new PIN')),
              ]),
        )),
      );
}
