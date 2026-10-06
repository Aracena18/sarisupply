import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';
import 'checkout_controller.dart';
import 'owner_reversal_approval.dart';

class RefundScreen extends StatefulWidget {
  const RefundScreen({
    super.key,
    required this.controller,
    required this.sale,
  });

  final CheckoutController controller;
  final CheckoutSale sale;

  @override
  State<RefundScreen> createState() => _RefundScreenState();
}

class _RefundScreenState extends State<RefundScreen> {
  final Map<int, int> _refundQuantities = {};
  final _reasonController = TextEditingController();
  String _tenderKind = 'cash';
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < widget.sale.lines.length; i++) {
      _refundQuantities[i] = 0;
    }
    _tenderKind = widget.sale.tender.kind;
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  int get _totalRefundCentavos {
    var total = 0;
    for (var i = 0; i < widget.sale.lines.length; i++) {
      final line = widget.sale.lines[i];
      final qty = _refundQuantities[i] ?? 0;
      total += qty * line.priceCentavos;
    }
    return total;
  }

  Future<void> _processRefund() async {
    if (_submitting) return;
    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Please provide a reason for the refund');
      return;
    }

    final refundLines = <RefundLine>[];
    for (var i = 0; i < widget.sale.lines.length; i++) {
      final line = widget.sale.lines[i];
      final qty = _refundQuantities[i] ?? 0;
      if (qty > 0) {
        refundLines.add(RefundLine(
          productId: line.productId,
          sku: line.sku,
          name: line.name,
          unit: line.unit,
          factor: line.factor,
          priceCentavos: line.priceCentavos,
          quantity: qty,
          refundCentavos: qty * line.priceCentavos,
        ));
      }
    }

    if (refundLines.isEmpty) {
      setState(() => _error = 'Select at least one item to refund');
      return;
    }

    final totalCentavos = _totalRefundCentavos;
    if (totalCentavos > widget.sale.totalCentavos) {
      setState(() => _error = 'Refund amount exceeds original receipt total');
      return;
    }

    if (!await widget.controller.revalidate() ||
        !mounted ||
        !widget.controller.ownsShift) {
      if (mounted) {
        setState(() => _error = 'Sign in to your open shift to continue');
      }
      return;
    }
    final shift = widget.controller.shift;
    final auth = widget.controller.authorization;
    if (shift == null || auth == null) {
      setState(() => _error = 'Active shift and authorization required');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final refundId = const Uuid().v4();
    final intent = RefundIntent(
      id: refundId,
      originalSaleId: widget.sale.id,
      shiftId: shift.id,
      scope: auth.scope,
      ordinal: shift.lastOrdinal + 1,
      lines: refundLines,
      tenderKind: _tenderKind,
      reason: reason,
      authorizedByCashierId: auth.scope.cashierId,
      occurredAt: DateTime.now(),
    );

    try {
      if (!await requestOwnerReversalApproval(
          context: context,
          controller: widget.controller,
          intent: intent.toCheckoutIntent(),
          sale: widget.sale)) {
        if (mounted) setState(() => _submitting = false);
        return;
      }
      await widget.controller.store.checkout.recordRefund(intent);
      widget.controller.shift = await widget.controller.store.checkout
          .activeShift(widget.controller.session.deviceId);
      widget.controller.changed();
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Refund ${formatPhp(totalCentavos)} saved locally · Sync pending'),
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = operationErrorMessage(e);
        });
      }
    }
  }

  Future<void> _confirmVoid() async {
    if (_submitting) return;
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Void entire sale?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Voiding will cancel this receipt, return all stock, and reverse the expected cash for the shift. This cannot be undone.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason for voiding',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Void Sale'),
          ),
        ],
      ),
    );

    final reason = reasonController.text.trim();
    reasonController.dispose();
    if (confirmed != true || !mounted) return;
    if (reason.isEmpty) {
      if (mounted) setState(() => _error = 'A reason is required to void');
      return;
    }

    if (!await widget.controller.revalidate() ||
        !mounted ||
        !widget.controller.ownsShift) {
      if (mounted) {
        setState(() => _error = 'Sign in to your open shift to continue');
      }
      return;
    }
    final shift = widget.controller.shift;
    final auth = widget.controller.authorization;
    if (shift == null || auth == null) {
      if (mounted) setState(() => _error = 'Active shift required');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final voidId = const Uuid().v4();
    final voidIntent = VoidIntent(
      id: voidId,
      originalSaleId: widget.sale.id,
      shiftId: shift.id,
      scope: auth.scope,
      ordinal: shift.lastOrdinal + 1,
      reason: reason,
      authorizedByCashierId: auth.scope.cashierId,
      voidCentavos: widget.sale.totalCentavos,
      tenderKind: widget.sale.tender.kind,
      occurredAt: DateTime.now(),
    );

    try {
      if (!await requestOwnerReversalApproval(
          context: context,
          controller: widget.controller,
          intent: voidIntent.toCheckoutIntent(),
          sale: widget.sale)) {
        if (mounted) setState(() => _submitting = false);
        return;
      }
      await widget.controller.store.checkout.voidSale(voidIntent);
      widget.controller.shift = await widget.controller.store.checkout
          .activeShift(widget.controller.session.deviceId);
      widget.controller.changed();
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Void saved locally · Sync pending')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = operationErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sale;
    final totalRefund = _totalRefundCentavos;

    return Scaffold(
      appBar: sariSupplyTaskAppBar(context, title: 'Refund or Void'),
      body: SariSupplyPageContent(
        maxWidth: 600,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Original Receipt',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text('Receipt ID: ${s.id}'),
                      Text(
                          'Date: ${s.occurredAt.toLocal().toString().split('.').first}'),
                      Text(
                          'Total: ${formatPhp(s.totalCentavos)} (${s.tender.kind.toUpperCase()})'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Select Items to Refund',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              for (var i = 0; i < s.lines.length; i++) ...[
                Builder(builder: (context) {
                  final line = s.lines[i];
                  final qty = _refundQuantities[i] ?? 0;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(line.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                              '${formatPhp(line.priceCentavos)} / ${line.unit} · Bought: ${line.quantity}'),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Refund quantity: $qty'),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    onPressed: qty > 0
                                        ? () => setState(() =>
                                            _refundQuantities[i] = qty - 1)
                                        : null,
                                  ),
                                  Text(
                                    '$qty',
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    onPressed: qty < line.quantity
                                        ? () => setState(() =>
                                            _refundQuantities[i] = qty + 1)
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
              const SizedBox(height: 12),
              Text(
                'Total Refund: ${formatPhp(totalRefund)}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason for refund',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLength: 160,
              ),
              const SizedBox(height: 8),
              Text(
                'Refund Tender',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(s.tender.kind == 'credit'
                  ? 'Customer credit balance'
                  : s.tender.kind == 'cash'
                      ? 'Cash'
                      : 'QR / Digital'),
              if (_error != null) ...[
                const SizedBox(height: 12),
                SariSupplyStatus(message: _error!, error: true),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed:
                    _submitting || totalRefund == 0 ? null : _processRefund,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(_submitting
                    ? 'Processing…'
                    : 'Process Refund (${formatPhp(totalRefund)})'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed:
                    _submitting || widget.controller.shift?.id != s.shiftId
                        ? null
                        : _confirmVoid,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  minimumSize: const Size.fromHeight(48),
                ),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Void Entire Sale'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
