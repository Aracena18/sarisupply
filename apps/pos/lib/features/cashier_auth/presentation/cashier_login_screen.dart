import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

import '../domain/cashier_login_service.dart';

class CashierLoginScreen extends StatefulWidget {
  const CashierLoginScreen(
      {super.key,
      required this.onLogin,
      required this.onResult,
      this.loadCashiers,
      this.onManage});
  final Future<CashierLoginResult> Function(String cashierId, String pin)
      onLogin;
  final void Function(String cashierId, CashierLoginResult result) onResult;
  final Future<List<CashierCredentialProjection>> Function()? loadCashiers;
  final VoidCallback? onManage;
  @override
  State<CashierLoginScreen> createState() => _CashierLoginScreenState();
}

class _CashierLoginScreenState extends State<CashierLoginScreen> {
  final _cashierId = TextEditingController();
  final _pin = TextEditingController();
  final _pinFocus = FocusNode();
  String? _namedId;
  bool _busy = false, _manual = false;
  bool _namesAvailable = false;
  String? _error;
  Future<List<CashierCredentialProjection>>? _roster;
  @override
  void initState() {
    super.initState();
    _refreshNames();
  }

  void _refreshNames() {
    _roster =
        widget.loadCashiers == null ? null : Future.sync(widget.loadCashiers!);
  }

  @override
  void dispose() {
    _cashierId.dispose();
    _pin.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final cashierId =
        _manual || !_namesAvailable ? _cashierId.text.trim() : _namedId ?? '';
    if (_busy) return;
    if (cashierId.isEmpty || _pin.text.isEmpty) {
      _pin.clear();
      setState(() =>
          _error = 'Choose a cashier or enter an ID, then enter your PIN.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.onLogin(cashierId, _pin.text);
      if (!mounted) return;
      _pin.clear();
      if (result.status == CashierLoginStatus.invalidPin) {
        setState(() => _error = 'Incorrect PIN');
      } else if (result.status == CashierLoginStatus.cooldown) {
        setState(() => _error = 'Too many attempts. Try again shortly.');
      } else {
        widget.onResult(cashierId, result);
      }
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) {
        _pin.clear();
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: sariSupplyTaskAppBar(context, title: 'Cashier sign in'),
        body: SariSupplyPageContent(
            maxWidth: 440,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SariSupplyBrand(role: 'POS'),
                  const SizedBox(height: 24),
                  FutureBuilder<List<CashierCredentialProjection>>(
                      future: _roster,
                      builder: (context, snapshot) {
                        final cashiers = snapshot.data ?? [];
                        _namesAvailable = cashiers.isNotEmpty;
                        final loading = _roster != null &&
                            snapshot.connectionState != ConnectionState.done;
                        return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (!_manual && loading) ...[
                                const LinearProgressIndicator(),
                                const SizedBox(height: 12),
                                const Text('Loading cashier names…'),
                              ],
                              if (snapshot.hasError)
                                SariSupplyStatus(
                                    message:
                                        'Cashier names are unavailable. Enter your cashier ID or retry.',
                                    actions: [
                                      TextButton(
                                          onPressed: _busy
                                              ? null
                                              : () => setState(_refreshNames),
                                          child: const Text('Retry names'))
                                    ]),
                              if (_manual || (!loading && cashiers.isEmpty))
                                TextField(
                                    controller: _cashierId,
                                    enabled: !_busy,
                                    textInputAction: TextInputAction.next,
                                    onSubmitted: (_) =>
                                        _pinFocus.requestFocus(),
                                    decoration: const InputDecoration(
                                        labelText: 'Cashier ID')),
                              if (!_manual && !loading && cashiers.isNotEmpty)
                                DropdownButtonFormField<String>(
                                    key: ValueKey('cashier-$_namedId'),
                                    initialValue: cashiers
                                            .any((c) => c.cashierId == _namedId)
                                        ? _namedId
                                        : null,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Cashier'),
                                    items: cashiers
                                        .map((c) => DropdownMenuItem(
                                            value: c.cashierId,
                                            child: Text(
                                                '${c.displayName} · ${c.employeeCode}',
                                                overflow:
                                                    TextOverflow.ellipsis)))
                                        .toList(),
                                    onChanged: _busy
                                        ? null
                                        : (value) {
                                            setState(() {
                                              _namedId = value;
                                            });
                                            _pinFocus.requestFocus();
                                          }),
                              if (_roster != null &&
                                  (cashiers.isNotEmpty || loading))
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                        onPressed: _busy
                                            ? null
                                            : () => setState(() {
                                                  _manual = !_manual;
                                                  _pin.clear();
                                                }),
                                        child: Text(_manual
                                            ? 'Choose cashier name'
                                            : 'Use cashier ID'))),
                            ]);
                      }),
                  const SizedBox(height: 16),
                  TextField(
                      controller: _pin,
                      focusNode: _pinFocus,
                      enabled: !_busy,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'PIN'),
                      onSubmitted: (_) => _login()),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    SariSupplyStatus(message: _error!, error: true),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                      onPressed: _busy ? null : _login,
                      child: Text(_busy ? 'Checking…' : 'Sign in')),
                  if (widget.onManage != null) ...[
                    const SizedBox(height: 12),
                    TextButton(
                        onPressed: _busy ? null : widget.onManage,
                        child: const Text('Manage store')),
                  ],
                ])),
      );
}
