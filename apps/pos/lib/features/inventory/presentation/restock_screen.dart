import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import '../data/procurement_workspace.dart';

class RestockScreen extends StatefulWidget {
  const RestockScreen({
    super.key,
    required this.store,
    this.isOwner = false,
    this.onProposalSubmitted,
  });

  final InventoryStore store;
  final bool isOwner;
  final VoidCallback? onProposalSubmitted;

  @override
  State<RestockScreen> createState() => _RestockScreenState();
}

class _RestockScreenState extends State<RestockScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  final _notesController = TextEditingController();

  List<InventoryRow> _shortages = [];
  List<RestockProposalLine> _draftLines = [];
  List<RestockProposal> _proposals = [];
  bool _loading = false;
  bool _ownerVerified = false;
  Set<String> _canonicalProposalIds = {};
  String? _actorId, _warehouseId;
  List<Warehouse> _warehouses = [];
  String? _statusMessage;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      try {
        final page =
            await refreshProcurementWorkspace(widget.store, 'restockProposals');
        _canonicalProposalIds = {
          for (final record in page['records'] as List)
            (record as Map)['id'] as String,
        };
        _ownerVerified =
            page['canManagePurchasing'] == true && page['pendingCount'] == 0;
        final warehousePage =
            await refreshProcurementWorkspace(widget.store, 'warehouses');
        _warehouses = (warehousePage['records'] as List)
            .map((record) =>
                Warehouse.fromMap(Map<String, dynamic>.from(record as Map)))
            .toList();
        if (!_warehouses.any((warehouse) => warehouse.id == _warehouseId)) {
          _warehouseId = _warehouses.length == 1 ? _warehouses.single.id : null;
        }
        _actorId = page['actorId'] as String;
        if ((page['pendingCount'] as int) > 0) {
          _statusMessage =
              'Saved locally · Purchasing sync pending or needs review';
        }
      } catch (error) {
        _ownerVerified = false;
        _errorMessage = operationErrorMessage(error);
      }
      final rows = await widget.store.search('');
      final lowStock = rows.where((r) => r.quantity <= 10).toList();
      final proposals = await widget.store.listRestockProposals();

      if (mounted) {
        setState(() {
          _shortages = lowStock;
          _proposals = proposals;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = operationErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  void _addShortageToDraft(InventoryRow row) {
    if (_draftLines.any((l) => l.productId == row.product.id)) return;
    setState(() {
      _draftLines.add(
        RestockProposalLine(
          productId: row.product.id,
          productName: row.product.name,
          sku: row.product.sku,
          currentStock: row.quantity,
          suggestedQuantity: 24, // Standard shelf pack
        ),
      );
    });
  }

  void _addAllShortages() {
    setState(() {
      for (final r in _shortages) {
        if (!_draftLines.any((l) => l.productId == r.product.id)) {
          _draftLines.add(
            RestockProposalLine(
              productId: r.product.id,
              productName: r.product.name,
              sku: r.product.sku,
              currentStock: r.quantity,
              suggestedQuantity: 24,
            ),
          );
        }
      }
    });
  }

  Future<void> _submitProposal() async {
    if (_warehouseId == null) {
      setState(() =>
          _errorMessage = 'Select a configured warehouse before submitting.');
      return;
    }
    if (_draftLines.isEmpty) {
      setState(() => _errorMessage = 'Add at least one product to restock');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _statusMessage = null;
    });

    final proposalId = const Uuid().v4();
    final proposal = RestockProposal(
      id: proposalId,
      branchId: widget.store.branchId,
      warehouseId: _warehouseId ?? '',
      status: RestockProposalStatus.pendingApproval,
      lines: _draftLines,
      requestedAt: DateTime.now(),
      notes: _notesController.text.trim(),
    );

    try {
      await widget.store.submitRestockProposal(proposal);
      _notesController.clear();
      if (mounted) {
        setState(() {
          _draftLines = [];
          _loading = false;
          _statusMessage = 'Saved locally · Owner submission sync pending';
        });
        widget.onProposalSubmitted?.call();
        _loadData();
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Failed to submit proposal: $e';
        });
      }
    }
  }

  Future<void> _showOwnerReviewDialog(RestockProposal proposal) async {
    if (_loading ||
        !_ownerVerified ||
        !_canonicalProposalIds.contains(proposal.id)) {
      return;
    }
    final qtyControllers = {
      for (final l in proposal.lines)
        l.productId: TextEditingController(
          text: (l.approvedQuantity > 0
                  ? l.approvedQuantity
                  : l.suggestedQuantity)
              .toString(),
        )
    };
    final reasonController = TextEditingController();

    final formKey = GlobalKey<FormState>();
    try {
      final result = await showSariSupplyForm<bool>(
        context: context,
        builder: (ctx) => SariSupplyFormSurface(
          title: 'Review restock',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Reject'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(ctx).pop(true);
                }
              },
              child: const Text('Approve & Reserve'),
            ),
          ],
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Order: ${proposal.id}'),
                const SizedBox(height: 12),
                for (final line in proposal.lines) ...[
                  Text(line.productName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Current stock: ${line.currentStock}'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: qtyControllers[line.productId],
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Approved quantity in base units'),
                    validator: (value) {
                      final quantity = int.tryParse(value?.trim() ?? '');
                      return quantity == null ||
                              quantity < 0 ||
                              quantity > 1000000
                          ? 'Enter a whole quantity from 0 to 1000000'
                          : null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: reasonController,
                  decoration:
                      const InputDecoration(labelText: 'Rejection reason'),
                ),
              ],
            ),
          ),
        ),
      );
      if (result == null || !mounted) return;
      setState(() => _loading = true);
      final adjustedLines = proposal.lines
          .map((line) => line.copyWith(
              approvedQuantity: result
                  ? int.parse(qtyControllers[line.productId]!.text.trim())
                  : 0))
          .toList();
      await widget.store.reviewRestockProposal(
        proposalId: proposal.id,
        approved: result,
        reviewedBy: _actorId!,
        adjustedLines: result ? adjustedLines : null,
        rejectionReason: result
            ? null
            : (reasonController.text.trim().isEmpty
                ? 'Rejected by Owner'
                : reasonController.text.trim()),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result
            ? 'Saved locally · Owner approval sync pending'
            : 'Saved locally · Rejection sync pending'),
      ));
      await _loadData();
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = operationErrorMessage(error));
      }
    } finally {
      for (final controller in qtyControllers.values) {
        controller.dispose();
      }
      reasonController.dispose();
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(RestockProposalStatus status) {
    switch (status) {
      case RestockProposalStatus.pendingApproval:
        return Colors.orange;
      case RestockProposalStatus.approved:
        return Colors.blue;
      case RestockProposalStatus.picking:
      case RestockProposalStatus.picked:
        return Colors.indigo;
      case RestockProposalStatus.packing:
      case RestockProposalStatus.packed:
        return Colors.purple;
      case RestockProposalStatus.dispatched:
      case RestockProposalStatus.received:
        return Colors.green;
      case RestockProposalStatus.rejected:
      case RestockProposalStatus.cancelled:
        return Colors.red;
      case RestockProposalStatus.draft:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sariSupplyTaskAppBar(
        context,
        title: 'Restock Orders',
      ),
      body: SariSupplyPageContent(
        maxWidth: 600,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Request Restock'),
                Tab(text: 'Order Status'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildRequestTab(),
                  _buildStatusTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_errorMessage != null) ...[
            SariSupplyStatus(message: _errorMessage!, error: true),
            const SizedBox(height: 12),
          ],
          if (_statusMessage != null) ...[
            SariSupplyStatus(message: _statusMessage!),
            const SizedBox(height: 12),
          ],

          // Low Stock Alert Card
          Card(
            color: Colors.amber.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        'Low Stock Items (${_shortages.length})',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const Spacer(),
                      if (_shortages.isNotEmpty)
                        TextButton(
                          onPressed: _addAllShortages,
                          child: const Text('Add All'),
                        ),
                    ],
                  ),
                  if (_shortages.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('All products are adequately stocked.'),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: _shortages.map((item) {
                        final inDraft = _draftLines
                            .any((l) => l.productId == item.product.id);
                        return ActionChip(
                          avatar: inDraft
                              ? const Icon(Icons.check, size: 16)
                              : const Icon(Icons.add, size: 16),
                          label: Text(
                              '${item.product.name} (stock: ${item.quantity})'),
                          onPressed: () => _addShortageToDraft(item),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Items to restock
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items to Restock (${_draftLines.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (_draftLines.isNotEmpty)
                TextButton(
                  onPressed: () => setState(() => _draftLines.clear()),
                  child: const Text('Clear All'),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (_draftLines.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text(
                    'No items in restock draft.\nSelect from low stock items above to begin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
            )
          else
            ...List.generate(_draftLines.length, (index) {
              final item = _draftLines[index];
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
                            Text(item.productName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            Text(
                                'SKU: ${item.sku} · Current: ${item.currentStock}',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 90,
                        child: TextFormField(
                          initialValue: item.suggestedQuantity.toString(),
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Qty',
                            isDense: true,
                          ),
                          onChanged: (val) {
                            final n = int.tryParse(val) ?? 0;
                            _draftLines[index] =
                                item.copyWith(suggestedQuantity: n);
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          setState(() => _draftLines.removeAt(index));
                        },
                      ),
                    ],
                  ),
                ),
              );
            }),

          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
              initialValue: _warehouseId,
              isExpanded: true,
              itemHeight: null,
              decoration:
                  const InputDecoration(labelText: 'Destination warehouse'),
              items: _warehouses
                  .map((warehouse) => DropdownMenuItem(
                      value: warehouse.id, child: Text(warehouse.name)))
                  .toList(),
              onChanged: _loading
                  ? null
                  : (value) => setState(() => _warehouseId = value)),
          const SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Order Notes (optional)',
              prefixIcon: Icon(Icons.edit_note),
            ),
          ),
          const SizedBox(height: 24),

          FilledButton(
            onPressed:
                (_loading || _draftLines.isEmpty) ? null : _submitProposal,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(_loading ? 'Submitting…' : 'Submit for Owner Approval'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTab() {
    if (_proposals.isEmpty) {
      return Center(
        child: Text(
          'No restock orders found.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _proposals.length,
      itemBuilder: (context, i) {
        final p = _proposals[i];
        final color = _statusColor(p.status);

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Proposal #${p.id.substring(0, p.id.length.clamp(0, 8))}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withAlpha(30),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color),
                      ),
                      child: Text(
                        p.status.label,
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Requested: ${p.requestedAt.toLocal().toString().split('.').first}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (p.reviewedBy != null) ...[
                  Text(
                    'Reviewed by: ${p.reviewedBy}',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
                if (p.rejectionReason != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Reason: ${p.rejectionReason}',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ],
                if (!_canonicalProposalIds.contains(p.id))
                  const Text('Local record · Connect to verify before review'),
                const Divider(height: 20),
                Text(
                  'Items (${p.lines.length}):',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                ...p.lines.map((l) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(l.productName)),
                          Text(
                            p.status == RestockProposalStatus.pendingApproval
                                ? 'Req: ${l.suggestedQuantity}'
                                : 'Appr: ${l.approvedQuantity}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    )),
                if (p.status == RestockProposalStatus.pendingApproval &&
                    (widget.isOwner &&
                        _ownerVerified &&
                        _canonicalProposalIds.contains(p.id))) ...[
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => _showOwnerReviewDialog(p),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(40),
                    ),
                    child: const Text('Review & Approve (Owner)'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
