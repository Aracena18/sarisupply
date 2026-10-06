import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import '../data/procurement_workspace.dart';
import 'owner_dispatch_screen.dart';

class WarehouseFulfillmentScreen extends StatefulWidget {
  const WarehouseFulfillmentScreen({
    super.key,
    required this.store,
    this.staffId,
    this.onFulfillmentUpdated,
  });

  final InventoryStore store;
  final String? staffId;
  final VoidCallback? onFulfillmentUpdated;

  @override
  State<WarehouseFulfillmentScreen> createState() =>
      _WarehouseFulfillmentScreenState();
}

class _WarehouseFulfillmentScreenState extends State<WarehouseFulfillmentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<RestockProposal> _proposals = [];
  List<PurchaseOrder> _purchaseOrders = [];
  List<Warehouse> _warehouses = [];
  Warehouse? _selectedWarehouse;
  List<WarehouseStock> _warehouseStock = [];
  Map<String, String> _productNames = {};

  bool _loading = false;
  String? _actorId;
  bool _ownerVerified = false;
  Set<String> _canonicalProposalIds = {};
  Set<String> _canonicalPurchaseOrderIds = {};
  Set<String> _canonicalWarehouseIds = {};
  String? _statusMessage;
  String? _errorMessage;
  String _fulfillmentFilter = 'all'; // all, approved, picking, packed

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      try {
        final page =
            await refreshProcurementWorkspace(widget.store, 'purchaseOrders');
        _ownerVerified =
            page['canManagePurchasing'] == true && page['pendingCount'] == 0;
        _actorId = page['actorId'] as String;
        final proposalsPage =
            await refreshProcurementWorkspace(widget.store, 'restockProposals');
        final warehousesPage =
            await refreshProcurementWorkspace(widget.store, 'warehouses');
        _canonicalPurchaseOrderIds = _recordIds(page);
        _canonicalProposalIds = _recordIds(proposalsPage);
        _canonicalWarehouseIds = _recordIds(warehousesPage);
        if ((page['pendingCount'] as int) > 0) {
          _statusMessage =
              'Saved locally · Purchasing sync pending or needs review';
        }
      } catch (error) {
        _ownerVerified = false;
        _errorMessage = operationErrorMessage(error);
      }
      final proposals = await widget.store.listRestockProposals();
      final pos = await widget.store.listPurchaseOrders();
      final cachedWarehouses =
          await widget.store.listWarehouses(activeOnly: false);
      final warehouses = _ownerVerified
          ? cachedWarehouses
              .where((w) => w.active && _canonicalWarehouseIds.contains(w.id))
              .toList()
          : cachedWarehouses;

      final selectedWh = warehouses.isEmpty
          ? null
          : _selectedWarehouse != null
              ? warehouses.firstWhere((w) => w.id == _selectedWarehouse!.id,
                  orElse: () => warehouses.first)
              : warehouses.first;
      if (selectedWh != null && _ownerVerified) {
        await refreshProcurementWorkspace(widget.store, 'warehouseStock',
            warehouseId: selectedWh.id);
      }
      final stock = selectedWh == null
          ? <WarehouseStock>[]
          : await widget.store.listWarehouseStock(selectedWh.id);

      // Load product names for display
      final rows = await widget.store.search('');
      final names = <String, String>{};
      for (final r in rows) {
        names[r.product.id] = r.product.name;
      }

      if (mounted) {
        setState(() {
          _proposals = proposals;
          _purchaseOrders = pos;
          _warehouses = warehouses;
          _selectedWarehouse = selectedWh;
          _warehouseStock = stock;
          _productNames = names;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ownerVerified = false;
          _errorMessage = operationErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Set<String> _recordIds(Map<String, Object?> page) => {
        for (final record in page['records'] as List)
          (record as Map)['id'] as String,
      };

  bool _canFulfill(RestockProposal proposal) =>
      _ownerVerified &&
      _canonicalProposalIds.contains(proposal.id) &&
      _canonicalWarehouseIds.contains(proposal.warehouseId);

  Future<void> _selectWarehouse(Warehouse wh) async {
    setState(() {
      _selectedWarehouse = wh;
      _loading = true;
    });
    try {
      await refreshProcurementWorkspace(widget.store, 'warehouseStock',
          warehouseId: wh.id);
      final stock = await widget.store.listWarehouseStock(wh.id);
      if (mounted) {
        setState(() {
          _warehouseStock = stock;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _ownerVerified = false;
          _errorMessage = operationErrorMessage(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ==========================================
  // Pick & Pack Actions
  // ==========================================

  Future<void> _startPicking(RestockProposal proposal) async {
    if (_loading || !_canFulfill(proposal)) {
      setState(() => _errorMessage =
          'Connect to verify Owner access before changing warehouse stock.');
      return;
    }
    setState(() => _loading = true);
    try {
      await widget.store.startPicking(
        proposalId: proposal.id,
        pickerId: _actorId ?? widget.staffId ?? 'Pending verification',
      );
      if (mounted) {
        setState(() {
          _statusMessage =
              'Started picking Restock #${proposal.id.substring(0, proposal.id.length.clamp(0, 8))}';
        });
      }
      await _loadData();
      widget.onFulfillmentUpdated?.call();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = operationErrorMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openPickingDialog(RestockProposal proposal) async {
    if (_loading || !_canFulfill(proposal)) {
      setState(() => _errorMessage =
          'Connect to verify Owner access before changing warehouse stock.');
      return;
    }
    final Map<String, int> pickedQuantities = {};
    for (final line in proposal.lines) {
      pickedQuantities[line.productId] =
          line.pickedQuantity > 0 ? line.pickedQuantity : line.approvedQuantity;
    }

    final confirmed = await showSariSupplyForm<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final allValid = proposal.lines.every((l) {
            final qty = pickedQuantities[l.productId] ?? 0;
            return qty >= 0 && qty <= l.approvedQuantity;
          });

          return SariSupplyFormSurface(
            title:
                'Pick Items - #${proposal.id.substring(0, proposal.id.length.clamp(0, 8))}',
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              OutlinedButton(
                onPressed: () {
                  setDialogState(() {
                    for (final l in proposal.lines) {
                      pickedQuantities[l.productId] = l.approvedQuantity;
                    }
                  });
                },
                child: const Text('Pick All Qty'),
              ),
              FilledButton(
                onPressed: allValid ? () => Navigator.of(ctx).pop(true) : null,
                child: const Text('Complete Picking'),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Warehouse: ${proposal.warehouseId}',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final line in proposal.lines) ...[
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _productNames[line.productId] ??
                                'Product: ${line.productId}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Approved quantity to pick: ${line.approvedQuantity}',
                            style: Theme.of(ctx).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              IconButton.outlined(
                                onPressed:
                                    (pickedQuantities[line.productId] ?? 0) > 0
                                        ? () {
                                            setDialogState(() {
                                              pickedQuantities[line.productId] =
                                                  (pickedQuantities[
                                                              line.productId] ??
                                                          0) -
                                                      1;
                                            });
                                          }
                                        : null,
                                icon: const Icon(Icons.remove),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  '${pickedQuantities[line.productId] ?? 0}',
                                  style: Theme.of(ctx).textTheme.titleMedium,
                                ),
                              ),
                              IconButton.outlined(
                                onPressed:
                                    (pickedQuantities[line.productId] ?? 0) <
                                            line.approvedQuantity
                                        ? () {
                                            setDialogState(() {
                                              pickedQuantities[line.productId] =
                                                  (pickedQuantities[
                                                              line.productId] ??
                                                          0) +
                                                      1;
                                            });
                                          }
                                        : null,
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        final updatedLines = proposal.lines.map((l) {
          return l.copyWith(
            pickedQuantity: pickedQuantities[l.productId] ?? l.approvedQuantity,
          );
        }).toList();

        await widget.store.completePicking(
          proposalId: proposal.id,
          pickedLines: updatedLines,
        );

        if (mounted) {
          setState(() {
            _statusMessage =
                'Picking completed for Restock #${proposal.id.substring(0, proposal.id.length.clamp(0, 8))}';
          });
        }
        await _loadData();
        widget.onFulfillmentUpdated?.call();
      } catch (e) {
        if (mounted) {
          setState(() => _errorMessage = operationErrorMessage(e));
        }
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    }
  }

  Future<void> _openPackingDialog(RestockProposal proposal) async {
    if (_loading || !_canFulfill(proposal)) {
      setState(() => _errorMessage =
          'Connect to verify Owner access before changing warehouse stock.');
      return;
    }
    final packageCodeController = TextEditingController(
      text:
          'PKG-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
    );
    final sealNotesController = TextEditingController(
      text: 'Verified & sealed by $_actorId',
    );

    final confirmed = await showSariSupplyForm<bool>(
      context: context,
      builder: (ctx) => SariSupplyFormSurface(
        title: 'Pack & Seal Manifest',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.verified),
            onPressed: () {
              if (packageCodeController.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(true);
              }
            },
            label: const Text('Confirm Pack & Seal'),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Order #${proposal.id.substring(0, proposal.id.length.clamp(0, 8))} · Branch: ${proposal.branchId}',
              style: Theme.of(ctx).textTheme.titleSmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: packageCodeController,
              decoration: const InputDecoration(
                labelText: 'Package / Container Code *',
                prefixIcon: Icon(Icons.inventory_2),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: sealNotesController,
              decoration: const InputDecoration(
                labelText: 'Tamper Seal # / Security Notes',
                prefixIcon: Icon(Icons.security),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.primaryContainer.withAlpha(50),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Note: Sealing this package will deduct physical stock and clear reserved stock from warehouse ${proposal.warehouseId}.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      setState(() => _loading = true);
      try {
        await widget.store.completePacking(
          proposalId: proposal.id,
          packageCode: packageCodeController.text.trim(),
          sealNotes: sealNotesController.text.trim(),
        );

        if (mounted) {
          setState(() {
            _statusMessage = 'Saved locally · Packing sync pending';
          });
        }
        await _loadData();
        widget.onFulfillmentUpdated?.call();
      } catch (e) {
        if (mounted) {
          setState(() => _errorMessage = operationErrorMessage(e));
        }
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    }
  }

  // ==========================================
  // Supplier PO Receiving Action
  // ==========================================

  Future<void> _openReceivingDialog(
      PurchaseOrder po, PurchaseOrderLine line) async {
    if (_loading ||
        !_ownerVerified ||
        !_canonicalPurchaseOrderIds.contains(po.id) ||
        !_canonicalWarehouseIds.contains(po.warehouseId)) {
      setState(() => _errorMessage =
          'Connect to verify this purchase order and Owner access before receiving.');
      return;
    }
    final remaining = line.remainingQuantity;
    final qtyController = TextEditingController(text: remaining.toString());
    final batchController = TextEditingController();
    final expiryController = TextEditingController();

    final confirmed = await showSariSupplyForm<bool>(
      context: context,
      builder: (ctx) => SariSupplyFormSurface(
        title: 'Receive PO Item',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final qty = int.tryParse(qtyController.text.trim());
              if (qty != null && qty > 0) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Record Receiving'),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _productNames[line.productId] ?? 'Product: ${line.productId}',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'PO #${po.id.substring(0, po.id.length.clamp(0, 8))} · Warehouse: ${po.warehouseId}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Ordered: ${line.quantity} | Received: ${line.quantityReceived} | Remaining: $remaining',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qtyController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity Received Now *',
                prefixIcon: Icon(Icons.numbers),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: batchController,
              decoration: const InputDecoration(
                labelText: 'Batch Number (Optional)',
                prefixIcon: Icon(Icons.qr_code),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: expiryController,
              decoration: const InputDecoration(
                labelText: 'Expiry Date (YYYY-MM-DD, Optional)',
                prefixIcon: Icon(Icons.calendar_today),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final qty = int.tryParse(qtyController.text.trim()) ?? 0;
      if (qty <= 0) return;

      setState(() => _loading = true);
      try {
        await widget.store.recordSupplierReceiving(
          poId: po.id,
          productId: line.productId,
          quantityReceived: qty,
          batchNumber: batchController.text.trim().isEmpty
              ? null
              : batchController.text.trim(),
          expiryDate: expiryController.text.trim().isEmpty
              ? null
              : expiryController.text.trim(),
        );

        if (mounted) {
          setState(() {
            _statusMessage =
                'Received $qty units into warehouse ${po.warehouseId}';
          });
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          setState(() => _errorMessage = operationErrorMessage(e));
        }
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    }
  }

  // ==========================================
  // Stock Adjustment Action
  // ==========================================

  Future<void> _openStockAdjustmentDialog(WarehouseStock stock) async {
    if (!_ownerVerified) {
      setState(() => _errorMessage =
          'Connect to verify Owner access before changing warehouse stock.');
      return;
    }
    final deltaController = TextEditingController();
    String direction = 'add'; // 'add' or 'deduct'

    final confirmed = await showSariSupplyForm<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => SariSupplyFormSurface(
          title: 'Adjust Warehouse Stock',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final d = int.tryParse(deltaController.text.trim());
                if (d != null && d > 0) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Apply Adjustment'),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _productNames[stock.productId] ?? 'Product: ${stock.productId}',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Physical: ${stock.physicalQuantity} | Reserved: ${stock.reservedQuantity} | Available: ${stock.availableQuantity}',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'add',
                    label: Text('Add Stock (+)'),
                    icon: Icon(Icons.add),
                  ),
                  ButtonSegment(
                    value: 'deduct',
                    label: Text('Deduct Stock (-)'),
                    icon: Icon(Icons.remove),
                  ),
                ],
                selected: {direction},
                onSelectionChanged: (val) {
                  setDialogState(() => direction = val.first);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: deltaController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: direction == 'add'
                      ? 'Quantity to Add'
                      : 'Quantity to Deduct',
                  prefixIcon: Icon(direction == 'add'
                      ? Icons.add_circle
                      : Icons.remove_circle),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      final val = int.tryParse(deltaController.text.trim()) ?? 0;
      if (val <= 0) return;
      final delta = direction == 'add' ? val : -val;

      setState(() => _loading = true);
      try {
        await widget.store.adjustWarehouseStock(
          warehouseId: stock.warehouseId,
          productId: stock.productId,
          physicalDelta: delta,
        );
        if (mounted) {
          setState(() {
            _statusMessage = 'Stock updated for ${stock.productId}';
          });
        }
        await _selectWarehouse(_selectedWarehouse!);
      } catch (e) {
        if (mounted) {
          setState(() => _errorMessage = operationErrorMessage(e));
        }
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    }
  }

  // ==========================================
  // UI Builders
  // ==========================================

  Widget _buildFulfillmentTab() {
    final filtered = _proposals.where((p) {
      if (_fulfillmentFilter == 'approved') {
        return p.status == RestockProposalStatus.approved;
      }
      if (_fulfillmentFilter == 'picking') {
        return p.status == RestockProposalStatus.picking ||
            p.status == RestockProposalStatus.picked;
      }
      if (_fulfillmentFilter == 'packed') {
        return p.status == RestockProposalStatus.packed;
      }
      return [
        RestockProposalStatus.approved,
        RestockProposalStatus.picking,
        RestockProposalStatus.picked,
        RestockProposalStatus.packed,
      ].contains(p.status);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All Active'),
                  selected: _fulfillmentFilter == 'all',
                  onSelected: (s) => setState(() => _fulfillmentFilter = 'all'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Ready to Pick'),
                  selected: _fulfillmentFilter == 'approved',
                  onSelected: (s) =>
                      setState(() => _fulfillmentFilter = 'approved'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('In Picking'),
                  selected: _fulfillmentFilter == 'picking',
                  onSelected: (s) =>
                      setState(() => _fulfillmentFilter = 'picking'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Packed'),
                  selected: _fulfillmentFilter == 'packed',
                  onSelected: (s) =>
                      setState(() => _fulfillmentFilter = 'packed'),
                ),
              ],
            ),
          ),
        ),
        if (filtered.isEmpty)
          const Expanded(
            child: Center(
              child: SariSupplyStatus(
                message: 'No restock fulfillment orders match current filter.',
                icon: Icons.assignment_turned_in_outlined,
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final proposal = filtered[i];
                final totalUnits = proposal.lines.fold(
                  0,
                  (sum, l) =>
                      sum +
                      (proposal.status == RestockProposalStatus.picked ||
                              proposal.status == RestockProposalStatus.packed
                          ? l.pickedQuantity
                          : l.approvedQuantity),
                );

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Restock #${proposal.id.substring(0, proposal.id.length.clamp(0, 8))}',
                                style: Theme.of(ctx).textTheme.titleMedium,
                              ),
                            ),
                            Chip(
                              label: Text(
                                proposal.status.name.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              backgroundColor:
                                  _statusColor(ctx, proposal.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Destination Branch: ${proposal.branchId}',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                        Text(
                          'Fulfillment Warehouse: ${proposal.warehouseId}',
                          style: Theme.of(ctx).textTheme.bodySmall,
                        ),
                        Text(
                          '${proposal.lines.length} items · $totalUnits total units',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (!_canonicalProposalIds.contains(proposal.id))
                          const Text(
                              'Local record · Connect to verify before fulfillment'),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (proposal.status ==
                                RestockProposalStatus.approved)
                              FilledButton.icon(
                                icon: const Icon(Icons.playlist_play),
                                onPressed: _loading || !_canFulfill(proposal)
                                    ? null
                                    : () => _startPicking(proposal),
                                label: const Text('Start Picking'),
                              ),
                            if (proposal.status ==
                                RestockProposalStatus.picking)
                              FilledButton.icon(
                                icon: const Icon(Icons.checklist),
                                onPressed: _loading || !_canFulfill(proposal)
                                    ? null
                                    : () => _openPickingDialog(proposal),
                                label: const Text('Continue Picking'),
                              ),
                            if (proposal.status == RestockProposalStatus.picked)
                              FilledButton.icon(
                                icon: const Icon(Icons.archive),
                                onPressed: _loading || !_canFulfill(proposal)
                                    ? null
                                    : () => _openPackingDialog(proposal),
                                label: const Text('Pack & Seal'),
                              ),
                            if (proposal.status == RestockProposalStatus.packed)
                              const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text(
                                    'Manifest Sealed',
                                    style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildPoReceivingTab() {
    if (_purchaseOrders.isEmpty) {
      return const Center(
        child: SariSupplyStatus(
          message: 'No purchase orders recorded yet.',
          icon: Icons.receipt_long_outlined,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _purchaseOrders.length,
      itemBuilder: (ctx, i) {
        final po = _purchaseOrders[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text(
              'PO #${po.id.substring(0, po.id.length.clamp(0, 8))}',
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
            subtitle: Text(
              'Supplier: ${po.supplierId} · Dest: ${po.warehouseId}\nStatus: ${po.status.name.toUpperCase()}',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
            trailing: Chip(
              label: Text(
                po.status.name.toUpperCase(),
                style:
                    const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              backgroundColor: _poStatusColor(ctx, po.status),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Line Items:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    for (final line in po.lines) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _productNames[line.productId] ??
                                      line.productId,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Ordered: ${line.quantity} | Received: ${line.quantityReceived} | Unit: ₱${(line.unitCostCentavos / 100).toStringAsFixed(2)}',
                                  style: Theme.of(ctx).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          if (!line.isFullyReceived)
                            FilledButton.tonal(
                              onPressed: _loading ||
                                      !_ownerVerified ||
                                      !_canonicalPurchaseOrderIds
                                          .contains(po.id) ||
                                      !_canonicalWarehouseIds
                                          .contains(po.warehouseId)
                                  ? null
                                  : () => _openReceivingDialog(po, line),
                              child: const Text('Receive'),
                            )
                          else
                            const Icon(Icons.check_circle, color: Colors.green),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStockLevelsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Text('Warehouse: ',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<Warehouse>(
                  isExpanded: true,
                  initialValue: _selectedWarehouse,
                  items: _warehouses
                      .map((w) => DropdownMenuItem(
                            value: w,
                            child: Text('${w.name} (${w.code})'),
                          ))
                      .toList(),
                  onChanged: (wh) {
                    if (wh != null) _selectWarehouse(wh);
                  },
                ),
              ),
            ],
          ),
        ),
        if (_warehouseStock.isEmpty)
          const Expanded(
            child: Center(
              child: SariSupplyStatus(
                message: 'No stock recorded in this warehouse yet.',
                icon: Icons.warehouse_outlined,
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _warehouseStock.length,
              itemBuilder: (ctx, i) {
                final stock = _warehouseStock[i];
                final productName =
                    _productNames[stock.productId] ?? stock.productId;

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 12,
                                children: [
                                  Text(
                                    'Physical: ${stock.physicalQuantity}',
                                    style: Theme.of(ctx).textTheme.bodySmall,
                                  ),
                                  Text(
                                    'Reserved: ${stock.reservedQuantity}',
                                    style: TextStyle(
                                      color: stock.reservedQuantity > 0
                                          ? Colors.orange.shade800
                                          : null,
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    'Available: ${stock.availableQuantity}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: stock.availableQuantity <= 0
                                          ? Colors.red
                                          : Colors.green.shade800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton.outlined(
                          onPressed: _loading
                              ? null
                              : () => _openStockAdjustmentDialog(stock),
                          icon: const Icon(Icons.tune),
                          tooltip: 'Adjust stock',
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Color _statusColor(BuildContext context, RestockProposalStatus status) {
    switch (status) {
      case RestockProposalStatus.approved:
        return Colors.blue.shade100;
      case RestockProposalStatus.picking:
        return Colors.orange.shade100;
      case RestockProposalStatus.picked:
        return Colors.amber.shade100;
      case RestockProposalStatus.packed:
      case RestockProposalStatus.dispatched:
      case RestockProposalStatus.received:
        return Colors.green.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  Color _poStatusColor(BuildContext context, PurchaseOrderStatus status) {
    switch (status) {
      case PurchaseOrderStatus.completed:
        return Colors.green.shade100;
      case PurchaseOrderStatus.partiallyReceived:
        return Colors.orange.shade100;
      case PurchaseOrderStatus.submitted:
      case PurchaseOrderStatus.confirmed:
        return Colors.blue.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sariSupplyTaskAppBar(
        context,
        title: 'Warehouse Fulfillment',
        actions: [
          if (_ownerVerified && _selectedWarehouse != null)
            IconButton(
                tooltip: 'Dispatch and returns',
                icon: const Icon(Icons.local_shipping_outlined),
                onPressed: _loading
                    ? null
                    : () async {
                        final warehouse = _selectedWarehouse!;
                        await Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => OwnerDispatchScreen(
                                    merchantId: widget.store.merchantId,
                                    warehouseId: warehouse.id,
                                    warehouseName: warehouse.name)));
                        if (mounted) await _loadData();
                      }),
        ],
      ),
      body: SariSupplyPageContent(
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.playlist_add_check), text: 'Pick & Pack'),
                Tab(icon: Icon(Icons.local_shipping), text: 'PO Receiving'),
                Tab(icon: Icon(Icons.warehouse), text: 'Stock Levels'),
              ],
            ),
            if (_loading) const LinearProgressIndicator(),
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SariSupplyStatus(
                  message: _errorMessage!,
                  error: true,
                ),
              ),
            if (_statusMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SariSupplyStatus(
                  message: _statusMessage!,
                  icon: Icons.check_circle,
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildFulfillmentTab(),
                  _buildPoReceivingTab(),
                  _buildStockLevelsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
