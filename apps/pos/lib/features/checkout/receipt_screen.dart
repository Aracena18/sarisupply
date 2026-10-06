import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sarisupply_core/sarisupply_core.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'checkout_controller.dart';
import 'refund_screen.dart';
import '../reports/presentation/receipt_preview_dialog.dart';

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen(
      {super.key, required this.controller, required this.sale});
  final CheckoutController controller;
  final CheckoutSale sale;
  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  String _status = 'Saved locally · Sync pending';
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final c = widget.controller, s = widget.sale;
      if (s.scope.deviceId == c.session.deviceId &&
          s.scope.cashierId == c.session.cashierId) {
        try {
          await c.store.checkout
              .markReceiptSeen(s.scope.deviceId, s.scope.cashierId, s.id);
          if (c.recovery?.id == s.id) c.recovery = null;
        } on Object {
          // A presentation write cannot invalidate the committed payment.
          // Keep recovery pending so reopening can show this same receipt.
        }
      }
      if (!mounted) return;
      await _refresh();
      if (mounted) unawaited(c.sync());
    });
  }

  Future<void> _refresh() async {
    try {
      final op =
          await widget.controller.store.checkout.operation(widget.sale.id);
      final status = op?.status;
      if (mounted) {
        setState(() => _status = ['blocked', 'conflict'].contains(status)
            ? 'Saved locally · Needs review'
            : status == 'accepted'
                ? 'Synced'
                : 'Saved locally · Sync pending');
      }
    } on Object {/* Receipt stays readable if its status cannot be loaded. */}
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sale;
    return Scaffold(
        appBar: sariSupplyTaskAppBar(context, title: 'Receipt'),
        body: SariSupplyPageContent(
            maxWidth: 600,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(s.merchantName,
                      style: Theme.of(context).textTheme.titleLarge),
                  Text(s.branchName),
                  const SizedBox(height: 8),
                  SelectableText('Receipt ${s.id}'),
                  Text(s.occurredAt.toLocal().toString().split('.').first),
                  Text('Cashier ${s.scope.cashierId}'),
                  const SizedBox(height: 16),
                  for (final l in s.lines)
                    Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.name),
                              Text(
                                  '${l.quantity} × ${l.unit} · ${formatPhp(l.priceCentavos)}'),
                              Text(formatPhp(l.totalCentavos)),
                            ])),
                  const Divider(),
                  Text('Total ${formatPhp(s.totalCentavos)}',
                      style: Theme.of(context).textTheme.titleLarge),
                  if (s.tender.kind == 'cash') ...[
                    Text('Cash ${formatPhp(s.tender.receivedCentavos)}'),
                    Text('Change ${formatPhp(s.changeCentavos)}')
                  ] else if (s.tender.kind == 'credit') ...[
                    const Text('Credit (Utang)'),
                    Text('Customer: ${s.tender.reference}')
                  ] else ...[
                    const Text('QR · Checked manually'),
                    Text('Reference ${s.tender.reference}')
                  ],
                  const SizedBox(height: 16),
                  Text(_status),
                  const SizedBox(height: 24),
                  FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('New sale')),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Print / Preview Receipt'),
                      onPressed: () {
                        final doc = ReceiptFormatter.formatCheckoutSale(
                          merchantName: s.merchantName,
                          branchName: s.branchName,
                          sale: s,
                          cashierName: s.scope.cashierId,
                        );
                        showDialog<void>(
                          context: context,
                          builder: (_) => ReceiptPreviewDialog(
                            document: doc,
                            title: 'Customer Receipt',
                          ),
                        );
                      }),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => RefundScreen(
                                  controller: widget.controller,
                                  sale: widget.sale))),
                      child: const Text('Refund or void sale')),
                ])));
  }
}
