import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({
    super.key,
    required this.store,
    this.initialProduct,
    this.onCompleted,
  });

  final InventoryStore store;
  final CatalogProduct? initialProduct;
  final VoidCallback? onCompleted;

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Dispatch Tab State
  final _destinationController = TextEditingController();
  final _dispatchNotesController = TextEditingController();
  final _itemQtyController = TextEditingController();
  final _productSearchController = TextEditingController();
  CatalogProduct? _selectedProduct;
  List<InventoryRow> _productSearchResults = [];
  bool _searchingProduct = false;
  final List<StockTransferItem> _transferItems = [];
  final Map<String, String> _productNames = {};
  bool _submittingDispatch = false;
  String? _dispatchError;

  // Receive Tab State
  final _receiveIdController = TextEditingController();
  List<StockTransferIntent> _transfers = [];
  bool _loadingTransfers = true;
  String? _incomingCursor;
  bool _hasMoreIncoming = false;
  bool _submittingReceive = false;
  String? _receiveError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _selectedProduct = widget.initialProduct;
    if (_selectedProduct != null) {
      _productNames[_selectedProduct!.id] = _selectedProduct!.name;
    }
    _loadTransfers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _destinationController.dispose();
    _dispatchNotesController.dispose();
    _itemQtyController.dispose();
    _productSearchController.dispose();
    _receiveIdController.dispose();
    super.dispose();
  }

  Future<void> _loadTransfers({bool nextPage = false}) async {
    setState(() {
      _loadingTransfers = true;
      _receiveError = null;
    });
    try {
      final page = await InventoryFunctions.forHuman().incomingTransfers(
          widget.store.merchantId, widget.store.branchId,
          cursor: nextPage ? _incomingCursor : null);
      await widget.store.cacheIncomingTransfers(page.transfers);
      if (mounted) {
        setState(() {
          _incomingCursor = page.nextCursor;
          _hasMoreIncoming = page.hasMore;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _receiveError = operationErrorMessage(error));
    }
    try {
      final list = await widget.store.listTransfers();
      if (mounted) setState(() => _transfers = list);
    } catch (error) {
      if (mounted) setState(() => _receiveError = operationErrorMessage(error));
    } finally {
      if (mounted) setState(() => _loadingTransfers = false);
    }
  }

  Future<void> _searchProducts(String q) async {
    setState(() => _searchingProduct = true);
    try {
      final results = await widget.store.search(q);
      if (mounted) setState(() => _productSearchResults = results);
    } catch (_) {
      // Ignored
    } finally {
      if (mounted) setState(() => _searchingProduct = false);
    }
  }

  void _addItem() {
    if (_selectedProduct == null) {
      setState(() => _dispatchError = 'Select a product to add');
      return;
    }
    final qty = int.tryParse(_itemQtyController.text.trim()) ?? 0;
    if (qty <= 0) {
      setState(() => _dispatchError = 'Quantity must be at least 1');
      return;
    }
    if (_transferItems.any((i) => i.productId == _selectedProduct!.id)) {
      setState(() => _dispatchError = 'Product already added to transfer');
      return;
    }

    setState(() {
      _dispatchError = null;
      _transferItems.add(
        StockTransferItem(productId: _selectedProduct!.id, quantity: qty),
      );
      _productNames[_selectedProduct!.id] = _selectedProduct!.name;
      _selectedProduct = null;
      _itemQtyController.clear();
      _productSearchController.clear();
      _productSearchResults.clear();
    });
  }

  Future<void> _dispatch() async {
    if (_submittingDispatch) return;
    final dest = _destinationController.text.trim();
    if (dest.isEmpty) {
      setState(() => _dispatchError = 'Enter a destination branch ID');
      return;
    }
    if (dest == widget.store.branchId) {
      setState(
          () => _dispatchError = 'Destination cannot be the current branch');
      return;
    }
    if (_transferItems.isEmpty) {
      setState(() => _dispatchError = 'Add at least one product item');
      return;
    }

    setState(() {
      _submittingDispatch = true;
      _dispatchError = null;
    });

    final id = const Uuid().v4();
    try {
      await widget.store.dispatchTransfer(
        transferId: id,
        destinationBranchId: dest,
        items: _transferItems,
        occurredAt: DateTime.now(),
        notes: _dispatchNotesController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _submittingDispatch = false;
          _transferItems.clear();
          _destinationController.clear();
          _dispatchNotesController.clear();
        });
        widget.onCompleted?.call();
        await _loadTransfers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Saved locally · Transfer dispatch sync pending')),
          );
          _tabController.animateTo(1);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submittingDispatch = false;
          _dispatchError = operationErrorMessage(e);
        });
      }
    }
  }

  Future<void> _receive(String transferId) async {
    if (_submittingReceive) return;
    setState(() {
      _submittingReceive = true;
      _receiveError = null;
    });

    try {
      await widget.store.receiveTransfer(
        transferId: transferId,
        receivedAt: DateTime.now(),
      );

      if (mounted) {
        setState(() => _submittingReceive = false);
        widget.onCompleted?.call();
        await _loadTransfers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Saved locally · Transfer receipt sync pending')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submittingReceive = false;
          _receiveError = operationErrorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Branch Transfers'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Dispatch (Out)', icon: Icon(Icons.outbox)),
            Tab(text: 'Receive (In)', icon: Icon(Icons.move_to_inbox)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDispatchTab(),
          _buildReceiveTab(),
        ],
      ),
    );
  }

  Widget _buildDispatchTab() {
    return SariSupplyPageContent(
      maxWidth: 600,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Current Branch: ${widget.store.branchId}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _destinationController,
              decoration: const InputDecoration(
                labelText: 'Destination Branch ID',
                prefixIcon: Icon(Icons.storefront_outlined),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            Text(
              'Add Items to Transfer',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (_selectedProduct != null)
              Card(
                child: ListTile(
                  title: Text(_selectedProduct!.name),
                  subtitle: Text('SKU: ${_selectedProduct!.sku}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: 'Change product',
                    onPressed: () => setState(() => _selectedProduct = null),
                  ),
                ),
              )
            else ...[
              TextField(
                controller: _productSearchController,
                decoration: const InputDecoration(
                  labelText: 'Search product to add',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _searchProducts,
              ),
              if (_searchingProduct) const LinearProgressIndicator(),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 140),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _productSearchResults.length,
                  itemBuilder: (context, i) {
                    final row = _productSearchResults[i];
                    return ListTile(
                      title: Text(row.product.name),
                      subtitle: Text(
                          'Stock: ${row.quantity} ${row.product.baseUnit}'),
                      onTap: () =>
                          setState(() => _selectedProduct = row.product),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemQtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      prefixIcon: Icon(Icons.format_list_numbered),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: _addItem,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(100, 48),
                  ),
                  child: const Text('Add Item'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_transferItems.isNotEmpty) ...[
              Text(
                'Items to Dispatch (${_transferItems.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ..._transferItems.map((item) {
                final name = _productNames[item.productId] ?? item.productId;
                return Card(
                  child: ListTile(
                    title: Text(name),
                    subtitle: Text('Quantity: ${item.quantity} base units'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Remove',
                      onPressed: () => setState(() => _transferItems
                          .removeWhere((i) => i.productId == item.productId)),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _dispatchNotesController,
              decoration: const InputDecoration(
                labelText: 'Transfer Notes (optional)',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLength: 160,
            ),
            if (_dispatchError != null) ...[
              const SizedBox(height: 8),
              SariSupplyStatus(message: _dispatchError!, error: true),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submittingDispatch ? null : _dispatch,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(
                  _submittingDispatch ? 'Dispatching…' : 'Dispatch Transfer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiveTab() {
    return SariSupplyPageContent(
      maxWidth: 600,
      child: RefreshIndicator(
        onRefresh: _loadTransfers,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Transfers Involving This Branch',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (_receiveError != null) ...[
                SariSupplyStatus(message: _receiveError!, error: true),
                const SizedBox(height: 8),
              ],
              if (_hasMoreIncoming && !_loadingTransfers)
                TextButton(
                    onPressed: () => _loadTransfers(nextPage: true),
                    child: const Text('Load more incoming transfers')),
              if (_loadingTransfers)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_transfers.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No transfers found'),
                  ),
                )
              else
                ..._transfers.map((t) {
                  final isDestination =
                      t.destinationBranchId == widget.store.branchId;
                  final canReceive = isDestination &&
                      t.status == StockTransferStatus.dispatched;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isDestination ? 'INCOMING' : 'OUTGOING',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDestination
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.secondary,
                                ),
                              ),
                              Chip(
                                label: Text(t.status.name.toUpperCase()),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('Transfer ID: ${t.id}'),
                          Text(
                              'From: ${t.sourceBranchId} → To: ${t.destinationBranchId}'),
                          Text('Items: ${t.items.length} item(s)'),
                          if (t.notes.isNotEmpty) Text('Notes: ${t.notes}'),
                          const SizedBox(height: 8),
                          if (canReceive)
                            FilledButton.icon(
                              onPressed: _submittingReceive
                                  ? null
                                  : () => _receive(t.id),
                              icon: const Icon(Icons.check),
                              label: Text(_submittingReceive
                                  ? 'Receiving…'
                                  : 'Receive Stock'),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }
}
