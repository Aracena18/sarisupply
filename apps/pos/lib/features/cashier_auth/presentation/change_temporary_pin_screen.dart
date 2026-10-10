import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

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
    final validation = !RegExp(r'^\d{4,6}$').hasMatch(_current.text)
        ? 'Enter your 4–6 digit temporary PIN'
        : !RegExp(r'^\d{4,6}$').hasMatch(_next.text)
            ? 'Use 4–6 digits for your new PIN'
            : _current.text == _next.text
                ? 'Choose a different PIN'
                : null;
    if (validation != null) {
      _current.clear();
      _next.clear();
      setState(() => _error = validation);
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
      if (!mounted) return;
      if (result.status == CashierLoginStatus.invalidPin ||
          result.status == CashierLoginStatus.cooldown) {
        setState(() => _error = result.status == CashierLoginStatus.invalidPin
            ? 'Incorrect temporary PIN'
            : 'Too many attempts. Wait and try again.');
      } else {
        widget.onResult(result);
      }
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) {
        _current.clear();
        _next.clear();
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: sariSupplyTaskAppBar(context, title: 'Change temporary PIN'),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.all(
                  MediaQuery.sizeOf(context).width < 600 ? 16 : 24),
              children: [
                TextField(
                    controller: _current,
                    enabled: !_busy,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Temporary PIN')),
                const SizedBox(height: 16),
                TextField(
                    controller: _next,
                    enabled: !_busy,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'New PIN')),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(_error!,
                          style: TextStyle(color: SariSupplyColors.error))),
                const SizedBox(height: 20),
                FilledButton(
                    onPressed: _busy ? null : _change,
                    child: Text(_busy ? 'Saving…' : 'Save new PIN')),
              ]),
        )),
      );
}
