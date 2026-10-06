import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';

class OwnerDispatchScreen extends StatefulWidget {
  const OwnerDispatchScreen(
      {super.key,
      required this.merchantId,
      required this.warehouseId,
      required this.warehouseName});
  final String merchantId, warehouseId, warehouseName;
  @override
  State<OwnerDispatchScreen> createState() => _OwnerDispatchScreenState();
}

class _OwnerDispatchScreenState extends State<OwnerDispatchScreen> {
  final _vehicle = TextEditingController();
  final _selectedPackages = <String>{};
  List<Map<String, dynamic>> _drivers = [],
      _packages = [],
      _runs = [],
      _returns = [];
  String? _driverId, _error;
  bool _busy = false, _hasMore = false;
  DeliveryRun? _savedAttempt;
  DeliveryFunctions get _gateway => DeliveryFunctions.forHuman();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _vehicle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await _gateway.dispatchWorkspace(
          widget.merchantId, widget.warehouseId);
      List<Map<String, dynamic>> records(String key) => (page[key] as List)
          .map((v) => Map<String, dynamic>.from(v as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _drivers = records('drivers');
        _packages = records('manifests');
        _runs = records('runs');
        _returns = records('returns');
        _hasMore = page['hasMore'] as bool;
        if (!_drivers.any((d) => d['id'] == _driverId)) _driverId = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _assignDriver() async {
    final id = TextEditingController(), name = TextEditingController();
    String? error;
    bool saving = false;
    await showSariSupplyForm<void>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => SariSupplyFormSurface(
                title: 'Assign a driver',
                actions: [
                  TextButton(
                      onPressed: saving ? null : () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (id.text.trim().isEmpty ||
                                  name.text.trim().isEmpty) {
                                update(() => error =
                                    'Enter the driver access ID and name');
                                return;
                              }
                              update(() => saving = true);
                              try {
                                await _gateway.assignDriver(
                                    widget.merchantId,
                                    id.text.trim(),
                                    name.text.trim(),
                                    widget.warehouseId);
                                if (context.mounted) Navigator.pop(context);
                              } catch (e) {
                                if (context.mounted) {
                                  update(
                                      () => error = operationErrorMessage(e));
                                }
                              } finally {
                                if (context.mounted) {
                                  update(() => saving = false);
                                }
                              }
                            },
                      child: Text(saving ? 'Saving…' : 'Assign driver')),
                ],
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                          'Ask the driver to copy their access ID from the Driver app after Google sign-in.'),
                      const SizedBox(height: 16),
                      TextField(
                          controller: id,
                          enabled: !saving,
                          decoration: const InputDecoration(
                              labelText: 'Driver access ID')),
                      const SizedBox(height: 16),
                      TextField(
                          controller: name,
                          enabled: !saving,
                          decoration:
                              const InputDecoration(labelText: 'Driver name')),
                      if (error != null)
                        SariSupplyStatus(message: error!, error: true),
                    ]))));
    id.dispose();
    name.dispose();
    if (mounted) await _refresh();
  }

  Future<void> _createRoute() async {
    if (_busy) return;
    if (_savedAttempt == null) {
      final driver = _drivers.where((d) => d['id'] == _driverId).firstOrNull;
      final packages =
          _packages.where((p) => _selectedPackages.contains(p['id'])).toList();
      if (driver == null ||
          packages.isEmpty ||
          packages.length > 20 ||
          _vehicle.text.trim().isEmpty) {
        setState(() => _error =
            'Select a driver, up to 20 packed packages, and enter the vehicle');
        return;
      }
      final runId = const Uuid().v4();
      _savedAttempt = DeliveryRun(
          id: runId,
          driverId: driver['id'] as String,
          driverName: driver['driverName'] as String,
          vehicleInfo: _vehicle.text.trim(),
          warehouseId: widget.warehouseId,
          createdAt: DateTime.now(),
          stops: packages.indexed.map((entry) {
            final (index, p) = entry;
            return DeliveryStop(
                id: const Uuid().v4(),
                deliveryRunId: runId,
                sequence: index + 1,
                destinationId: p['destinationId'] as String,
                destinationName: p['destinationName'] as String,
                destinationAddress: p['destinationAddress'] as String,
                packageManifestId: p['id'] as String,
                items: (p['items'] as List).map((raw) {
                  final item = Map<String, dynamic>.from(raw as Map);
                  return DeliveryStopItem(
                      productId: item['productId'] as String,
                      productName: item['productName'] as String,
                      sku: item['sku'] as String,
                      quantityOrdered: item['quantityOrdered'] as int,
                      unitCostCentavos: item['unitCostCentavos'] as int);
                }).toList());
          }).toList());
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _gateway.createRun(widget.merchantId, _savedAttempt!);
      if (!mounted) return;
      setState(() {
        _savedAttempt = null;
        _selectedPackages.clear();
        _vehicle.clear();
      });
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && _savedAttempt == null) await _refresh();
  }

  Future<void> _dispatch(Map<String, dynamic> run) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Dispatch this route?'),
                content: Text(
                    'Release these packed packages to ${run['driverName']} in ${run['vehicleInfo']}. The driver will receive this route.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Dispatch'))
                ]));
    if (confirmed != true || !mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _gateway.dispatchRun(widget.merchantId, run['id'] as String);
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && _error == null) await _refresh();
  }

  Future<void> _receiveReturn(Map<String, dynamic> record) async {
    final disposition = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Confirm returned goods received'),
                content: const Text(
                    'Confirm the goods are physically back in the warehouse. Quarantine damaged or uncertain goods. Restock only sellable goods.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  TextButton(
                      onPressed: () => Navigator.pop(context, 'quarantine'),
                      child: const Text('Quarantine')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, 'restock'),
                      child: const Text('Restock'))
                ]));
    if (disposition == null || !mounted || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final id = record['id'] as String;
      final operationId = const Uuid()
          .v5(Namespace.url.value, 'warehouse-return:${widget.merchantId}:$id');
      await _gateway.receiveReturns(
          widget.merchantId, id, operationId, disposition);
    } catch (error) {
      if (mounted) setState(() => _error = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted && _error == null) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final locked = _busy || _savedAttempt != null;
    return Scaffold(
        appBar: sariSupplyTaskAppBar(context,
            title: 'Dispatch · ${widget.warehouseName}'),
        body: SariSupplyPageContent(
            maxWidth: 700,
            child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    children: [
                      if (_busy) const LinearProgressIndicator(),
                      if (_error != null)
                        SariSupplyStatus(message: _error!, error: true),
                      if (_hasMore)
                        const SariSupplyStatus(
                            message:
                                'This workspace shows the first 50 records in each queue.'),
                      TextButton.icon(
                          onPressed: locked ? null : _assignDriver,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Assign a driver')),
                      DropdownButtonFormField<String>(
                          initialValue: _driverId,
                          isExpanded: true,
                          decoration:
                              const InputDecoration(labelText: 'Driver'),
                          items: _drivers
                              .map((d) => DropdownMenuItem(
                                  value: d['id'] as String,
                                  child: Text(d['driverName'] as String)))
                              .toList(),
                          onChanged: locked
                              ? null
                              : (value) => setState(() => _driverId = value)),
                      const SizedBox(height: 16),
                      TextField(
                          controller: _vehicle,
                          enabled: !locked,
                          decoration: const InputDecoration(
                              labelText: 'Vehicle / plate')),
                      const SizedBox(height: 16),
                      Text('Packed packages',
                          style: Theme.of(context).textTheme.titleMedium),
                      if (_packages.isEmpty)
                        const SariSupplyStatus(
                            message:
                                'No packed packages available. Sync completed packing first.'),
                      for (final package in _packages)
                        Builder(builder: (context) {
                          final items = package['items'] as List;
                          final ready = items.isNotEmpty &&
                              items.every((raw) =>
                                  (raw as Map)['unitCostCentavos'] is int) &&
                              (package['destinationAddress'] as String)
                                  .isNotEmpty;
                          return CheckboxListTile(
                              title: Text(package['destinationName'] as String),
                              subtitle: Text(ready
                                  ? '${package['packageCode']} · ${items.length} products'
                                  : 'Purchase cost or destination address is missing'),
                              value: _selectedPackages.contains(package['id']),
                              onChanged: locked || !ready
                                  ? null
                                  : (value) => setState(() {
                                        if (value == true) {
                                          _selectedPackages
                                              .add(package['id'] as String);
                                        } else {
                                          _selectedPackages
                                              .remove(package['id']);
                                        }
                                      }));
                        }),
                      FilledButton(
                          onPressed: _busy ? null : _createRoute,
                          child: Text(_savedAttempt == null
                              ? 'Create route'
                              : 'Retry saved route')),
                      const SizedBox(height: 24),
                      Text('Current routes',
                          style: Theme.of(context).textTheme.titleMedium),
                      if (_runs.isEmpty) const Text('No current routes'),
                      for (final run in _runs)
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                          '${run['driverName']} · ${run['vehicleInfo']}'),
                                      Text(
                                          '${run['status']} · ${(run['stops'] as List).length} stops'),
                                      if (run['status'] == 'draft')
                                        FilledButton(
                                            onPressed: _busy
                                                ? null
                                                : () => _dispatch(run),
                                            child:
                                                const Text('Dispatch route')),
                                    ]))),
                      const SizedBox(height: 24),
                      Text('Returns awaiting receipt',
                          style: Theme.of(context).textTheme.titleMedium),
                      if (_returns.isEmpty)
                        const Text('No returns awaiting receipt'),
                      for (final record in _returns)
                        Card(
                            child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      for (final raw in record['items'] as List)
                                        Text(
                                            '${(raw as Map)['productId']} · ${raw['quantity']} units · ${raw['reason']}'),
                                      FilledButton(
                                          onPressed: _busy
                                              ? null
                                              : () => _receiveReturn(record),
                                          child: const Text(
                                              'Receive returned goods')),
                                    ]))),
                    ]))));
  }
}
