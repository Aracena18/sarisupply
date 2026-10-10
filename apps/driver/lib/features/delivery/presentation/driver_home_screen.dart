import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:url_launcher/url_launcher.dart';

import 'delivery_signature_screen.dart';
import 'stop_detail_screen.dart';
import '../data/driver_gps.dart';
import 'driver_location_controller.dart';

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

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with WidgetsBindingObserver {
  DriverLocationController? _location;
  DeliveryRun? _currentRun;
  List<DeliveryRun> _runs = [];
  int _pendingCount = 0;
  bool _isLoading = true;
  bool _isSyncing = false;
  bool _refreshing = false, _accessDenied = false;
  DateTime? _refreshedAt;
  String? _syncMessage;

  bool _showCompleted = false;
  bool _actionBusy = false;
  final Set<String> _directionsOpened = {};
  final Set<String> _itemsConfirmed = {};
  final Set<String> _proofStarted = {};
  String? _justCompletedStopId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final gateway = widget.deliveryGateway;
    if (gateway is DriverLocationGateway) {
      _location = DriverLocationController(
          gateway: gateway as DriverLocationGateway,
          merchantId: widget.merchantId,
          capture: captureDriverLocation);
    }
    _loadRuns();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _location?.setForeground(state == AppLifecycleState.resumed);
    if (state == AppLifecycleState.resumed) {
      unawaited(_loadRuns(force: false));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _location?.dispose();
    super.dispose();
  }

  void _selectLocationRun() {
    final run = _currentRun;
    _location?.selectRun(run != null &&
            [DeliveryRunStatus.dispatched, DeliveryRunStatus.inTransit]
                .contains(run.status)
        ? run.id
        : null);
  }

  Future<void> _loadRuns({bool force = true}) async {
    if (!mounted || _refreshing || _accessDenied) return;
    _refreshing = true;
    try {
      await _displayLocalRuns();
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (!force &&
          _refreshedAt != null &&
          DateTime.now().difference(_refreshedAt!) <
              const Duration(seconds: 30)) {
        return;
      }
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
          final assignmentMismatch = error is FormatException &&
              error.message == 'Assignment mismatch';
          final accessDenied = assignmentMismatch ||
              (error is FirebaseException &&
                  const {'permission-denied', 'unauthenticated'}
                      .contains(error.code));
          setState(() {
            _syncMessage = assignmentMismatch
                ? 'This delivery is assigned to another driver. Ask your administrator to refresh the assignment.'
                : accessDenied
                    ? operationErrorMessage(error)
                    : '${operationErrorMessage(error)} Saved deliveries remain on this phone.';
          });
          if (accessDenied) {
            _accessDenied = true;
            _runs = [];
            _currentRun = null;
            return;
          }
          // A server or response error does not revoke the driver's cached work.
          // Do not filter it using a partial result from this failed refresh.
          remoteIds = null;
        }
      }
      await _displayLocalRuns(remoteIds: remoteIds);
      _refreshedAt = DateTime.now();
    } catch (error) {
      _syncMessage = operationErrorMessage(error);
    } finally {
      _refreshing = false;
      if (mounted) {
        _selectLocationRun();
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _displayLocalRuns({Set<String>? remoteIds}) async {
    final runs = await widget.store.listDeliveryRuns(driverId: widget.driverId);
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
    if (mounted) {
      _selectLocationRun();
      setState(() {});
    }
  }

  void _syncError(Object error) {
    if (!mounted) return;
    setState(() {
      _syncMessage = '${operationErrorMessage(error)} Local work is retained.';
      if (error is FirebaseException &&
          ['permission-denied', 'unauthenticated'].contains(error.code)) {
        _accessDenied = true;
        _runs = [];
        _currentRun = null;
        _location?.stop();
      }
    });
  }

  Future<void> _syncOfflineProofs() async {
    if (_isSyncing || _accessDenied || widget.deliveryGateway == null) return;
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Saved delivery operations synchronized')),
        );
      }
      await _loadRuns();
    } catch (error) {
      _syncError(error);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _retrySync() async {
    if (_pendingCount > 0) {
      await _syncOfflineProofs();
    } else {
      await _loadRuns();
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

  Future<void> _startDelivery(DeliveryStop stop) async {
    if (_actionBusy) return;
    setState(() => _actionBusy = true);
    try {
      await widget.store.updateStopStatus(
        runId: _currentRun!.id,
        stopId: stop.id,
        status: DeliveryStopStatus.arrived,
      );
      await _loadRuns(force: false);
      _refreshedAt = null;
      await _loadRuns();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Started delivery for ${stop.destinationName}.')),
        );
      }
    } catch (e) {
      _syncError(e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(operationErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _actionBusy = false);
    }
  }

  Future<void> _openStopDetail(DeliveryStop stop) async {
    final run = _currentRun;
    if (run == null) return;
    final completedFromStopDetail = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => StopDetailScreen(
          run: run,
          stop: stop,
          store: widget.store,
          deliveryGateway: widget.deliveryGateway,
          onSyncError: _syncError,
          merchantId: widget.merchantId,
        ),
      ),
    );
    _itemsConfirmed.add(stop.id);
    _justCompletedStopId = completedFromStopDetail == true ? stop.id : null;
    await _loadRuns(force: false);
  }

  Future<void> _openSignature(DeliveryStop stop) async {
    final run = _currentRun;
    if (run == null) return;
    _proofStarted.add(stop.id);
    final completed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DeliverySignatureScreen(
          run: run,
          stop: stop,
          store: widget.store,
          deliveryGateway: widget.deliveryGateway,
          onSyncError: _syncError,
          merchantId: widget.merchantId,
        ),
      ),
    );
    if (completed == true) {
      _justCompletedStopId = stop.id;
      _directionsOpened.remove(stop.id);
    }
    await _loadRuns(force: false);
  }

  Future<void> _handlePrimary() async {
    final run = _currentRun;
    if (run == null || _actionBusy || _isSyncing) return;
    if (_justCompletedStopId != null) {
      setState(() => _justCompletedStopId = null);
      return;
    }
    final next = _nextStop(run);
    if (next == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route completed.')),
        );
      }
      await _loadRuns();
      return;
    }
    if (next.status == DeliveryStopStatus.pending) {
      if (!_directionsOpened.contains(next.id)) {
        _directionsOpened.add(next.id);
        setState(() {});
        await _launchMaps(next);
      } else {
        await _startDelivery(next);
      }
      return;
    }
    if (next.status == DeliveryStopStatus.arrived) {
      if (!_itemsConfirmed.contains(next.id)) {
        await _openStopDetail(next);
      } else {
        await _openSignature(next);
      }
      return;
    }
  }

  DeliveryStop? _nextStop(DeliveryRun run) {
    final sorted = List<DeliveryStop>.from(run.stops)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    for (final stop in sorted) {
      if (!stop.isCompleted) return stop;
    }
    return null;
  }

  List<DeliveryStop> _upNext(DeliveryRun run, DeliveryStop? next) {
    if (next == null) return const [];
    final sorted = List<DeliveryStop>.from(run.stops)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return sorted
        .where((s) => !s.isCompleted && s.id != next.id)
        .take(2)
        .toList();
  }

  List<DeliveryStop> _completedStops(DeliveryRun run) {
    final sorted = List<DeliveryStop>.from(run.stops)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    return sorted.where((s) => s.isCompleted).toList();
  }

  int _codCentavos(DeliveryStop stop) {
    if (stop.paymentMethod == 'qr') return 0;
    if (stop.proof != null && stop.proof!.cashCollectedCentavos > 0) {
      return stop.proof!.cashCollectedCentavos;
    }
    return stop.amountDueCentavos ??
        stop.items.fold<int>(
          0,
          (sum, i) => sum + i.quantityOrdered * i.unitCostCentavos,
        );
  }

  String _formatCod(int centavos) =>
      'COD \u20B1${(centavos / 100).toStringAsFixed(2)}';

  String _stopNumber(int sequence) => sequence.toString().padLeft(2, '0');

  ({String label, IconData icon}) _primaryState() {
    final run = _currentRun;
    if (run == null) {
      return (label: 'Open directions', icon: Icons.near_me_outlined);
    }
    if (_justCompletedStopId != null) {
      final next = _nextStop(run);
      if (next == null) {
        return (label: 'Finish route', icon: Icons.flag_outlined);
      }
      return (label: 'Next stop', icon: Icons.arrow_forward);
    }
    final next = _nextStop(run);
    if (next == null) {
      return (label: 'Finish route', icon: Icons.flag_outlined);
    }
    if (next.status == DeliveryStopStatus.pending) {
      if (!_directionsOpened.contains(next.id)) {
        return (label: 'Open directions', icon: Icons.near_me_outlined);
      }
      return (label: 'Start delivery', icon: Icons.storefront_outlined);
    }
    if (next.status == DeliveryStopStatus.arrived) {
      if (!_itemsConfirmed.contains(next.id)) {
        return (label: 'Confirm items', icon: Icons.checklist_outlined);
      }
      if (!_proofStarted.contains(next.id)) {
        return (label: 'Record proof', icon: Icons.edit_outlined);
      }
      return (label: 'Complete stop', icon: Icons.check_circle_outline);
    }
    return (label: 'Open directions', icon: Icons.near_me_outlined);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SariSupplyColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _currentRun == null
                      ? _buildEmptyState()
                      : _buildRouteBody(),
            ),
            if (_currentRun != null && !_isLoading) _buildStickyCta(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final initial = widget.driverName.trim().isEmpty
        ? 'R'
        : widget.driverName.trim().substring(0, 1).toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          const SariSupplySymbol(size: 32),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'My Route',
              style: TextStyle(
                fontFamily: SariSupplyTypography.fontFamily,
                fontFamilyFallback: SariSupplyTypography.fallback,
                fontSize: 18,
                height: 4 / 3,
                fontWeight: FontWeight.w700,
                color: SariSupplyColors.ink950,
              ),
            ),
          ),
          Semantics(
            label: 'Rider account',
            button: true,
            child: InkWell(
              onTap: () => _showAccountSheet(context),
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: SariSupplyColors.divider,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: SariSupplyColors.ink950,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAccountSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.driverName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: SariSupplyColors.ink950,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.onSignOut != null)
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      _location?.stop();
                      await widget.onSignOut!();
                    },
                    child: const Text('Sign out'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: () => _loadRuns(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_stripMessage() != null) _buildSyncStrip(),
            const SizedBox(height: 48),
            const Text(
              'No active deliveries',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: SariSupplyColors.ink950,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You have no assigned runs currently in progress.',
              style: TextStyle(fontSize: 14, color: SariSupplyColors.ink600),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String? _stripMessage() {
    if (_accessDenied) return null;
    if (_pendingCount > 0) return 'Saved on this phone \u00B7 Waiting to sync';
    return _syncMessage;
  }

  Widget _buildSyncStrip() {
    final message = _stripMessage();
    if (message == null) return const SizedBox.shrink();
    final hasLocalPendingWork = _pendingCount > 0;
    final canRetry = widget.deliveryGateway != null &&
        !_isSyncing &&
        !_refreshing &&
        !_accessDenied &&
        (hasLocalPendingWork || _syncMessage != null);
    return Container(
      decoration: BoxDecoration(
        color: hasLocalPendingWork
            ? SariSupplyColors.ink50
            : SariSupplyColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            hasLocalPendingWork ? Icons.cloud_outlined : Icons.sync_problem,
            size: 20,
            color: hasLocalPendingWork
                ? SariSupplyColors.success
                : SariSupplyColors.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: SariSupplyColors.ink600,
              ),
            ),
          ),
          if (canRetry)
            TextButton(
              onPressed: _retrySync,
              style: TextButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: SariSupplyColors.orange500,
              ),
              child: _isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text(
                      'Retry',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteBody() {
    final run = _currentRun!;
    final next = _nextStop(run);
    final upNext = _upNext(run, next);
    final completed = _completedStops(run);
    final total = run.totalStops;
    final done = run.completedStops;

    return RefreshIndicator(
      onRefresh: () => _loadRuns(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_stripMessage() != null) ...[
              _buildSyncStrip(),
              const SizedBox(height: 16),
            ],
            if (_runs.length > 1) ...[
              _buildRunSelector(),
              const SizedBox(height: 12),
            ],
            const Text(
              'TODAY\u2019S ROUTE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: SariSupplyColors.ink500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              run.id,
              style: const TextStyle(
                fontSize: 18,
                height: 4 / 3,
                fontWeight: FontWeight.w800,
                color: SariSupplyColors.ink950,
              ),
            ),
            if (run.vehicleInfo.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.local_shipping_outlined,
                    size: 20,
                    color: SariSupplyColors.ink600,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      run.vehicleInfo,
                      style: const TextStyle(
                        fontSize: 14,
                        color: SariSupplyColors.ink600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Text(
              '$done of $total stops delivered',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: SariSupplyColors.ink600,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? done / total : 0,
                minHeight: 8,
                backgroundColor: SariSupplyColors.divider,
                valueColor: const AlwaysStoppedAnimation<Color>(
                    SariSupplyColors.orange500),
              ),
            ),
            if (_location != null &&
                [DeliveryRunStatus.dispatched, DeliveryRunStatus.inTransit]
                    .contains(run.status)) ...[
              const SizedBox(height: 8),
              _buildLocationRow(),
            ],
            const SizedBox(height: 16),
            const Divider(height: 1, color: SariSupplyColors.divider),
            if (next != null) ...[
              const SizedBox(height: 16),
              _buildNextStop(next),
            ] else ...[
              const SizedBox(height: 16),
              const Text(
                'All stops completed for this route.',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: SariSupplyColors.ink950,
                ),
              ),
            ],
            const SizedBox(height: 8),
            if (upNext.isNotEmpty) _buildUpNext(upNext),
            _buildCompletedRow(completed),
          ],
        ),
      ),
    );
  }

  Widget _buildRunSelector() {
    final run = _currentRun!;
    return InkWell(
      onTap: () => _showRunPicker(),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Delivery run: ${run.id}',
                style: const TextStyle(
                  fontSize: 14,
                  color: SariSupplyColors.ink600,
                ),
              ),
            ),
            const Icon(Icons.expand_more, color: SariSupplyColors.ink600),
          ],
        ),
      ),
    );
  }

  Future<void> _showRunPicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final run in _runs)
              ListTile(
                title: Text(run.id),
                subtitle: Text(
                    '${run.completedStops} of ${run.totalStops} stops delivered'),
                onTap: () => Navigator.of(ctx).pop(run.id),
              ),
          ],
        ),
      ),
    );
    if (selected != null && selected != _currentRun?.id) {
      setState(() {
        _currentRun = _runs.firstWhere((r) => r.id == selected);
        _showCompleted = false;
        _justCompletedStopId = null;
        _selectLocationRun();
      });
    }
  }

  Widget _buildLocationRow() {
    final controller = _location!;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final status = controller.busy
            ? 'Getting and sharing location\u2026'
            : !controller.enabled
                ? 'Location sharing stopped'
                : !controller.foreground
                    ? 'Location sharing paused'
                    : controller.error != null
                        ? 'Location update failed'
                        : 'Location sharing available';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Divider(height: 1, color: SariSupplyColors.divider),
            InkWell(
              onTap: controller.busy
                  ? null
                  : () {
                      if (controller.enabled) {
                        controller.stop();
                      } else {
                        unawaited(controller.start());
                      }
                    },
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        status,
                        style: const TextStyle(
                          fontSize: 14,
                          color: SariSupplyColors.ink600,
                        ),
                      ),
                    ),
                    Text(
                      controller.enabled ? 'Stop' : 'Share',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: SariSupplyColors.orange500,
                      ),
                    ),
                    if (controller.enabled) ...[
                      const SizedBox(width: 12),
                      InkWell(
                        onTap: controller.busy ? null : controller.updateNow,
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                          child: Text(
                            'Update',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: SariSupplyColors.orange500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNextStop(DeliveryStop next) {
    final cod = _codCentavos(next);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NEXT STOP',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: SariSupplyColors.orange500,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: SariSupplyColors.orange50,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                _stopNumber(next.sequence),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: SariSupplyColors.orange500,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    next.destinationName,
                    style: const TextStyle(
                      fontSize: 22,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: SariSupplyColors.ink950,
                    ),
                  ),
                  const SizedBox(height: 6),
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
                          next.destinationAddress,
                          style: const TextStyle(
                            fontSize: 14,
                            color: SariSupplyColors.ink600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    children: [
                      Text(
                        '${next.totalOrderedUnits} units',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: SariSupplyColors.ink950,
                        ),
                      ),
                      if (next.paymentMethod == 'qr') ...[
                        const Text('|',
                            style: TextStyle(color: SariSupplyColors.divider)),
                        const Text(
                          'QR · collect no cash',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: SariSupplyColors.ink950,
                          ),
                        ),
                      ] else if (cod > 0) ...[
                        const Text(
                          '|',
                          style: TextStyle(
                            fontSize: 16,
                            color: SariSupplyColors.divider,
                          ),
                        ),
                        Text(
                          _formatCod(cod),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: SariSupplyColors.ink950,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: SariSupplyColors.divider),
        InkWell(
          onTap: () => _openStopDetail(next),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const Row(
              children: [
                Expanded(
                  child: Text(
                    'View stop details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: SariSupplyColors.ink950,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: SariSupplyColors.ink600, size: 24),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: SariSupplyColors.divider),
      ],
    );
  }

  Widget _buildUpNext(List<DeliveryStop> upNext) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          'UP NEXT (${upNext.length})',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: SariSupplyColors.ink500,
          ),
        ),
        const SizedBox(height: 4),
        for (final stop in upNext) ...[
          InkWell(
            onTap: () => _openStopDetail(stop),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: SariSupplyColors.ink50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _stopNumber(stop.sequence),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: SariSupplyColors.ink950,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.destinationName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: SariSupplyColors.ink950,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stop.destinationAddress,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: SariSupplyColors.ink600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${stop.totalOrderedUnits} units',
                    style: const TextStyle(
                      fontSize: 14,
                      color: SariSupplyColors.ink600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right,
                      color: SariSupplyColors.ink600, size: 24),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: SariSupplyColors.divider),
        ],
      ],
    );
  }

  Widget _buildCompletedRow(List<DeliveryStop> completed) {
    return Column(
      children: [
        InkWell(
          onTap: completed.isEmpty
              ? null
              : () => setState(() => _showCompleted = !_showCompleted),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    color: SariSupplyColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Completed \u00B7 ${completed.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: SariSupplyColors.ink600,
                    ),
                  ),
                ),
                if (completed.isNotEmpty)
                  Icon(
                    _showCompleted ? Icons.expand_more : Icons.chevron_right,
                    color: SariSupplyColors.ink600,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
        if (_showCompleted)
          for (final stop in completed) ...[
            InkWell(
              onTap: () => _openStopDetail(stop),
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 40),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_stopNumber(stop.sequence)}  ${stop.destinationName}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: SariSupplyColors.ink950,
                            ),
                          ),
                          Text(
                            stop.destinationAddress,
                            maxLines: 1,
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
                        color: SariSupplyColors.ink600, size: 20),
                  ],
                ),
              ),
            ),
          ],
        const Divider(height: 1, color: SariSupplyColors.divider),
      ],
    );
  }

  Widget _buildStickyCta() {
    final state = _primaryState();
    final busy = _actionBusy || _isSyncing;
    return Container(
      color: SariSupplyColors.paper,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: busy ? null : _handlePrimary,
            icon: busy
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
