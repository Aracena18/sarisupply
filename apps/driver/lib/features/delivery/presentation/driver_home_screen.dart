import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:url_launcher/url_launcher.dart';

import 'stop_detail_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({
    super.key,
    required this.store,
    this.deliveryGateway,
    required this.merchantId,
    required this.driverId,
    required this.driverName,
    this.onSignOut,
  });

  final InventoryStore store;
  final DeliveryGateway? deliveryGateway;
  final String merchantId;
  final String driverId;
  final String driverName;
  final Future<void> Function()? onSignOut;

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  DeliveryRun? _currentRun;
  List<DeliveryRun> _runs = [];
  int _pendingCount = 0;
  bool _isLoading = true;
  bool _isSyncing = false;
  String? _syncMessage;

  @override
  void initState() {
    super.initState();
    _loadRuns();
  }

  Future<void> _loadRuns() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      Set<String>? remoteIds;
      if (widget.deliveryGateway != null) {
        try {
          final remote = await widget.deliveryGateway!
              .listRuns(widget.merchantId, driverId: widget.driverId);
          remoteIds = remote.map((run) => run.id).toSet();
          for (final run in remote) {
            if (run.driverId != widget.driverId) {
              throw const FormatException('Assignment mismatch');
            }
            if (!await widget.store.hasPendingDelivery(run.id)) {
              await widget.store.saveDeliveryRun(run);
            }
          }
          _syncMessage = null;
        } catch (error) {
          if (!mounted) return;
          setState(() => _syncMessage = operationErrorMessage(error));
          if (!operationErrorMessage(error)
              .startsWith('Check your connection')) {
            _currentRun = null;
            return;
          }
        }
      }
      final runs =
          await widget.store.listDeliveryRuns(driverId: widget.driverId);
      _pendingCount = (await widget.store.pendingDeliveries()).length;
      final active = runs
          .where((run) => remoteIds == null || remoteIds.contains(run.id))
          .where((r) => [
                DeliveryRunStatus.dispatched,
                DeliveryRunStatus.inTransit,
                DeliveryRunStatus.completed
              ].contains(r.status))
          .toList();
      _runs = active;
      _currentRun = active.isEmpty
          ? null
          : active.firstWhere((run) => run.id == _currentRun?.id,
              orElse: () => active.first);
    } catch (error) {
      _syncMessage = operationErrorMessage(error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _syncOfflineProofs() async {
    if (_isSyncing || widget.deliveryGateway == null) return;
    setState(() {
      _isSyncing = true;
      _syncMessage = null;
    });
    try {
      for (final operation in await widget.store.pendingDeliveries()) {
        final payload = Map<String, Object?>.from(
            jsonDecode(operation['payload'] as String) as Map);
        if (operation['kind'] == 'proof') {
          await widget.deliveryGateway!.submitStopProof(
              merchantId: widget.merchantId,
              runId: operation['run'] as String,
              stopId: operation['stop'] as String,
              proof: DeliveryProof.fromMap(
                  Map<String, dynamic>.from(payload['proof'] as Map)),
              items: (payload['items'] as List)
                  .map((i) => DeliveryStopItem.fromMap(
                      Map<String, dynamic>.from(i as Map)))
                  .toList());
        } else if (widget.deliveryGateway
            case final DeliveryFunctions gateway) {
          await gateway
              .updateStatus({'merchantId': widget.merchantId, ...payload});
        } else {
          throw StateError('Status synchronization is unavailable');
        }
        await widget.store.acknowledgeDelivery(operation['id'] as String);
      }
      if (mounted) {
        setState(() => _syncMessage = 'Saved delivery operations synchronized');
      }
      await _loadRuns();
    } catch (error) {
      if (mounted) {
        setState(() => _syncMessage =
            '${operationErrorMessage(error)} Local work is retained.');
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _launchMaps(DeliveryStop stop) async {
    final Uri uri;
    if (stop.latitude != null && stop.longitude != null) {
      uri = Uri.parse(
        'geo:${stop.latitude},${stop.longitude}?q=${Uri.encodeComponent(stop.destinationAddress)}',
      );
    } else {
      uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(stop.destinationAddress)}',
      );
    }

    try {
      final launched =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        final fallback = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(stop.destinationAddress)}',
        );
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      final fallback = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(stop.destinationAddress)}',
      );
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: sariSupplyTaskAppBar(
        context,
        title: 'Driver Deliveries: ${widget.driverName}',
        actions: [
          if (widget.onSignOut != null)
            IconButton(
                onPressed: widget.onSignOut,
                tooltip: 'Sign out',
                icon: const Icon(Icons.logout)),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRuns,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: SariSupplyPageContent(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _currentRun == null
                ? _buildEmptyState(theme)
                : _buildRunContent(theme),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_syncMessage != null)
              SariSupplyStatus(message: _syncMessage!, error: true),
            Icon(
              Icons.local_shipping_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No Active Delivery Runs',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have no assigned runs currently in progress.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildRunContent(ThemeData theme) {
    final run = _currentRun!;
    final pendingCount = run.pendingStops;
    final completedCount = run.completedStops;
    final totalCount = run.totalStops;

    final hasPendingProofs = _pendingCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_runs.length > 1)
          DropdownButtonFormField<String>(
            initialValue: run.id,
            decoration: const InputDecoration(labelText: 'Delivery run'),
            items: _runs
                .map((item) =>
                    DropdownMenuItem(value: item.id, child: Text(item.id)))
                .toList(),
            onChanged: _isSyncing
                ? null
                : (id) => setState(() =>
                    _currentRun = _runs.firstWhere((item) => item.id == id)),
          ),
        // Offline resilience & sync indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color:
                hasPendingProofs ? Colors.amber.shade50 : Colors.teal.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasPendingProofs
                  ? Colors.amber.shade300
                  : Colors.teal.shade200,
            ),
          ),
          child: Row(
            children: [
              Icon(
                hasPendingProofs
                    ? Icons.cloud_upload_outlined
                    : Icons.offline_pin_outlined,
                color: hasPendingProofs
                    ? Colors.amber.shade900
                    : Colors.teal.shade800,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  hasPendingProofs
                      ? 'Local proofs pending sync'
                      : 'Offline-ready: All changes saved to SQLite',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hasPendingProofs
                        ? Colors.amber.shade900
                        : Colors.teal.shade900,
                  ),
                ),
              ),
              if (hasPendingProofs)
                TextButton(
                  onPressed: _isSyncing ? null : _syncOfflineProofs,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.amber.shade900,
                  ),
                  child: _isSyncing
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sync Now'),
                ),
            ],
          ),
        ),
        if (_syncMessage != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _syncMessage!,
              style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
            ),
          ),
        ],
        const SizedBox(height: 16),

        // Route overview card
        Card(
          elevation: 0,
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
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
                    Text(
                      'ROUTE: ${run.id}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    _buildRunStatusChip(run.status, theme),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.directions_car_outlined,
                        size: 16, color: theme.colorScheme.outline),
                    const SizedBox(width: 6),
                    Text(run.vehicleInfo, style: theme.textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: totalCount > 0 ? (completedCount / totalCount) : 0,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$completedCount of $totalCount stops completed',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (pendingCount > 0)
                      Text(
                        '$pendingCount stops remaining',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Stop List Header
        Text(
          'Stops Sequence',
          style:
              theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // Stop items
        ...run.stops.map((stop) => _buildStopCard(stop, theme)),

        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildStopCard(DeliveryStop stop, ThemeData theme) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: stop.isCompleted
              ? Colors.green.withValues(alpha: 0.4)
              : theme.colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StopDetailScreen(
                run: _currentRun!,
                stop: stop,
                store: widget.store,
                deliveryGateway: widget.deliveryGateway,
                merchantId: widget.merchantId,
              ),
            ),
          );
          await _loadRuns();
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: stop.isCompleted
                            ? Colors.green.shade100
                            : theme.colorScheme.primaryContainer,
                        child: Text(
                          '${stop.sequence}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: stop.isCompleted
                                ? Colors.green.shade900
                                : theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Stop #${stop.sequence}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  _buildStopStatusChip(stop.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                stop.destinationName,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(
                stop.destinationAddress,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${stop.totalOrderedUnits} units',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _launchMaps(stop),
                        icon: const Icon(Icons.navigation_outlined, size: 14),
                        label:
                            const Text('Maps', style: TextStyle(fontSize: 12)),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right,
                        color: theme.colorScheme.outline,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRunStatusChip(DeliveryRunStatus status, ThemeData theme) {
    Color bg;
    Color fg;
    switch (status) {
      case DeliveryRunStatus.draft:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        break;
      case DeliveryRunStatus.dispatched:
        bg = Colors.blue.shade100;
        fg = Colors.blue.shade900;
        break;
      case DeliveryRunStatus.inTransit:
        bg = Colors.indigo.shade100;
        fg = Colors.indigo.shade900;
        break;
      case DeliveryRunStatus.completed:
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
      case DeliveryRunStatus.cancelled:
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStopStatusChip(DeliveryStopStatus status) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        status.label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}
