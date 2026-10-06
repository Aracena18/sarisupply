import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:url_launcher/url_launcher.dart';

import 'delivery_signature_screen.dart';

class StopDetailScreen extends StatefulWidget {
  const StopDetailScreen({
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
  State<StopDetailScreen> createState() => _StopDetailScreenState();
}

class _StopDetailScreenState extends State<StopDetailScreen> {
  late DeliveryStop _stop;
  late DeliveryRun _run;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _run = widget.run;
    _stop = widget.stop;
  }

  Future<void> _refresh() async {
    final updatedRun = await widget.store.getDeliveryRun(_run.id);
    if (updatedRun != null && mounted) {
      setState(() {
        _run = updatedRun;
        _stop = updatedRun.stops.firstWhere(
          (s) => s.id == _stop.id,
          orElse: () => _stop,
        );
      });
    }
  }

  Future<void> _launchMaps() async {
    final Uri primaryUri;
    if (_stop.latitude != null && _stop.longitude != null) {
      primaryUri = Uri.parse(
        'geo:${_stop.latitude},${_stop.longitude}?q=${Uri.encodeComponent(_stop.destinationAddress)}',
      );
    } else {
      primaryUri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_stop.destinationAddress)}',
      );
    }

    try {
      final launched = await launchUrl(
        primaryUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        final fallback = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_stop.destinationAddress)}',
        );
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      final fallback = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(_stop.destinationAddress)}',
      );
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _callContact() async {
    if (_stop.contactPhone.isEmpty) return;
    final uri = Uri.parse('tel:${_stop.contactPhone}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _markArrived() async {
    setState(() => _isLoading = true);
    try {
      await widget.store.updateStopStatus(
        runId: _run.id,
        stopId: _stop.id,
        status: DeliveryStopStatus.arrived,
      );
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Arrived at destination.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(operationErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showFailDialog() async {
    String reason = 'Store closed';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Mark Delivery as Failed'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select the reason delivery could not be completed:'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: reason,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                      value: 'Store closed', child: Text('Store closed')),
                  DropdownMenuItem(
                      value: 'Owner unreachable',
                      child: Text('Owner unreachable')),
                  DropdownMenuItem(
                      value: 'Refused entire shipment',
                      child: Text('Refused entire shipment')),
                  DropdownMenuItem(
                      value: 'Incorrect address',
                      child: Text('Incorrect address')),
                ],
                onChanged: (val) {
                  if (val != null) setDlgState(() => reason = val);
                },
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
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Confirm Failure'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        final failedItems = _stop.items
            .map((i) => i.copyWith(
                  quantityDelivered: 0,
                  quantityReturned: i.quantityOrdered,
                  returnReason: reason,
                ))
            .toList();

        final proof = DeliveryProof(
          id: 'failed-${_stop.id}',
          stopId: _stop.id,
          recipientName: 'N/A',
          recipientRole: 'Failed Attempt',
          signatureSvg: '',
          deliveredAt: DateTime.now(),
          driverNotes: 'Delivery failed: $reason',
          offlineCreated: true,
        );

        await widget.store.recordDeliveryProof(
          runId: _run.id,
          stopId: _stop.id,
          proof: proof,
          items: failedItems,
        );

        await _refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Stop marked as failed ($reason).'),
              backgroundColor: Colors.orange.shade900,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update stop: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: sariSupplyTaskAppBar(
        context,
        title: 'Stop #${_stop.sequence}: ${_stop.destinationName}',
      ),
      body: SariSupplyPageContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status & Sequence Card
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'STOP #${_stop.sequence}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildStatusBadge(_stop.status, theme),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _stop.destinationName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _stop.destinationAddress,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_stop.contactPerson.isNotEmpty ||
                        _stop.contactPhone.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline,
                            size: 18,
                            color: theme.colorScheme.outline,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _stop.contactPerson.isNotEmpty
                                ? _stop.contactPerson
                                : 'Contact',
                            style: theme.textTheme.bodyMedium,
                          ),
                          if (_stop.contactPhone.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text('• ${_stop.contactPhone}'),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _launchMaps,
                            icon: const Icon(Icons.navigation_outlined),
                            label: const Text('Open in Maps'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (_stop.contactPhone.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          IconButton.filledTonal(
                            onPressed: _callContact,
                            icon: const Icon(Icons.phone),
                            tooltip: 'Call Contact',
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Package verification
            if (_stop.packageManifestId != null) ...[
              Card(
                elevation: 0,
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Verified Package Manifest',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              _stop.packageManifestId!,
                              style: TextStyle(
                                  color: theme.colorScheme.outline,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text('${_stop.totalOrderedUnits} items'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Items to Deliver Card
            Text(
              'Items for this Stop',
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _stop.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final item = _stop.items[idx];
                  return ListTile(
                    title: Text(
                      item.productName,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('SKU: ${item.sku}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Ordered: ${item.quantityOrdered} ${item.unitName}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (item.quantityDelivered > 0 ||
                            item.quantityReturned > 0)
                          Text(
                            'Delivered: ${item.quantityDelivered} | Returned: ${item.quantityReturned}',
                            style: TextStyle(
                              fontSize: 12,
                              color: item.quantityReturned > 0
                                  ? Colors.orange.shade800
                                  : Colors.green.shade800,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Proof Summary if already completed
            if (_stop.proof != null) ...[
              Card(
                elevation: 0,
                color: Colors.green.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.verified,
                              color: Colors.green, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Delivery Proof Recorded',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.green.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Recipient: ${_stop.proof!.recipientName} (${_stop.proof!.recipientRole})'),
                      if (_stop.proof!.cashCollectedCentavos > 0)
                        Text(
                          'COD Collected: ₱ ${(_stop.proof!.cashCollectedCentavos / 100).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      Text(
                        'Time: ${_stop.proof!.deliveredAt.toLocal().toString().substring(0, 16)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (_stop.proof!.driverNotes.isNotEmpty)
                        Text('Notes: ${_stop.proof!.driverNotes}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Action Buttons
            if (!_stop.isCompleted) ...[
              if (_stop.status == DeliveryStopStatus.pending)
                FilledButton.icon(
                  onPressed: _isLoading ? null : _markArrived,
                  icon: const Icon(Icons.storefront_outlined),
                  label: const Text('Mark Arrived at Destination'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              if (_stop.status == DeliveryStopStatus.arrived) ...[
                FilledButton.icon(
                  onPressed: () async {
                    final res = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => DeliverySignatureScreen(
                          run: _run,
                          stop: _stop,
                          store: widget.store,
                          deliveryGateway: widget.deliveryGateway,
                          merchantId: widget.merchantId,
                        ),
                      ),
                    );
                    if (res == true) {
                      await _refresh();
                    }
                  },
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: const Text('Proceed to Delivery & Signature'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _showFailDialog,
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text('Mark Delivery as Failed',
                      style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ],
            ],
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(DeliveryStopStatus status, ThemeData theme) {
    Color bg;
    Color fg;
    switch (status) {
      case DeliveryStopStatus.pending:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        break;
      case DeliveryStopStatus.arrived:
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        break;
      case DeliveryStopStatus.delivered:
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
      case DeliveryStopStatus.partiallyDelivered:
        bg = Colors.orange.shade100;
        fg = Colors.orange.shade900;
        break;
      case DeliveryStopStatus.failed:
      case DeliveryStopStatus.cancelled:
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
