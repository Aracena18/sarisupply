import 'package:firebase_core/firebase_core.dart';
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
  State<StopDetailScreen> createState() => _StopDetailScreenState();
}

class _StopDetailScreenState extends State<StopDetailScreen> {
  late DeliveryStop _stop;
  late DeliveryRun _run;
  bool _isLoading = false, _accessDenied = false;
  bool _directionsOpened = false;
  bool _completedInThisVisit = false;

  @override
  void initState() {
    super.initState();
    _run = widget.run;
    _stop = widget.stop;
  }

  void _syncError(Object error) {
    widget.onSyncError?.call(error);
    if (mounted &&
        error is FirebaseException &&
        ['permission-denied', 'unauthenticated'].contains(error.code)) {
      setState(() => _accessDenied = true);
    }
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
            backgroundColor: SariSupplyColors.info,
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

  Future<void> _openSignature() async {
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DeliverySignatureScreen(
          run: _run,
          stop: _stop,
          store: widget.store,
          deliveryGateway: widget.deliveryGateway,
          onSyncError: _syncError,
          merchantId: widget.merchantId,
        ),
      ),
    );
    if (completed == true) {
      _completedInThisVisit = true;
      await _refresh();
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
              style: FilledButton.styleFrom(
                  backgroundColor: SariSupplyColors.error),
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
              backgroundColor: SariSupplyColors.orange700,
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

  Future<void> _handlePrimary() async {
    if (_isLoading) return;
    if (_stop.isCompleted) {
      if (mounted) Navigator.of(context).pop(_completedInThisVisit);
      return;
    }
    if (_stop.status == DeliveryStopStatus.pending) {
      if (!_directionsOpened) {
        setState(() => _directionsOpened = true);
        await _launchMaps();
      } else {
        await _markArrived();
      }
      return;
    }
    if (_stop.status == DeliveryStopStatus.arrived) {
      await _openSignature();
    }
  }

  ({String label, IconData icon}) _primaryState() {
    if (_stop.isCompleted) {
      if (_completedInThisVisit) {
        return (label: 'Complete stop', icon: Icons.check_circle_outline);
      }
      return (label: 'Next stop', icon: Icons.arrow_forward);
    }
    if (_stop.status == DeliveryStopStatus.pending) {
      if (!_directionsOpened) {
        return (label: 'Open directions', icon: Icons.near_me_outlined);
      }
      return (label: 'Start delivery', icon: Icons.storefront_outlined);
    }
    if (_stop.status == DeliveryStopStatus.arrived) {
      return (label: 'Confirm items', icon: Icons.checklist_outlined);
    }
    return (label: 'Open directions', icon: Icons.near_me_outlined);
  }

  int _codCentavos() {
    if (_stop.paymentMethod == 'qr') return 0;
    final proof = _stop.proof;
    if (proof != null && proof.cashCollectedCentavos > 0) {
      return proof.cashCollectedCentavos;
    }
    return _stop.amountDueCentavos ??
        _stop.items.fold<int>(
          0,
          (sum, i) => sum + i.quantityOrdered * i.unitCostCentavos,
        );
  }

  String _formatPhp(int centavos) =>
      '\u20B1${(centavos / 100).toStringAsFixed(2)}';

  bool get _hasDeliverySummary =>
      _stop.items.isNotEmpty ||
      _codCentavos() > 0 ||
      _stop.packageManifestId != null ||
      _stop.proof != null;

  @override
  Widget build(BuildContext context) {
    if (_accessDenied) {
      return Scaffold(
        backgroundColor: SariSupplyColors.paper,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Padding(
                padding: EdgeInsets.all(16),
                child: SariSupplyStatus(
                  message:
                      'Delivery access has changed. Local work is retained.',
                  error: true,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: SariSupplyColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                children: [
                  _buildDestination(),
                  if (_hasDeliverySummary) ...[
                    const Divider(height: 32, color: SariSupplyColors.divider),
                    _buildDeliverySummary(),
                  ],
                  if (_stop.items.isNotEmpty) ...[
                    const Divider(height: 32, color: SariSupplyColors.divider),
                    _buildItems(),
                  ],
                  if (_stop.notes.trim().isNotEmpty) ...[
                    const Divider(height: 32, color: SariSupplyColors.divider),
                    _buildInstructions(),
                  ],
                  if (_stop.status == DeliveryStopStatus.arrived) ...[
                    const SizedBox(height: 8),
                    _buildFailAction(),
                  ],
                ],
              ),
            ),
            _buildStickyCta(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back,
                    color: SariSupplyColors.ink950, size: 26),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Stop ${_stop.sequence} of ${_run.totalStops}',
                  style: const TextStyle(
                    fontFamily: SariSupplyTypography.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: SariSupplyColors.ink950,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: SariSupplyColors.divider),
      ],
    );
  }

  Widget _buildDestination() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _stop.destinationName,
          style: const TextStyle(
            fontSize: 22,
            height: 4 / 3,
            fontWeight: FontWeight.w800,
            color: SariSupplyColors.ink950,
          ),
        ),
        if (_stop.destinationAddress.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 20,
                color: SariSupplyColors.orange500,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _stop.destinationAddress,
                  style: const TextStyle(
                    fontSize: 16,
                    color: SariSupplyColors.ink600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildDeliverySummary() {
    final cod = _codCentavos();
    final hasUnits = _stop.items.isNotEmpty;
    final hasCod = cod > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DELIVERY',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: SariSupplyColors.ink500,
          ),
        ),
        if (hasUnits || hasCod) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (hasUnits)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_stop.totalOrderedUnits} units',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: SariSupplyColors.ink950,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Total items',
                        style: TextStyle(
                          fontSize: 14,
                          color: SariSupplyColors.ink600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (hasUnits && hasCod)
                Container(
                  width: 1,
                  height: 48,
                  color: SariSupplyColors.divider,
                ),
              if (hasCod)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: hasUnits ? 16 : 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatPhp(cod),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: SariSupplyColors.ink950,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'COD amount',
                          style: TextStyle(
                            fontSize: 14,
                            color: SariSupplyColors.ink600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (_stop.paymentMethod == 'qr') ...[
          const SizedBox(height: 8),
          const Text('QR payment selected · collect no cash.'),
        ],
        if (_stop.packageManifestId != null) ...[
          const SizedBox(height: 12),
          const Row(
            children: [
              Icon(Icons.check_circle,
                  size: 22, color: SariSupplyColors.success),
              SizedBox(width: 8),
              Text(
                'Package verified',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: SariSupplyColors.success,
                ),
              ),
            ],
          ),
        ],
        if (_stop.proof != null) _buildProofSummary(),
      ],
    );
  }

  Widget _buildProofSummary() {
    final proof = _stop.proof!;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _stop.status == DeliveryStopStatus.failed
                    ? Icons.error_outline
                    : Icons.check_circle,
                size: 22,
                color: _stop.status == DeliveryStopStatus.failed
                    ? SariSupplyColors.error
                    : SariSupplyColors.success,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _stop.status == DeliveryStopStatus.failed
                      ? 'Delivery failed'
                      : 'Delivered \u00B7 ${proof.recipientName}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _stop.status == DeliveryStopStatus.failed
                        ? SariSupplyColors.error
                        : SariSupplyColors.success,
                  ),
                ),
              ),
            ],
          ),
          if (proof.cashCollectedCentavos > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Cash collected ${_formatPhp(proof.cashCollectedCentavos)}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: SariSupplyColors.ink950,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItems() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ITEMS (${_stop.items.length})',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: SariSupplyColors.ink500,
          ),
        ),
        const SizedBox(height: 4),
        for (final item in _stop.items) ...[
          Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.productName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: SariSupplyColors.ink950,
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (item.sku.trim().isNotEmpty)
                        Text(
                          'SKU ${item.sku}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: SariSupplyColors.ink600,
                          ),
                        ),
                      if (_stop.isCompleted &&
                          (item.quantityDelivered > 0 ||
                              item.quantityReturned > 0))
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Delivered: ${item.quantityDelivered} \u00B7 Returned: ${item.quantityReturned}',
                            style: TextStyle(
                              fontSize: 14,
                              color: item.quantityReturned > 0
                                  ? SariSupplyColors.orange700
                                  : SariSupplyColors.success,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${item.quantityOrdered}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: SariSupplyColors.ink950,
                      ),
                    ),
                    const Text(
                      'units',
                      style: TextStyle(
                        fontSize: 14,
                        color: SariSupplyColors.ink600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: SariSupplyColors.divider),
        ],
      ],
    );
  }

  Widget _buildInstructions() {
    return InkWell(
      onTap: () => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delivery instructions'),
          content: Text(_stop.notes.trim()),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.description_outlined,
                size: 22, color: SariSupplyColors.ink600),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Delivery instructions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: SariSupplyColors.ink950,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _stop.notes.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: SariSupplyColors.ink600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 24, color: SariSupplyColors.ink600),
          ],
        ),
      ),
    );
  }

  Widget _buildFailAction() {
    return Center(
      child: TextButton(
        onPressed: _isLoading ? null : _showFailDialog,
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          foregroundColor: SariSupplyColors.error,
        ),
        child: const Text('Mark as failed'),
      ),
    );
  }

  Widget _buildStickyCta() {
    final state = _primaryState();
    return Container(
      color: SariSupplyColors.paper,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _isLoading ? null : _handlePrimary,
            icon: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: SariSupplyColors.ink950),
                  )
                : Icon(state.icon, size: 24),
            label: Text(
              state.label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: SariSupplyColors.orange500,
              foregroundColor: SariSupplyColors.ink950,
              disabledBackgroundColor:
                  SariSupplyColors.orange500.withValues(alpha: 0.6),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
