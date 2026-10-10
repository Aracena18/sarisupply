import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

import 'company_delivery_payment.dart';
import 'company_rider_stop_detail.dart';

/// Presentation of company-assigned work; callbacks retain company authority
/// and durable proof handling in the owning workspace.
class CompanyRiderRoute extends StatefulWidget {
  const CompanyRiderRoute({
    super.key,
    required this.companyName,
    required this.runs,
    required this.onRefresh,
    required this.onDirections,
    required this.onProof,
    this.onRecordProof,
    this.onRecordDelivery,
    this.onLoadStopProgress,
    this.onSaveStopProgress,
    this.loading = false,
    this.busy = false,
    this.actionsEnabled = true,
    this.error,
    this.notice,
    this.onRetrySync,
    this.onLoadMore,
    this.onSignOut,
    this.onExit,
  });

  final String companyName;
  final List<CompanyRecord> runs;
  final Future<void> Function() onRefresh;
  final void Function(Map<String, Object?> stop) onDirections;
  final void Function(CompanyRecord run, Map<String, Object?> stop) onProof;
  final Future<bool> Function(CompanyRecord run, Map<String, Object?> stop)?
  onRecordProof;
  final Future<bool> Function(
    CompanyRecord run,
    Map<String, Object?> stop,
    Map<String, Object?> delivery,
  )?
  onRecordDelivery;
  final Future<Map<String, Object?>?> Function(
    CompanyRecord run,
    Map<String, Object?> stop,
  )?
  onLoadStopProgress;
  final Future<bool> Function(
    CompanyRecord run,
    Map<String, Object?> stop,
    Map<String, Object?> progress,
  )?
  onSaveStopProgress;
  final bool loading, busy, actionsEnabled;
  final String? error, notice;
  final VoidCallback? onRetrySync, onLoadMore, onExit;
  final Future<void> Function()? onSignOut;

  @override
  State<CompanyRiderRoute> createState() => _CompanyRiderRouteState();
}

class _CompanyRiderRouteState extends State<CompanyRiderRoute> {
  String? _selectedRunId;
  final Set<String> _directionsOpened = {};
  final Set<String> _deliveryStarted = {};
  final Set<String> _itemsConfirmed = {};
  final Set<String> _paymentConfirmed = {};
  final Map<String, Map<String, Object?>> _progressByStop = {};
  String? _proofStopId;
  bool _showCompleted = false;
  int _progressGeneration = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreRunProgress());
  }

  @override
  void didUpdateWidget(covariant CompanyRiderRoute oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.runs, widget.runs)) {
      unawaited(_restoreRunProgress());
    }
  }

  String _progressKey(CompanyRecord run, Map<String, Object?> stop) =>
      '${run.id}:${_stopId(stop)}';

  List<CompanyRecord> _availableRuns() => widget.runs
      .where(
        (run) => const [
          'draft',
          'dispatched',
          'inTransit',
          'completed',
        ].contains(run.status),
      )
      .toList();

  CompanyRecord? _selectedRun() {
    final runs = _availableRuns();
    if (runs.isEmpty) return null;
    for (final run in runs) {
      if (run.id == _selectedRunId) return run;
    }
    for (final run in runs) {
      if (const ['dispatched', 'inTransit'].contains(run.status)) return run;
    }
    for (final run in runs) {
      if (run.status == 'draft') return run;
    }
    return runs.first;
  }

  Future<void> _restoreRunProgress() async {
    final load = widget.onLoadStopProgress;
    final run = _selectedRun();
    if (load == null || run == null || run.status == 'draft') return;
    final generation = ++_progressGeneration;
    final progressById = <String, Map<String, Object?>>{};
    for (final stop in run.records('stops')) {
      if (stop['proof'] != null) continue;
      try {
        final progress = await load(run, stop);
        if (progress != null) {
          progressById[_stopId(stop)] = progress;
        }
      } catch (_) {
        // The detail screen will surface a local-save error if the rider acts.
      }
    }
    if (!mounted || generation != _progressGeneration) return;
    setState(() {
      for (final stop in run.records('stops')) {
        final id = _stopId(stop);
        final key = _progressKey(run, stop);
        final progress = progressById[id];
        if (progress == null) {
          _progressByStop.remove(key);
          _applyProgress(id, const {});
        } else {
          _progressByStop[key] = progress;
          _applyProgress(id, progress);
        }
      }
    });
  }

  void _applyProgress(String id, Map<String, Object?> progress) {
    if (progress['directionsOpened'] == true) {
      _directionsOpened.add(id);
    } else {
      _directionsOpened.remove(id);
    }
    if (progress['deliveryStarted'] == true) {
      _deliveryStarted.add(id);
    } else {
      _deliveryStarted.remove(id);
    }
    if (progress['itemsConfirmed'] == true) {
      _itemsConfirmed.add(id);
    } else {
      _itemsConfirmed.remove(id);
    }
    if (progress['paymentConfirmed'] == true) {
      _paymentConfirmed.add(id);
    } else {
      _paymentConfirmed.remove(id);
    }
  }

  Map<String, Object?> _progressAtStep(
    CompanyRecord run,
    Map<String, Object?> stop,
    int step,
  ) {
    final current = _progressByStop[_progressKey(run, stop)] ?? const {};
    final hasCashDue =
        companyDeliveryPaymentMethod(stop) == companyCashOnDelivery &&
        stop['amountDueCentavos'] is num &&
        (stop['amountDueCentavos'] as num) > 0;
    return {
      ...current,
      'version': 1,
      'step': step,
      'directionsOpened': step >= 1,
      'deliveryStarted': step >= 2,
      'itemsConfirmed': step >= 3 || (stop['items'] as List? ?? []).isEmpty,
      'paymentConfirmed': hasCashDue && step >= 4,
    };
  }

  Future<bool> _saveProgress(
    CompanyRecord run,
    Map<String, Object?> stop,
    Map<String, Object?> progress,
  ) async {
    try {
      final save = widget.onSaveStopProgress;
      if (save != null && !await save(run, stop, progress)) return false;
      if (!mounted) return true;
      setState(() {
        _progressByStop[_progressKey(run, stop)] = progress;
        _applyProgress(_stopId(stop), progress);
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _account() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.companyName,
              style: SariSupplyTypography.sectionHeading,
            ),
            if (widget.onExit != null)
              TextButton(
                onPressed: widget.busy
                    ? null
                    : () {
                        Navigator.pop(context);
                        widget.onExit!();
                      },
                child: const Text('Choose workspace'),
              ),
            if (widget.onSignOut != null)
              OutlinedButton(
                onPressed: widget.busy
                    ? null
                    : () {
                        Navigator.pop(context);
                        widget.onSignOut!();
                      },
                child: const Text('Sign out'),
              ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final runs = _availableRuns();
    final run = _selectedRun();
    final stops = run?.records('stops').toList() ?? <Map<String, Object?>>[];
    stops.sort(
      (a, b) => (a['sequence'] as int).compareTo(b['sequence'] as int),
    );
    final remaining = stops.where((s) => s['proof'] == null).toList();
    final completed = stops.where((s) => s['proof'] != null).toList();
    final next = remaining.isEmpty ? null : remaining.first;
    final awaitingDispatch = run?.status == 'draft';
    final enabled =
        widget.actionsEnabled &&
        !widget.busy &&
        !widget.loading &&
        !awaitingDispatch;
    final padding = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;
    return Scaffold(
      backgroundColor: SariSupplyColors.paper,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(padding, 8, padding, 8),
                  child: Row(
                    children: [
                      const SariSupplySymbol(size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'My Route',
                              style: SariSupplyTypography.cardHeading,
                            ),
                            Text(
                              widget.companyName,
                              style: SariSupplyTypography.body.copyWith(
                                color: SariSupplyColors.ink600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh assignments',
                        onPressed: widget.busy || widget.loading
                            ? null
                            : widget.onRefresh,
                        icon: const Icon(Icons.refresh),
                      ),
                      IconButton(
                        tooltip: 'Rider account',
                        onPressed: _account,
                        icon: const Icon(Icons.person_outline),
                      ),
                    ],
                  ),
                ),
                if (widget.loading || widget.busy)
                  const LinearProgressIndicator(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: widget.onRefresh,
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        padding,
                        16,
                        padding,
                        padding,
                      ),
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (widget.error != null)
                          _statusStrip(widget.error!, error: true),
                        if (widget.notice != null)
                          _statusStrip(
                            widget.notice!,
                            retry: widget.onRetrySync != null,
                          ),
                        if (run == null && widget.loading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 32),
                            child: Text(
                              'Loading your route…',
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if (run == null && !widget.loading) ...[
                          const SizedBox(height: 32),
                          const Icon(
                            Icons.route_outlined,
                            size: 48,
                            color: SariSupplyColors.ink600,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No active deliveries',
                            style: SariSupplyTypography.sectionHeading,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Your assigned runs will appear here after dispatch.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                        if (run != null) ...[
                          if (runs.length > 1) ...[
                            _runPicker(runs, run),
                            const SizedBox(height: 16),
                          ],
                          _routeSummary(run, stops.length, completed.length),
                          const SizedBox(height: 24),
                          if (next != null)
                            Card(
                              margin: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  SariSupplyRadii.md,
                                ),
                                side: const BorderSide(
                                  color: SariSupplyColors.orange100,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Next stop',
                                                style: SariSupplyTypography
                                                    .label
                                                    .copyWith(
                                                      color: SariSupplyColors
                                                          .orange700,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              (next['sequence'] as int? ?? 0)
                                                  .toString()
                                                  .padLeft(2, '0'),
                                              style: SariSupplyTypography.label
                                                  .copyWith(
                                                    color:
                                                        SariSupplyColors.ink600,
                                                  ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        _nextStop(next),
                                      ],
                                    ),
                                  ),
                                  const Divider(height: 1),
                                  InkWell(
                                    onTap: widget.busy || widget.loading
                                        ? null
                                        : () => _openStopDetails(
                                            run,
                                            next,
                                            stops.length,
                                          ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      child: ConstrainedBox(
                                        constraints: const BoxConstraints(
                                          minHeight: 24,
                                        ),
                                        child: const Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'View stop details',
                                                style:
                                                    SariSupplyTypography.label,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Icon(
                                              Icons.chevron_right,
                                              color: SariSupplyColors.ink600,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            Icon(
                              stops.isEmpty
                                  ? Icons.route_outlined
                                  : Icons.task_alt,
                              size: 40,
                              color: stops.isEmpty
                                  ? SariSupplyColors.ink600
                                  : SariSupplyColors.success,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              stops.isEmpty
                                  ? 'No stops assigned'
                                  : 'All stops recorded',
                              style: SariSupplyTypography.cardHeading,
                              textAlign: TextAlign.center,
                            ),
                          ],
                          if (remaining.length > 1) ...[
                            const SizedBox(height: 24),
                            const Text(
                              'Up next',
                              style: SariSupplyTypography.cardHeading,
                            ),
                            const SizedBox(height: 8),
                            for (final stop in remaining.skip(1))
                              _upNextStop(stop),
                          ],
                          const SizedBox(height: 16),
                          InkWell(
                            onTap: completed.isEmpty
                                ? null
                                : () => setState(
                                    () => _showCompleted = !_showCompleted,
                                  ),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.task_alt,
                                    size: 20,
                                    color: SariSupplyColors.success,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Recorded stops · ${completed.length}',
                                      style: SariSupplyTypography.label
                                          .copyWith(
                                            color: SariSupplyColors.ink600,
                                          ),
                                    ),
                                  ),
                                  if (completed.isNotEmpty)
                                    Icon(
                                      _showCompleted
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: SariSupplyColors.ink600,
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (_showCompleted)
                            for (final stop in completed) _completedStop(stop),
                        ],
                        if (widget.onLoadMore != null)
                          TextButton(
                            onPressed: widget.busy ? null : widget.onLoadMore,
                            child: const Text('Load more runs'),
                          ),
                      ],
                    ),
                  ),
                ),
                if (run != null)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(padding, 12, padding, padding),
                    decoration: const BoxDecoration(
                      color: SariSupplyColors.card,
                      border: Border(
                        top: BorderSide(color: SariSupplyColors.divider),
                      ),
                    ),
                    child: FilledButton.icon(
                      onPressed: enabled
                          ? () => _handlePrimary(run, next, completed)
                          : null,
                      icon: widget.busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: SariSupplyColors.ink950,
                              ),
                            )
                          : Icon(
                              awaitingDispatch
                                  ? Icons.schedule_outlined
                                  : next == null
                                  ? Icons.flag_outlined
                                  : _directionsOpened.contains(_stopId(next))
                                  ? Icons.checklist_outlined
                                  : Icons.near_me_outlined,
                            ),
                      label: Text(
                        _primaryLabel(run, next, completed),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(56),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _routeSummary(CompanyRecord run, int total, int recorded) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Assigned route',
        style: SariSupplyTypography.label.copyWith(
          color: SariSupplyColors.ink600,
        ),
      ),
      const SizedBox(height: 4),
      Text(_routeName(run), style: SariSupplyTypography.bodyLarge),
      if (run.string('vehicleInfo').trim().isNotEmpty) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.local_shipping_outlined,
              size: 18,
              color: SariSupplyColors.ink600,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                run.string('vehicleInfo'),
                style: SariSupplyTypography.body.copyWith(
                  color: SariSupplyColors.ink600,
                ),
              ),
            ),
          ],
        ),
      ],
      const SizedBox(height: 12),
      Text(
        '$recorded of $total stops recorded',
        style: SariSupplyTypography.label,
      ),
      const SizedBox(height: 8),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: total == 0 ? 0 : recorded / total,
          minHeight: 6,
          backgroundColor: SariSupplyColors.divider,
          color: SariSupplyColors.success,
        ),
      ),
    ],
  );

  Widget _statusStrip(
    String message, {
    bool error = false,
    bool retry = false,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: error
          ? SariSupplyColors.error.withValues(alpha: 0.08)
          : SariSupplyColors.ink50,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(
          error ? Icons.error_outline : Icons.cloud_outlined,
          size: 20,
          color: error ? SariSupplyColors.error : SariSupplyColors.ink600,
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
        if (retry && widget.onRetrySync != null)
          TextButton(
            onPressed: widget.busy ? null : widget.onRetrySync,
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: SariSupplyColors.orange700,
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    ),
  );

  Widget _runPicker(List<CompanyRecord> runs, CompanyRecord selected) =>
      DropdownButtonFormField<String>(
        initialValue: selected.id,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Delivery run'),
        items: [
          for (final run in runs)
            DropdownMenuItem(value: run.id, child: Text(_routeName(run))),
        ],
        onChanged: widget.busy || widget.loading ? null : _selectRun,
      );

  void _selectRun(String? id) {
    setState(() {
      _selectedRunId = id;
      _directionsOpened.clear();
      _deliveryStarted.clear();
      _itemsConfirmed.clear();
      _paymentConfirmed.clear();
      _proofStopId = null;
      _showCompleted = false;
    });
    unawaited(_restoreRunProgress());
  }

  String _routeName(CompanyRecord run) {
    final name = run.string('routeName').trim();
    if (name.isNotEmpty) return name;
    final stops = run.records('stops').toList()
      ..sort((a, b) => (a['sequence'] as int).compareTo(b['sequence'] as int));
    final destinations = stops
        .map((stop) => stop['destinationName']?.toString().trim() ?? '')
        .where((stop) => stop.isNotEmpty)
        .toList();
    if (destinations.length == 1) return '${destinations.single} route';
    if (destinations.length > 1) {
      return '${destinations.first} \u2192 ${destinations.last}';
    }
    return 'Delivery route';
  }

  String _stopId(Map<String, Object?> stop) => stop['id']?.toString() ?? '';

  int _stopUnits(Map<String, Object?> stop) =>
      (stop['items'] as List? ?? const []).fold<int>(
        0,
        (sum, raw) => sum + ((raw as Map)['quantityOrdered'] as int? ?? 0),
      );

  int? _stopAmountDue(Map<String, Object?> stop) {
    final due = stop['amountDueCentavos'];
    if (due is! num) return null;
    return due.toInt().clamp(0, 1 << 52).toInt();
  }

  bool _hasItems(Map<String, Object?> stop) =>
      (stop['items'] as List? ?? const []).isNotEmpty;

  bool _needsCashCollection(Map<String, Object?> stop) =>
      companyDeliveryPaymentMethod(stop) == companyCashOnDelivery &&
      (_stopAmountDue(stop) == null || _stopAmountDue(stop)! > 0);

  String? _stopPaymentLabel(Map<String, Object?> stop) {
    final method = companyDeliveryPaymentMethod(stop);
    final due = _stopAmountDue(stop);
    if (method == companyCashOnDelivery) {
      if (due == null) return 'COD amount unavailable';
      if (due == 0) return null;
      return 'COD ${_peso(due)}';
    }
    if (method == companyQrPayment) {
      if (due == null) return 'QR status unavailable';
      return due == 0 ? 'QR payment confirmed' : 'QR payment pending';
    }
    return due == null ? null : 'Payment details unavailable';
  }

  String _primaryLabel(
    CompanyRecord run,
    Map<String, Object?>? next,
    List<Map<String, Object?>> completed,
  ) {
    if (run.status == 'draft') return 'Awaiting dispatch';
    if (next == null) return 'Finish route';
    if (_proofStopId != null &&
        completed.any((stop) => _stopId(stop) == _proofStopId)) {
      return 'Next stop';
    }
    final id = _stopId(next);
    if (!_directionsOpened.contains(id)) return 'Open directions';
    if (!_deliveryStarted.contains(id)) return 'Start delivery';
    if (_hasItems(next) && !_itemsConfirmed.contains(id)) {
      return 'Confirm items';
    }
    if (_needsCashCollection(next) && !_paymentConfirmed.contains(id)) {
      if (_stopAmountDue(next) == null) return 'Check payment details';
      return 'Confirm collection';
    }
    return 'Record proof';
  }

  Future<void> _handlePrimary(
    CompanyRecord run,
    Map<String, Object?>? next,
    List<Map<String, Object?>> completed,
  ) async {
    if (run.status == 'draft') return;
    if (next == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Route completed.')));
      return;
    }
    final id = _stopId(next);
    if (_proofStopId != null &&
        completed.any((stop) => _stopId(stop) == _proofStopId)) {
      _proofStopId = null;
      final id = _stopId(next);
      _deliveryStarted.remove(id);
      _itemsConfirmed.remove(id);
      _paymentConfirmed.remove(id);
      if (!await _saveProgress(run, next, _progressAtStep(run, next, 1))) {
        return;
      }
      widget.onDirections(next);
      setState(() {});
      return;
    }
    if (!_directionsOpened.contains(id)) {
      if (!await _saveProgress(run, next, _progressAtStep(run, next, 1))) {
        return;
      }
      widget.onDirections(next);
      setState(() {});
      return;
    }
    if (!_deliveryStarted.contains(id)) {
      if (!await _saveProgress(run, next, _progressAtStep(run, next, 2))) {
        return;
      }
      setState(() {});
      return;
    }
    await _openStopDetails(run, next, run.records('stops').length);
  }

  Future<void> _openStopDetails(
    CompanyRecord run,
    Map<String, Object?> stop,
    int stopCount,
  ) async {
    final id = _stopId(stop);
    final key = _progressKey(run, stop);
    var initialProgress = _progressByStop[key];
    final loadProgress = widget.onLoadStopProgress;
    if (initialProgress == null && loadProgress != null) {
      try {
        initialProgress = await loadProgress(run, stop);
      } catch (_) {
        initialProgress = null;
      }
    }
    if (initialProgress != null) {
      _progressByStop[key] = initialProgress;
      _applyProgress(id, initialProgress);
    }
    if (!mounted) return;
    final completedHere = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CompanyRiderStopDetail(
          stop: stop,
          stopCount: stopCount,
          awaitingDispatch: run.status == 'draft',
          busy: widget.busy,
          actionsEnabled: widget.actionsEnabled,
          directionsOpened: _directionsOpened.contains(id),
          deliveryStarted: _deliveryStarted.contains(id),
          itemsConfirmed: _itemsConfirmed.contains(id),
          paymentConfirmed: _paymentConfirmed.contains(id),
          initialProgress: initialProgress ?? const {},
          onSaveProgress: (progress) => _saveProgress(run, stop, progress),
          onDirections: () {
            _directionsOpened.add(id);
            widget.onDirections(stop);
            if (mounted) setState(() {});
          },
          onDeliveryStarted: () {
            _deliveryStarted.add(id);
            if (mounted) setState(() {});
          },
          onItemsConfirmed: () {
            _itemsConfirmed.add(id);
            if (mounted) setState(() {});
          },
          onPaymentConfirmed: () {
            _paymentConfirmed.add(id);
            if (mounted) setState(() {});
          },
          onProof: () async {
            final recordProof = widget.onRecordProof;
            if (recordProof == null) {
              widget.onProof(run, stop);
              return false;
            }
            return recordProof(run, stop);
          },
          onRecordDelivery: (delivery) async {
            final recordDelivery = widget.onRecordDelivery;
            if (recordDelivery != null) {
              return recordDelivery(run, stop, delivery);
            }
            final recordProof = widget.onRecordProof;
            if (recordProof == null) {
              widget.onProof(run, stop);
              return false;
            }
            return recordProof(run, stop);
          },
        ),
      ),
    );
    if (!mounted) return;
    if (completedHere == true) {
      _proofStopId = id;
      _progressByStop.remove(key);
      _directionsOpened.remove(id);
      _deliveryStarted.remove(id);
      _itemsConfirmed.remove(id);
      _paymentConfirmed.remove(id);
    }
    setState(() {});
  }

  Widget _nextStop(Map<String, Object?> stop) {
    final paymentLabel = _stopPaymentLabel(stop);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${stop['destinationName'] ?? 'Store'}',
          style: SariSupplyTypography.sectionHeading,
        ),
        if (stop['destinationAddress']?.toString().trim().isNotEmpty ==
            true) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 18,
                color: SariSupplyColors.ink600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${stop['destinationAddress']}',
                  style: SariSupplyTypography.body.copyWith(
                    color: SariSupplyColors.ink600,
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            Text(
              '${_stopUnits(stop)} units',
              style: SariSupplyTypography.label,
            ),
            if (paymentLabel != null)
              Text(paymentLabel, style: SariSupplyTypography.label),
          ],
        ),
        if (stop['localPending'] == true) ...[
          const SizedBox(height: 8),
          Text(
            'Saved on this phone · Waiting to sync',
            style: SariSupplyTypography.body.copyWith(
              color: SariSupplyColors.ink600,
            ),
          ),
        ],
        if (paymentLabel == 'Payment details unavailable') ...[
          const SizedBox(height: 8),
          Text(
            'Check with warehouse operations before collecting cash.',
            style: SariSupplyTypography.body.copyWith(
              color: SariSupplyColors.orange700,
            ),
          ),
        ],
      ],
    );
  }

  Widget _upNextStop(Map<String, Object?> stop) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SariSupplyColors.ink50,
                borderRadius: BorderRadius.circular(SariSupplyRadii.sm),
              ),
              alignment: Alignment.center,
              child: Text(
                (stop['sequence'] as int? ?? 0).toString().padLeft(2, '0'),
                style: SariSupplyTypography.label,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${stop['destinationName'] ?? 'Store'}',
                    style: SariSupplyTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${stop['destinationAddress'] ?? ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: SariSupplyTypography.body.copyWith(
                      color: SariSupplyColors.ink600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_stopUnits(stop)} units',
                    style: SariSupplyTypography.body.copyWith(
                      color: SariSupplyColors.ink600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const Divider(height: 1, color: SariSupplyColors.divider),
    ],
  );

  Widget _completedStop(Map<String, Object?> stop) => Padding(
    padding: const EdgeInsets.only(left: 32, top: 8, bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${(stop['sequence'] as int? ?? 0).toString().padLeft(2, '0')}  ${stop['destinationName']}',
          style: SariSupplyTypography.label,
        ),
        const SizedBox(height: 4),
        Text(
          stop['status'] == 'partiallyDelivered'
              ? 'Partial delivery recorded'
              : stop['status'] == 'failed'
              ? 'Delivery failed'
              : 'Proof recorded',
          style: SariSupplyTypography.body.copyWith(
            color: SariSupplyColors.ink600,
          ),
        ),
        if (stop['localPending'] == true) ...[
          const SizedBox(height: 4),
          Text(
            'Saved on this phone · Waiting to sync',
            style: SariSupplyTypography.body.copyWith(
              color: SariSupplyColors.ink600,
            ),
          ),
        ],
      ],
    ),
  );
}

String _peso(int cents) => '₱${(cents / 100).toStringAsFixed(2)}';
