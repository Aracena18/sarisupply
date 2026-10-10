import 'dart:async';
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
    this.onSyncError,
    required this.merchantId,
  });

  final DeliveryRun run;
  final DeliveryStop stop;
  final InventoryStore store;
  final DeliveryGateway? deliveryGateway;
  final ValueChanged<Object>? onSyncError;
  final String merchantId;

  @override
  State<DeliverySignatureScreen> createState() =>
      _DeliverySignatureScreenState();
}

class _DeliverySignatureScreenState extends State<DeliverySignatureScreen> {
  final _paymentFormKey = GlobalKey<FormState>();
  final _proofFormKey = GlobalKey<FormState>();
  final _recipientNameController = TextEditingController();
  final _cashController = TextEditingController();
  final _notesController = TextEditingController();

  String _recipientRole = 'Store Owner';
  String? _signatureSvg;
  late List<_ItemEntry> _itemEntries;
  int _step = 0;
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

  int get _deliveredValueCentavos => _itemEntries.fold(
        0,
        (sum, entry) =>
            sum + entry.quantityDelivered * entry.item.unitCostCentavos,
      );

  bool get _requiresPayment =>
      widget.stop.paymentMethod != 'qr' && _deliveredValueCentavos > 0;

  String? _cashValidationMessage(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    if (widget.stop.paymentMethod == 'qr') {
      return 'This order uses QR payment. Do not collect cash.';
    }
    try {
      if (parsePhpCentavos(text) > _deliveredValueCentavos) {
        return 'Cannot exceed ${_formatPhp(_deliveredValueCentavos)}';
      }
    } on Object {
      return 'Enter a valid PHP amount';
    }
    return null;
  }

  @override
  void dispose() {
    _recipientNameController.dispose();
    _cashController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving || !_proofFormKey.currentState!.validate()) return;
    final cashError = _cashValidationMessage(_cashController.text);
    if (cashError != null) {
      setState(() => _step = _requiresPayment ? 1 : 0);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(cashError)),
      );
      return;
    }
    if (_signatureSvg == null || _signatureSvg!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please capture recipient signature before completing delivery.'),
          backgroundColor: SariSupplyColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final proofId = const Uuid().v4();
      final cashText = _cashController.text.trim();
      final cashCollectedCentavos = widget.stop.paymentMethod == 'qr'
          ? 0
          : cashText.isEmpty
              ? 0
              : parsePhpCentavos(cashText);

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

      if (widget.deliveryGateway != null) {
        unawaited(_upload(proof, updatedStopItems));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Saved locally. Synchronization may still be pending.'),
            backgroundColor: SariSupplyColors.success,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(operationErrorMessage(e,
                fallback:
                    'Delivery proof could not be saved on this phone. Your entries are still here; try again.')),
            backgroundColor: SariSupplyColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _advance() {
    if (_isSaving) return;
    if (_step == 0) {
      setState(() => _step = _requiresPayment ? 1 : 2);
      return;
    }
    if (_step == 1) {
      if (_paymentFormKey.currentState!.validate()) {
        setState(() => _step = 2);
      }
      return;
    }
    unawaited(_submit());
  }

  Future<void> _upload(
      DeliveryProof proof, List<DeliveryStopItem> items) async {
    try {
      await widget.deliveryGateway!.submitStopProof(
        merchantId: widget.merchantId,
        runId: widget.run.id,
        stopId: widget.stop.id,
        proof: proof,
        items: items,
      );
      await widget.store.acknowledgeDelivery(proof.id);
    } catch (error) {
      // A failed upload/acknowledgement leaves the durable outbox retry intact.
      // The parent handles definitive denial even after this form has closed.
      widget.onSyncError?.call(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionLabel = switch (_step) {
      0 => 'Confirm items',
      1 => 'Confirm payment',
      _ => 'Record proof',
    };

    return Scaffold(
      appBar: sariSupplyTaskAppBar(
        context,
        title: 'Stop ${widget.stop.sequence} of ${widget.run.totalStops}',
      ),
      body: SariSupplyPageContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.stop.destinationName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: SariSupplyColors.ink950,
              ),
            ),
            if (widget.stop.destinationAddress.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                widget.stop.destinationAddress,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: SariSupplyColors.ink600,
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (_step == 0) ...[
              Text(
                'Confirm items',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ..._itemEntries
                  .map((entry) => _buildItemStepperCard(entry, theme)),
            ],
            if (_step == 1)
              Form(
                key: _paymentFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Confirm payment',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'COD amount ${_formatPhp(_deliveredValueCentavos)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _cashController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Cash collected (PHP)',
                        hintText: '0.00',
                        prefixText: '\u20B1 ',
                        border: const OutlineInputBorder(),
                        helperText:
                            'Maximum: ${_formatPhp(_deliveredValueCentavos)}',
                      ),
                      validator: _cashValidationMessage,
                    ),
                  ],
                ),
              ),
            if (_step == 2)
              Form(
                key: _proofFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Record proof',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (widget.stop.paymentMethod == 'qr') ...[
                      const SizedBox(height: 8),
                      const Text('QR selected · do not collect cash.'),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _recipientNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Recipient name *',
                        hintText: 'e.g. Maria Santos',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Recipient name is required'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _recipientRole,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Recipient role',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'Store Owner',
                          child: Text('Store Owner'),
                        ),
                        DropdownMenuItem(
                          value: 'Store Manager',
                          child: Text('Store Manager'),
                        ),
                        DropdownMenuItem(
                            value: 'Cashier', child: Text('Cashier')),
                        DropdownMenuItem(
                          value: 'Staff/Relative',
                          child: Text('Staff/Relative'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _recipientRole = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    SignaturePad(
                      onChanged: (svg) => setState(() => _signatureSvg = svg),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Driver notes (optional)',
                        hintText: 'Any delivery or return notes...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            if (_step > 0)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _isSaving
                      ? null
                      : () {
                          setState(() {
                            if (_step == 2) _signatureSvg = null;
                            _step = _step == 2 && _requiresPayment ? 1 : 0;
                          });
                        },
                  child: const Text('Back'),
                ),
              ),
            FilledButton.icon(
              onPressed: _isSaving ? null : _advance,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SariSupplyColors.card,
                      ),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _isSaving ? 'Saving proof...' : actionLabel,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SariSupplyRadii.md),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildItemStepperCard(_ItemEntry entry, ThemeData theme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(SariSupplyRadii.md),
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
                    borderRadius: BorderRadius.circular(SariSupplyRadii.sm),
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
            Text(
              'Unit amount: ${_formatPhp(entry.item.unitCostCentavos)} / ${entry.item.unitName.isNotEmpty ? entry.item.unitName : 'unit'}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 2),
            Text(
              'Delivered line amount: ${_formatPhp(entry.quantityDelivered * entry.item.unitCostCentavos)}',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            LayoutBuilder(builder: (context, constraints) {
              final stack = constraints.maxWidth < 340 ||
                  MediaQuery.textScalerOf(context).scale(16) > 24;
              final width = stack
                  ? constraints.maxWidth
                  : (constraints.maxWidth - SariSupplySpacing.sm) / 2;
              return Wrap(
                spacing: SariSupplySpacing.sm,
                runSpacing: SariSupplySpacing.sm,
                children: [
                  SizedBox(
                    width: width,
                    child: _buildCounter(
                      label: 'Delivered',
                      value: entry.quantityDelivered,
                      color: SariSupplyColors.success,
                      onDecrement: () {
                        if (entry.quantityDelivered > 0) {
                          setState(() {
                            entry.quantityDelivered--;
                            entry.quantityReturned =
                                entry.item.quantityOrdered -
                                    entry.quantityDelivered;
                          });
                        }
                      },
                      onIncrement: () {
                        if (entry.quantityDelivered <
                            entry.item.quantityOrdered) {
                          setState(() {
                            entry.quantityDelivered++;
                            entry.quantityReturned =
                                entry.item.quantityOrdered -
                                    entry.quantityDelivered;
                          });
                        }
                      },
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _buildCounter(
                      label: 'Returned',
                      value: entry.quantityReturned,
                      color: SariSupplyColors.orange700,
                      onDecrement: () {
                        if (entry.quantityReturned > 0) {
                          setState(() {
                            entry.quantityReturned--;
                            entry.quantityDelivered =
                                entry.item.quantityOrdered -
                                    entry.quantityReturned;
                          });
                        }
                      },
                      onIncrement: () {
                        if (entry.quantityReturned <
                            entry.item.quantityOrdered) {
                          setState(() {
                            entry.quantityReturned++;
                            entry.quantityDelivered =
                                entry.item.quantityOrdered -
                                    entry.quantityReturned;
                          });
                        }
                      },
                    ),
                  ),
                ],
              );
            }),
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
        borderRadius: BorderRadius.circular(SariSupplyRadii.sm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Decrease $label quantity',
                iconSize: 24,
                onPressed: onDecrement,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text(
                '$value',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                tooltip: 'Increase $label quantity',
                iconSize: 24,
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

String _formatPhp(int centavos) => '₱${(centavos / 100).toStringAsFixed(2)}';
