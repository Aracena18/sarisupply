import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';
import 'checkout_controller.dart';

class CustomerCreditScreen extends StatefulWidget {
  const CustomerCreditScreen({super.key, required this.controller});

  final CheckoutController controller;

  @override
  State<CustomerCreditScreen> createState() => _CustomerCreditScreenState();
}

class _CustomerCreditScreenState extends State<CustomerCreditScreen> {
  List<CustomerAccount> _customers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _loading = true);
    try {
      final controller = widget.controller;
      if (controller.checkoutGateway is CreditGateway &&
          await controller.revalidate()) {
        try {
          await controller.sync();
          final grant =
              await controller.grantResolver(controller.authorization!.scope);
          if (grant != null &&
              (await controller.store.checkout.pendingIntents()).isEmpty) {
            final remote = await (controller.checkoutGateway as CreditGateway)
                .customers(grant);
            for (final customer in remote) {
              await controller.store.checkout.saveCustomer(customer);
            }
          }
        } catch (_) {/* Retain local customer balances while offline. */}
      }
      final list = await controller.store.checkout.listCustomers();
      if (mounted) {
        setState(() {
          _customers = list;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = operationErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addCustomer() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final limitCtrl = TextEditingController(text: '1000.00');
    final formKey = GlobalKey<FormState>();

    final saved = await showSariSupplyForm<bool>(
      context: context,
      builder: (ctx) => SariSupplyFormSurface(
        title: 'Add Credit Customer',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
            },
            child: const Text('Save Customer'),
          ),
        ],
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Customer Name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a phone' : null,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: limitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Credit Limit',
                  prefixText: '₱ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  try {
                    final centavos = parsePhpCentavos(v ?? '');
                    if (centavos <= 0) return 'Limit must be positive';
                    return null;
                  } catch (_) {
                    return 'Enter a valid amount';
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true) return;
    try {
      final id = const Uuid().v4();
      final limitCentavos = parsePhpCentavos(limitCtrl.text.trim());
      final customer = CustomerAccount(
        id: id,
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        creditLimitCentavos: limitCentavos,
        balanceCentavos: 0,
        active: true,
      );
      final identity = FirebaseGoogleAuthRepository.forDefaultApp();
      try {
        await identity.signInWithGoogle();
        final saved = await CustomerFunctions.forHuman()
            .save(widget.controller.store.merchantId, customer);
        await widget.controller.store.checkout.saveCustomer(saved);
      } finally {
        await identity.signOut();
      }

      await _loadCustomers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer registered')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(operationErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _recordRepayment(CustomerAccount customer) async {
    final amountCtrl = TextEditingController(
      text: (customer.balanceCentavos / 100).toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();

    final confirmed = await showSariSupplyForm<bool>(
      context: context,
      builder: (ctx) => SariSupplyFormSurface(
        title: 'Repayment: ${customer.name}',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.of(ctx).pop(true);
            },
            child: const Text('Record Repayment'),
          ),
        ],
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Current Debt: ${formatPhp(customer.balanceCentavos)}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Repayment Amount',
                  prefixText: '₱ ',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  try {
                    final centavos = parsePhpCentavos(v ?? '');
                    if (centavos <= 0) return 'Enter a positive amount';
                    if (centavos > customer.balanceCentavos) {
                      return 'Cannot exceed total debt';
                    }
                    return null;
                  } catch (_) {
                    return 'Invalid amount';
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    try {
      if (!await widget.controller.revalidate() ||
          widget.controller.shift == null ||
          !widget.controller.ownsShift) {
        throw StateError('Open your cashier shift first');
      }
      final amountCentavos = parsePhpCentavos(amountCtrl.text.trim());
      final repayment = DebtRepayment(
        id: const Uuid().v4(),
        customerId: customer.id,
        amountCentavos: amountCentavos,
        tenderKind: 'cash',
        occurredAt: DateTime.now(),
        shiftId: widget.controller.shift!.id,
        cashierId: widget.controller.session.cashierId,
      );
      await widget.controller.store.checkout.recordDebtRepayment(repayment,
          scope: widget.controller.authorization!.scope);
      widget.controller.shift = await widget.controller.store.checkout
          .activeShift(widget.controller.session.deviceId);
      widget.controller.changed();
      await _loadCustomers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Recorded repayment of ${formatPhp(amountCentavos)} for ${customer.name}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(operationErrorMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sariSupplyTaskAppBar(
        context,
        title: 'Customer Credit (Utang)',
        actions: [
          IconButton(
            tooltip: 'Add customer',
            icon: const Icon(Icons.person_add_outlined),
            onPressed: _addCustomer,
          ),
        ],
      ),
      body: SariSupplyPageContent(
        maxWidth: 600,
        child: RefreshIndicator(
          onRefresh: _loadCustomers,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null) ...[
                  SariSupplyStatus(message: _error!, error: true),
                  const SizedBox(height: 12),
                ],
                if (_loading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_customers.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No credit customers registered yet'),
                    ),
                  )
                else
                  ..._customers.map((c) {
                    final available = c.creditLimitCentavos - c.balanceCentavos;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    c.name,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                if (c.balanceCentavos > 0)
                                  Chip(
                                    label: Text(
                                      'OWES ${formatPhp(c.balanceCentavos)}',
                                      style: TextStyle(
                                        color: SariSupplyColors.error,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  )
                                else
                                  const Chip(
                                    label: Text('PAID UP'),
                                    visualDensity: VisualDensity.compact,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Phone: ${c.phone}'),
                            Text(
                              'Credit limit: ${formatPhp(c.creditLimitCentavos)} · Available: ${formatPhp(available)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (c.balanceCentavos > 0) ...[
                              const SizedBox(height: 8),
                              FilledButton.tonal(
                                onPressed: () => _recordRepayment(c),
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(40),
                                ),
                                child: const Text('Record Repayment'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
