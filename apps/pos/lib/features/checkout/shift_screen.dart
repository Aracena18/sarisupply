import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'checkout_controller.dart';
import 'owner_reversal_approval.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

class ShiftScreen extends StatefulWidget {
  const ShiftScreen({super.key, required this.controller});
  final CheckoutController controller;
  @override
  State<ShiftScreen> createState() => _ShiftScreenState();
}

class _ShiftScreenState extends State<ShiftScreen> {
  final _amount = TextEditingController(text: '0.00'),
      _reason = TextEditingController();
  String _kind = 'openShift';
  String? _error;
  bool _approving = false;
  List<CheckoutIntent> _pending = [];
  CheckoutController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    _kind = c.shift == null ? 'openShift' : 'summary';
    c.addListener(_changed);
    _loadPending();
  }

  Future<void> _loadPending() async {
    final rows = await c.store.checkout.pendingIntents();
    if (mounted) setState(() => _pending = rows);
  }

  Future<void> _approvePending(CheckoutIntent intent) async {
    if (_approving) return;
    setState(() => _approving = true);
    try {
      final sale = await c.store.checkout
          .sale(intent.payload['originalSaleId'] as String);
      if (sale == null || !mounted) return;
      if (!await requestOwnerReversalApproval(
          context: context, controller: c, intent: intent, sale: sale)) {
        return;
      }
      await c.store.checkout.retryOwnerApprovedReversal(intent.id);
      await c.sync();
      await _loadPending();
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  bool get _valid {
    if (_approving ||
        c.busy ||
        !c.allowed ||
        (c.shift != null && !c.ownsShift)) {
      return false;
    }
    try {
      final n = parsePhpCentavos(_amount.text);
      if (_kind == 'cashIn' || _kind == 'cashOut') {
        return n > 0 && _reason.text.trim().isNotEmpty;
      }
      if (_kind == 'closeShift') {
        if (c.shift == null) return false;
        return c.draft?.lines.isNotEmpty != true &&
            (n == c.shift!.expectedCashCentavos ||
                _reason.text.trim().isNotEmpty);
      }
      return _kind == 'openShift';
    } on Object {
      return false;
    }
  }

  void _select(String kind) {
    setState(() {
      _kind = kind;
      _amount.text = '';
      _reason.clear();
      _error = null;
    });
  }

  Future<void> _save() async {
    try {
      await c.mutation(
          _kind, parsePhpCentavos(_amount.text), _reason.text.trim());
      if (!mounted) return;
      if (_kind == 'openShift' || _kind == 'closeShift') {
        Navigator.of(context).pop();
      } else {
        setState(() => _kind = 'summary');
        await _loadPending();
      }
    } on Object {
      if (mounted) {
        setState(() => _error = 'Check the amount, reason and cashier access');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int? count;
    try {
      count = parsePhpCentavos(_amount.text);
    } on Object {/* Incomplete amount. */}
    final current = c.shift;
    final label = _kind == 'openShift'
        ? 'Opening float'
        : _kind == 'closeShift'
            ? 'Counted cash'
            : 'Amount';
    return Scaffold(
        appBar: sariSupplyTaskAppBar(context, title: 'Shift'),
        body: SariSupplyPageContent(
            maxWidth: 600,
            child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  if (current != null)
                    Text(
                        'Expected cash ${formatPhp(current.expectedCashCentavos)}',
                        style: Theme.of(context).textTheme.titleLarge),
                  if (current != null && !c.ownsShift)
                    const Text(
                        'The current cashier must sign in to close this shift'),
                  if (_kind == 'summary') ...[
                    const SizedBox(height: 16),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton(
                          onPressed:
                              c.ownsShift ? () => _select('cashIn') : null,
                          child: const Text('Cash in')),
                      OutlinedButton(
                          onPressed:
                              c.ownsShift ? () => _select('cashOut') : null,
                          child: const Text('Cash out')),
                      OutlinedButton(
                          onPressed:
                              c.ownsShift ? () => _select('closeShift') : null,
                          child: const Text('Close shift')),
                    ]),
                  ] else ...[
                    const SizedBox(height: 16),
                    TextField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            InputDecoration(labelText: label, prefixText: '₱ '),
                        onChanged: (_) => setState(() {})),
                    if (_kind != 'openShift') ...[
                      const SizedBox(height: 16),
                      TextField(
                          controller: _reason,
                          maxLength: 160,
                          decoration:
                              const InputDecoration(labelText: 'Reason'),
                          onChanged: (_) => setState(() {}))
                    ],
                    if (_kind == 'closeShift' &&
                        count != null &&
                        current != null)
                      Text(
                          'Difference ${formatPhp(count - current.expectedCashCentavos)}'),
                    if (_kind == 'closeShift' &&
                        c.draft?.lines.isNotEmpty == true)
                      const Text('Finish or discard the cart before closing'),
                    const SizedBox(height: 24),
                    FilledButton(
                        onPressed: _valid ? _save : null,
                        child: Text(c.busy
                            ? 'Saving…'
                            : _kind == 'openShift'
                                ? 'Save shift'
                                : _kind == 'closeShift'
                                    ? 'Save close'
                                    : 'Save movement')),
                  ],
                  if (c.error != null) Text(c.error!),
                  if (_error != null) Text(_error!),
                  if (_pending.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text('Sync pending'),
                    for (final op in _pending)
                      ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(op.kind == 'sale'
                              ? 'Receipt ${op.id}'
                              : {
                                    'openShift': 'Opening float',
                                    'cashIn': 'Cash in',
                                    'cashOut': 'Cash out',
                                    'closeShift': 'Shift close',
                                    'refund': 'Refund',
                                    'voidSale': 'Void',
                                    'debtRepayment': 'Debt repayment'
                                  }[op.kind] ??
                                  op.kind),
                          subtitle: Text(op.status == 'pending'
                              ? 'Waiting to sync'
                              : op.message ?? 'Needs review'),
                          trailing: ['refund', 'voidSale'].contains(op.kind) &&
                                  op.message ==
                                      'Owner approval required for this exact refund or void'
                              ? TextButton(
                                  onPressed: _approving
                                      ? null
                                      : () => _approvePending(op),
                                  child: const Text('Owner review'))
                              : null)
                  ],
                ]))));
  }
}
