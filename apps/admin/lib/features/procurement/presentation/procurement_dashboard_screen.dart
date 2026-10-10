import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';

class ProcurementDashboardScreen extends StatefulWidget {
  const ProcurementDashboardScreen({
    super.key,
    this.gateway,
    this.merchantId,
    this.readGateway,
  });

  final ProcurementGateway? gateway;
  final String? merchantId;
  final OperationsFunctions? readGateway;

  @override
  State<ProcurementDashboardScreen> createState() =>
      _ProcurementDashboardScreenState();
}

class _ProcurementDashboardScreenState extends State<ProcurementDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Supplier> _suppliers = [];
  List<Warehouse> _warehouses = [];
  List<CatalogProduct> _products = [];
  List<PurchaseOrder> _purchaseOrders = [];
  List<RestockProposal> _proposals = [];

  String? _merchantId;
  List<Map<String, Object?>> _merchants = [];
  bool _canManage = false;
  int _request = 0;
  ProcurementGateway get _gateway =>
      widget.gateway ?? ProcurementFunctions.forHuman();

  bool _loading = false;
  String? _error;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
      _canManage = false;
      _suppliers = [];
      _purchaseOrders = [];
      _proposals = [];
    });
    try {
      final reader = widget.readGateway ?? OperationsFunctions.forAdmin();
      final merchants = await reader.merchants();
      if (!mounted || request != _request) return;
      _merchants = merchants;
      _merchantId ??= widget.merchantId;
      if (!_merchants.any((m) => m['id'] == _merchantId)) {
        _merchantId =
            merchants.length == 1 ? merchants.single['id'] as String : null;
      }
      if (_merchantId == null) return;
      final pages = await Future.wait([
        'suppliers',
        'purchaseOrders',
        'restockProposals',
        'warehouses',
        'products'
      ].map((kind) => reader.procurement(_merchantId!, kind)));
      if (!mounted || request != _request) return;
      List<Map<String, dynamic>> records(int index) =>
          (pages[index]['records'] as List)
              .map((r) => Map<String, dynamic>.from(r as Map))
              .toList();
      setState(() {
        _suppliers = records(0).map(Supplier.fromMap).toList();
        _purchaseOrders = records(1).map(PurchaseOrder.fromMap).toList();
        _proposals = records(2).map(RestockProposal.fromMap).toList();
        _warehouses = records(3).map(Warehouse.fromMap).toList();
        _products = records(4)
            .map((record) =>
                CatalogProduct.fromMap(Map<String, Object?>.from(record)))
            .where((product) => product.active)
            .toList();
        _canManage = pages.every((page) => page['canManagePurchasing'] == true);
      });
    } catch (error) {
      if (mounted && request == _request) {
        setState(() => _error = operationErrorMessage(error));
      }
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  // ==========================================
  // Supplier Actions
  // ==========================================

  Future<void> _openAddSupplierDialog() async {
    final nameController = TextEditingController();
    final contactController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final addressController = TextEditingController();
    final leadTimeController = TextEditingController(text: '3');

    final confirmed = await showSariSupplyForm<bool>(
      context: context,
      builder: (ctx) => SariSupplyFormSurface(
        title: 'Add New Supplier',
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.of(ctx).pop(true);
              }
            },
            child: const Text('Save Supplier'),
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Supplier Company Name *',
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: contactController,
              decoration: const InputDecoration(
                labelText: 'Contact Person',
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address / Warehouse Location',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: leadTimeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Lead Time (Days)',
                prefixIcon: Icon(Icons.timer),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      final supplier = Supplier(
        id: 'sup-${const Uuid().v4().substring(0, 8)}',
        name: nameController.text.trim(),
        contactPerson: contactController.text.trim(),
        phone: phoneController.text.trim(),
        email: emailController.text.trim(),
        address: addressController.text.trim(),
        leadTimeDays: int.tryParse(leadTimeController.text.trim()) ?? 3,
        active: true,
      );

      setState(() => _loading = true);
      try {
        if (!_canManage || _merchantId == null) {
          throw StateError('Owner access required');
        }
        await _gateway.saveSupplier(_merchantId!, supplier);
        if (mounted) {
          setState(() {
            _statusMessage = 'Supplier ${supplier.name} added successfully.';
          });
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          setState(() => _error = operationErrorMessage(e));
        }
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    }
  }

  // ==========================================
  // Purchase Order Actions
  // ==========================================

  Future<void> _openCreatePoDialog() async {
    if (_suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please add at least one supplier first.')),
      );
      return;
    }

    Supplier selectedSupplier = _suppliers.first;
    final warehouseController = TextEditingController(
        text: _warehouses.isEmpty ? '' : _warehouses.first.id);
    final productIdController = TextEditingController();
    final qtyController = TextEditingController();
    final costController = TextEditingController();
    final lines = <PurchaseOrderLine>[];

    final confirmed = await showSariSupplyForm<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => SariSupplyFormSurface(
          title: 'Create Purchase Order',
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed:
                  lines.isNotEmpty ? () => Navigator.of(ctx).pop(true) : null,
              child: const Text('Issue PO'),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Supplier>(
                isExpanded: true,
                initialValue: selectedSupplier,
                decoration: const InputDecoration(labelText: 'Supplier *'),
                items: _suppliers
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.name),
                        ))
                    .toList(),
                onChanged: (s) {
                  if (s != null) setDialogState(() => selectedSupplier = s);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                  initialValue: warehouseController.text,
                  isExpanded: true,
                  itemHeight: null,
                  decoration:
                      const InputDecoration(labelText: 'Destination warehouse'),
                  items: _warehouses
                      .map((warehouse) => DropdownMenuItem(
                          value: warehouse.id, child: Text(warehouse.name)))
                      .toList(),
                  onChanged: (value) => warehouseController.text = value ?? ''),
              const SizedBox(height: 16),
              Text(
                'Line Items (${lines.length})',
                style: Theme.of(ctx).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              for (final line in lines) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(line.productName),
                  subtitle: Text(
                    '${line.quantity} units @ ₱${(line.unitCostCentavos / 100).toStringAsFixed(2)} = ₱${(line.totalCostCentavos / 100).toStringAsFixed(2)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setDialogState(() => lines.remove(line));
                    },
                  ),
                ),
                const Divider(height: 1),
              ],
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                          isExpanded: true,
                          itemHeight: null,
                          decoration: const InputDecoration(
                              labelText: 'Product (base units)'),
                          items: _products
                              .map((product) => DropdownMenuItem(
                                  value: product.id,
                                  child: Text(
                                      '${product.name} · ${product.baseUnit}')))
                              .toList(),
                          onChanged: (value) =>
                              productIdController.text = value ?? ''),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: qtyController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Quantity',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: costController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Unit Cost (₱)',
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item'),
                          onPressed: () {
                            final pid = productIdController.text.trim();
                            final q = int.tryParse(qtyController.text.trim());
                            int? c;
                            try {
                              c = parsePhpCentavos(costController.text.trim());
                            } on Object {/* Incomplete amount. */}
                            if (_products.any((product) => product.id == pid) &&
                                !lines.any((line) => line.productId == pid) &&
                                q != null &&
                                q > 0 &&
                                c != null &&
                                c >= 0) {
                              setDialogState(() {
                                lines.add(PurchaseOrderLine(
                                  productId: pid,
                                  productName: _products
                                      .firstWhere(
                                          (product) => product.id == pid)
                                      .name,
                                  sku: _products
                                      .firstWhere(
                                          (product) => product.id == pid)
                                      .sku,
                                  quantity: q,
                                  unitCostCentavos: c!,
                                ));
                                productIdController.clear();
                                qtyController.clear();
                                costController.clear();
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true && lines.isNotEmpty) {
      final po = PurchaseOrder(
        id: 'po-${const Uuid().v4().substring(0, 8)}',
        supplierId: selectedSupplier.id,
        supplierName: selectedSupplier.name,
        warehouseId: warehouseController.text.trim(),
        createdAt: DateTime.now(),
        expectedDeliveryDate: DateTime.now().add(
          Duration(days: selectedSupplier.leadTimeDays),
        ),
        lines: lines,
        status: PurchaseOrderStatus.submitted,
      );

      setState(() => _loading = true);
      try {
        if (!_canManage || _merchantId == null) {
          throw StateError('Owner access required');
        }
        await _gateway.createPurchaseOrder(_merchantId!, po);
        if (mounted) {
          setState(() {
            _statusMessage =
                'Purchase Order #${po.id.substring(0, 8)} submitted.';
          });
        }
        await _loadData();
      } catch (e) {
        if (mounted) {
          setState(() => _error = operationErrorMessage(e));
        }
      } finally {
        if (mounted) {
          setState(() => _loading = false);
        }
      }
    }
  }

  // ==========================================
  // UI Tabs
  // ==========================================

  Widget _buildSuppliersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${_suppliers.length} Registered Suppliers',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Add Supplier'),
                onPressed:
                    _loading || !_canManage ? null : _openAddSupplierDialog,
              ),
            ],
          ),
        ),
        if (_suppliers.isEmpty)
          const Expanded(
            child: Center(
              child: SariSupplyStatus(
                message:
                    'No suppliers registered yet. Click "Add Supplier" to create one.',
                icon: Icons.local_shipping_outlined,
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _suppliers.length,
              itemBuilder: (ctx, i) {
                final s = _suppliers[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.name,
                                style: Theme.of(ctx).textTheme.titleMedium,
                              ),
                            ),
                            Chip(
                              label: Text(s.active ? 'ACTIVE' : 'INACTIVE'),
                              backgroundColor: s.active
                                  ? SariSupplyColors.success
                                      .withValues(alpha: 0.1)
                                  : SariSupplyColors.divider,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (s.contactPerson.isNotEmpty)
                          Text('Contact: ${s.contactPerson} (${s.phone})'),
                        if (s.email.isNotEmpty) Text('Email: ${s.email}'),
                        if (s.address.isNotEmpty) Text('Address: ${s.address}'),
                        const SizedBox(height: 4),
                        Text(
                          'Standard Lead Time: ${s.leadTimeDays} days',
                          style: const TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildPoTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  '${_purchaseOrders.length} Purchase Orders',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Create PO'),
                onPressed: _loading ||
                        !_canManage ||
                        _warehouses.isEmpty ||
                        _products.isEmpty
                    ? null
                    : _openCreatePoDialog,
              ),
            ],
          ),
        ),
        if (_purchaseOrders.isEmpty)
          const Expanded(
            child: Center(
              child: SariSupplyStatus(
                message: 'No purchase orders recorded yet.',
                icon: Icons.receipt_long_outlined,
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _purchaseOrders.length,
              itemBuilder: (ctx, i) {
                final po = _purchaseOrders[i];
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
                                'PO #${po.id.substring(0, 8)}',
                                style: Theme.of(ctx).textTheme.titleMedium,
                              ),
                            ),
                            Chip(
                              label: Text(po.status.name.toUpperCase()),
                              backgroundColor:
                                  SariSupplyColors.info.withValues(alpha: 0.1),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                            'Supplier: ${po.supplierId} · Dest: ${po.warehouseId}'),
                        Text(
                          '${po.lines.length} items · Total: ₱${(po.totalCostCentavos / 100).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        if (po.expectedDeliveryDate != null)
                          Text(
                            'Expected: ${po.expectedDeliveryDate!.toLocal().toString().split(' ')[0]}',
                            style: Theme.of(ctx).textTheme.bodySmall,
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

  Widget _buildRestockOversightTab() {
    if (_proposals.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: SariSupplyStatus(
            message:
                'Restock proposal approval and warehouse stock reservations are active across all branches. Branch restock submissions will appear here for centralized operations oversight.',
            icon: Icons.verified_user_outlined,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _proposals.length,
      itemBuilder: (ctx, i) {
        final p = _proposals[i];
        final totalUnits = p.lines.fold(
          0,
          (sum, l) =>
              sum +
              (l.approvedQuantity > 0
                  ? l.approvedQuantity
                  : l.suggestedQuantity),
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
                        'Restock #${p.id.substring(0, 8)}',
                        style: Theme.of(ctx).textTheme.titleMedium,
                      ),
                    ),
                    Chip(
                      label: Text(p.status.name.toUpperCase()),
                      backgroundColor:
                          SariSupplyColors.info.withValues(alpha: 0.1),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                    'Branch: ${p.branchId} · Target Warehouse: ${p.warehouseId}'),
                Text(
                  '${p.lines.length} items · $totalUnits total units',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _addWarehouse() async {
    final name = TextEditingController(),
        code = TextEditingController(),
        address = TextEditingController();
    try {
      final saved = await showSariSupplyForm<bool>(
          context: context,
          builder: (context) => SariSupplyFormSurface(
              title: 'Add warehouse',
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel')),
                FilledButton(
                    onPressed: () {
                      if (name.text.trim().isNotEmpty &&
                          code.text.trim().isNotEmpty) {
                        Navigator.pop(context, true);
                      }
                    },
                    child: const Text('Save warehouse'))
              ],
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: name,
                    decoration:
                        const InputDecoration(labelText: 'Warehouse name')),
                TextField(
                    controller: code,
                    decoration:
                        const InputDecoration(labelText: 'Warehouse code')),
                TextField(
                    controller: address,
                    decoration: const InputDecoration(labelText: 'Address'))
              ])));
      if (saved != true || !mounted || !_canManage || _merchantId == null) {
        return;
      }
      setState(() => _loading = true);
      await ProcurementFunctions.forHuman().saveWarehouse(
          _merchantId!,
          Warehouse(
              id: const Uuid().v4(),
              name: name.text.trim(),
              code: code.text.trim(),
              address: address.text.trim()));
      if (mounted) await _loadData();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = operationErrorMessage(error);
          _loading = false;
        });
      }
    } finally {
      name.dispose();
      code.dispose();
      address.dispose();
    }
  }

  Widget _buildWarehousesTab() =>
      ListView(padding: const EdgeInsets.all(16), children: [
        FilledButton.icon(
            onPressed: _loading || !_canManage ? null : _addWarehouse,
            icon: const Icon(Icons.add),
            label: const Text('Add warehouse')),
        if (_warehouses.isEmpty)
          const SariSupplyStatus(
              message:
                  'No configured warehouses. A Store Owner must add one before purchasing.'),
        ..._warehouses.map((warehouse) => ListTile(
            title: Text(warehouse.name),
            subtitle: Text('${warehouse.code} · ${warehouse.address}')))
      ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sariSupplyTaskAppBar(
        context,
        title: 'Procurement & Warehouses',
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey(_merchantId),
                      initialValue: _merchantId,
                      isExpanded: true,
                      itemHeight: null,
                      decoration: const InputDecoration(labelText: 'Store'),
                      items: _merchants
                          .map((m) => DropdownMenuItem(
                              value: m['id'] as String,
                              child: Text(m['name'] as String)))
                          .toList(),
                      onChanged: _loading
                          ? null
                          : (value) {
                              _merchantId = value;
                              _loadData();
                            },
                    )),
                if (!_loading && _merchantId == null)
                  const SariSupplyStatus(
                      message: 'Select a store to view purchasing.'),
                if (!_loading && _merchantId != null && !_canManage)
                  const SariSupplyStatus(
                      message:
                          'Store Owner access is required to change purchasing.'),
                if (_error != null)
                  TextButton(onPressed: _loadData, child: const Text('Retry')),
                TabBar(
                  isScrollable: true,
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.local_shipping), text: 'Suppliers'),
                    Tab(
                        icon: Icon(Icons.receipt_long),
                        text: 'Purchase Orders'),
                    Tab(
                        icon: Icon(Icons.fact_check),
                        text: 'Restock Oversight'),
                    Tab(icon: Icon(Icons.warehouse), text: 'Warehouses'),
                  ],
                ),
                if (_loading) const LinearProgressIndicator(),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SariSupplyStatus(message: _error!, error: true),
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
                      _buildSuppliersTab(),
                      _buildPoTab(),
                      _buildRestockOversightTab(),
                      _buildWarehousesTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
