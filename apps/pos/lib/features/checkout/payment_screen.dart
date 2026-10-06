import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'checkout_controller.dart';
import 'receipt_screen.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key, required this.controller});
  final CheckoutController controller;
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _cash, _reference;
  String? _error;
  List<CustomerAccount> _customers = [];
  bool _loadingCustomers = true;
  CheckoutController get c => widget.controller;
  @override
  void initState() {
    super.initState();
    _cash = TextEditingController(text: c.draft!.received);
    _reference = TextEditingController(text: c.draft!.qrReference);
    WidgetsBinding.instance.addObserver(this);
    c.addListener(_changed);
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    try {
      final customers = await c.store.checkout.listCustomers();
      if (mounted) {
        setState(() {
          _customers = customers.where((customer) => customer.active).toList();
          _loadingCustomers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingCustomers = false;
          _error =
              'Customer accounts could not be loaded. Reopen payment to retry.';
        });
      }
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) c.revalidate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_changed);
    _cash.dispose();
    _reference.dispose();
    super.dispose();
  }

  bool get _valid {
    final d = c.draft;
    if (d == null || !c.allowed || c.busy) return false;
    if (d.frozenSale != null) return true;
    try {
      final tender = d.tenderKind == 'cash'
          ? Tender.cash(parsePhpCentavos(d.received))
          : d.tenderKind == 'credit'
              ? Tender.credit(d.qrReference)
              : Tender.qr(d.qrReference, confirmed: d.qrConfirmed);
      tender.validate(d.totalCentavos);
      return true;
    } on Object {
      return false;
    }
  }

  void _edit(
      {String? received, String? reference, String? kind, bool? confirmed}) {
    if (c.busy ||
        c.draft?.frozenSale != null ||
        (c.draft?.paymentAttemptId.isNotEmpty ?? false)) {
      return;
    }
    c.updateDraft(c.draft!.copyWith(
        received: received,
        qrReference: reference,
        tenderKind: kind,
        qrConfirmed: confirmed));
  }

  Future<void> _save() async {
    if (c.busy) return;
    try {
      final receipt = await c.complete();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
          builder: (_) => ReceiptScreen(controller: c, sale: receipt)));
    } on Object {
      if (mounted) {
        setState(() => _error = (c.draft?.frozenSale != null ||
                (c.draft?.paymentAttemptId.isNotEmpty ?? false))
            ? 'Payment not finished. Retry this saved payment.'
            : 'Check payment details or review prices in the cart.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = c.draft;
    if (d == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final frozen = d.frozenSale != null || d.paymentAttemptId.isNotEmpty;
    int? received;
    try {
      received = parsePhpCentavos(d.received);
    } on Object {/* Incomplete decimal input. */}
    return PopScope(
        canPop: !c.busy,
        child: Scaffold(
            appBar: sariSupplyTaskAppBar(context, title: 'Payment'),
            body: SariSupplyPageContent(
                maxWidth: 600,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Total ${formatPhp(d.totalCentavos)}',
                          style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      if (frozen)
                        const Text(
                            'Finish the saved payment. Keep the same tender.'),
                      if (!frozen)
                        Wrap(spacing: 8, children: [
                          ChoiceChip(
                              label: const Text('Cash'),
                              selected: d.tenderKind == 'cash',
                              onSelected:
                                  c.busy ? null : (_) => _edit(kind: 'cash')),
                          ChoiceChip(
                              label: const Text('QR'),
                              selected: d.tenderKind == 'qr',
                              onSelected: c.busy || d.totalCentavos == 0
                                  ? null
                                  : (_) => _edit(kind: 'qr')),
                          ChoiceChip(
                              label: const Text('Credit (Utang)'),
                              selected: d.tenderKind == 'credit',
                              onSelected: c.busy || d.totalCentavos == 0
                                  ? null
                                  : (_) => _edit(kind: 'credit')),
                        ]),
                      const SizedBox(height: 16),
                      if (d.tenderKind == 'cash') ...[
                        TextField(
                            controller: _cash,
                            readOnly: frozen || c.busy || !c.allowed,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Cash received', prefixText: '₱ '),
                            onChanged: (v) => _edit(received: v)),
                        const SizedBox(height: 16),
                        if (received != null && received >= d.totalCentavos)
                          Text(
                              'Change ${formatPhp(received - d.totalCentavos)}',
                              style: Theme.of(context).textTheme.titleLarge),
                        if (received != null && received < d.totalCentavos)
                          const Text('Cash received is short'),
                      ] else if (d.tenderKind == 'credit') ...[
                        if (_loadingCustomers) const LinearProgressIndicator(),
                        if (frozen) Text('Customer: ${d.qrReference}'),
                        if (!frozen)
                          DropdownButtonFormField<String>(
                            initialValue: _customers.any(
                                    (customer) => customer.id == d.qrReference)
                                ? d.qrReference
                                : null,
                            isExpanded: true,
                            decoration: const InputDecoration(
                                labelText: 'Customer account'),
                            items: _customers
                                .map((customer) => DropdownMenuItem(
                                    value: customer.id,
                                    child: Text(customer.name)))
                                .toList(),
                            onChanged: c.busy || !c.allowed
                                ? null
                                : (value) => _edit(reference: value),
                          ),
                        if (!_loadingCustomers && _customers.isEmpty)
                          const Text(
                              'Add a customer in Customer credit before charging.'),
                      ] else ...[
                        TextField(
                            controller: _reference,
                            readOnly: frozen || c.busy || !c.allowed,
                            maxLength: 80,
                            decoration: const InputDecoration(
                                labelText: 'Payment reference'),
                            onChanged: (v) => _edit(reference: v)),
                        CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title:
                                const Text('Payment checked in bank or wallet'),
                            value: d.qrConfirmed,
                            onChanged: frozen || c.busy || !c.allowed
                                ? null
                                : (v) => _edit(confirmed: v ?? false)),
                        const Text('QR payment is checked manually'),
                      ],
                      if (c.error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(c.error!,
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.error))),
                      if (_error != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(_error!)),
                      if (d.paymentAttemptId.isNotEmpty && d.frozenSale == null)
                        TextButton(
                            onPressed: c.busy
                                ? null
                                : () async {
                                    try {
                                      await c.cancelCreditReservation();
                                      if (mounted) {
                                        setState(() => _error = null);
                                      }
                                    } catch (_) {
                                      if (mounted) {
                                        setState(() => _error =
                                            'Connect to cancel reserved credit. Saved payment is retained.');
                                      }
                                    }
                                  },
                            child: const Text('Cancel reserved credit online')),
                      const SizedBox(height: 24),
                      FilledButton(
                          onPressed: _valid ? _save : null,
                          child: Text(c.busy
                              ? 'Saving…'
                              : frozen
                                  ? 'Finish saved payment'
                                  : 'Save payment')),
                    ]))));
  }
}
