import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';

import 'signature_pad.dart';

class DeliverySignatureScreen extends StatefulWidget {
  const DeliverySignatureScreen({
    super.key,
    required this.run,
    required this.stop,
    required this.store,
    this.deliveryGateway,
    required this.merchantId,
  });

  final DeliveryRun run;
  final DeliveryStop stop;
  final InventoryStore store;
  final DeliveryGateway? deliveryGateway;
  final String merchantId;

  @override
  State<DeliverySignatureScreen> createState() =>
      _DeliverySignatureScreenState();
}

class _DeliverySignatureScreenState extends State<DeliverySignatureScreen> {
  final _formKey = GlobalKey<FormState>();
  final _recipientNameController = TextEditingController();
  final _cashController = TextEditingController();
  final _notesController = TextEditingController();

  String _recipientRole = 'Store Owner';
  String? _signatureSvg;
  late List<_ItemEntry> _itemEntries;
  bool _isSaving = false;

  final _returnReasons = const [
    'Damaged goods',
    'Wrong item',
    'Expired/near-expiry',
    'Store rejected',
    'Excess quantity',
  ];

  @override
  void initState() {
    super.initState();
    _itemEntries = widget.stop.items.map((i) {
      final initialDelivered = i.quantityDelivered > 0
          ? i.quantityDelivered
          : (i.quantityReturned > 0 ? 0 : i.quantityOrdered);
      final initialReturned = i.quantityReturned;
      return _ItemEntry(
        item: i,
        quantityDelivered: initialDelivered,
        quantityReturned: initialReturned,
        returnReason: i.returnReason ?? _returnReasons.first,
      );
    }).toList();
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _cashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;
    if (_signatureSvg == null || _signatureSvg!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please capture recipient signature before completing delivery.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final proofId = const Uuid().v4();
      final cashText = _cashController.text.trim();
      final cashCollectedCentavos =
          cashText.isEmpty ? 0 : parsePhpCentavos(cashText);

      final updatedStopItems = _itemEntries.map((e) {
        return e.item.copyWith(
          quantityDelivered: e.quantityDelivered,
          quantityReturned: e.quantityReturned,
          returnReason: e.quantityReturned > 0 ? e.returnReason : null,
        );
      }).toList();

      final proof = DeliveryProof(
        id: proofId,
        stopId: widget.stop.id,
        recipientName: _recipientNameController.text.trim(),
        recipientRole: _recipientRole,
        signatureSvg: _signatureSvg!,
        deliveredAt: now,
        cashCollectedCentavos: cashCollectedCentavos,
        driverNotes: _notesController.text.trim(),
        offlineCreated: true,
      );

      // Save locally in SQLite database
      await widget.store.recordDeliveryProof(
        runId: widget.run.id,
        stopId: widget.stop.id,
        proof: proof,
        items: updatedStopItems,
      );

      // Attempt online backend sync if gateway is connected
      if (widget.deliveryGateway != null) {
        try {
          await widget.deliveryGateway!.submitStopProof(
            merchantId: widget.merchantId,
            runId: widget.run.id,
            stopId: widget.stop.id,
            proof: proof,
            items: updatedStopItems,
          );
          await widget.store.acknowledgeDelivery(proof.id);
        } catch (_) {
          // Safely preserved locally in SQLite
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Saved locally. Synchronization may still be pending.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(operationErrorMessage(e,
                fallback: 'Check delivered quantities and payment details.')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: sariSupplyTaskAppBar(
        context,
        title: 'Complete Stop #${widget.stop.sequence}',
      ),
      body: SariSupplyPageContent(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Destination summary header
              Card(
                elevation: 0,
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.stop.destinationName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.stop.destinationAddress,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Item delivery & return steppers
              Text(
                'Delivered & Returned Quantities',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              ..._itemEntries
                  .map((entry) => _buildItemStepperCard(entry, theme)),

              const SizedBox(height: 16),

              // COD Cash Collection
              Text(
                'COD Cash Collection',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cashController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Cash Collected (PHP)',
                  hintText: '0.00',
                  prefixText: '₱ ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Recipient Details
              Text(
                'Recipient Information',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _recipientNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Recipient Name *',
                  hintText: 'e.g. Maria Santos',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Recipient name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                initialValue: _recipientRole,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Recipient Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'Store Owner', child: Text('Store Owner')),
                  DropdownMenuItem(
                      value: 'Store Manager', child: Text('Store Manager')),
                  DropdownMenuItem(value: 'Cashier', child: Text('Cashier')),
                  DropdownMenuItem(
                      value: 'Staff/Relative', child: Text('Staff/Relative')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _recipientRole = val);
                },
              ),
              const SizedBox(height: 16),

              // Signature Pad
              SignaturePad(
                onChanged: (svg) => setState(() => _signatureSvg = svg),
              ),
              const SizedBox(height: 16),

              // Driver notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Driver Notes (Optional)',
                  hintText: 'Any delivery or return notes...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              FilledButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(
                  _isSaving
                      ? 'Saving Proof...'
                      : 'Confirm Delivery & Complete Stop',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItemStepperCard(_ItemEntry entry, ThemeData theme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    entry.item.productName,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Ordered: ${entry.item.quantityOrdered} ${entry.item.unitName.isNotEmpty ? entry.item.unitName : 'units'}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildCounter(
                    label: 'Delivered',
                    value: entry.quantityDelivered,
                    color: Colors.green.shade700,
                    onDecrement: () {
                      if (entry.quantityDelivered > 0) {
                        setState(() {
                          entry.quantityDelivered--;
                          entry.quantityReturned = entry.item.quantityOrdered -
                              entry.quantityDelivered;
                        });
                      }
                    },
                    onIncrement: () {
                      if (entry.quantityDelivered <
                          entry.item.quantityOrdered) {
                        setState(() {
                          entry.quantityDelivered++;
                          entry.quantityReturned = entry.item.quantityOrdered -
                              entry.quantityDelivered;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildCounter(
                    label: 'Returned',
                    value: entry.quantityReturned,
                    color: Colors.orange.shade800,
                    onDecrement: () {
                      if (entry.quantityReturned > 0) {
                        setState(() {
                          entry.quantityReturned--;
                          entry.quantityDelivered = entry.item.quantityOrdered -
                              entry.quantityReturned;
                        });
                      }
                    },
                    onIncrement: () {
                      if (entry.quantityReturned < entry.item.quantityOrdered) {
                        setState(() {
                          entry.quantityReturned++;
                          entry.quantityDelivered = entry.item.quantityOrdered -
                              entry.quantityReturned;
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            if (entry.quantityReturned > 0) ...[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: entry.returnReason,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Return Reason',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: _returnReasons
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => entry.returnReason = val);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCounter({
    required String label,
    required int value,
    required Color color,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                onPressed: onDecrement,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$value',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                onPressed: onIncrement,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ItemEntry {
  _ItemEntry({
    required this.item,
    required this.quantityDelivered,
    required this.quantityReturned,
    required this.returnReason,
  });

  final DeliveryStopItem item;
  int quantityDelivered;
  int quantityReturned;
  String returnReason;
}
