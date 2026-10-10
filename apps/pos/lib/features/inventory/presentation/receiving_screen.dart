import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';

class ReceivingScreen extends StatefulWidget {
  const ReceivingScreen({
    super.key,
    required this.store,
    this.product,
    this.onReceived,
  });

  final InventoryStore store;
  final CatalogProduct? product;
  final VoidCallback? onReceived;

  @override
  State<ReceivingScreen> createState() => _ReceivingScreenState();
}

class _ReceivingScreenState extends State<ReceivingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _batchController = TextEditingController();
  final _expiryController = TextEditingController();
  final _reasonController = TextEditingController(text: 'Supplier delivery');
  final _searchController = TextEditingController();

  CatalogProduct? _selectedProduct;
  List<InventoryRow> _searchResults = [];
  bool _searching = false;
  bool _submitting = false;
  String? _error;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _selectedProduct = widget.product;
    if (_selectedProduct == null) {
      _search('');
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _batchController.dispose();
    _expiryController.dispose();
    _reasonController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final rows = await widget.store.search(query);
      if (mounted) {
        setState(() => _searchResults = rows);
      }
    } catch (_) {
      // Ignored during search typing.
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null && mounted) {
      final formatted =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      _expiryController.text = formatted;
    }
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_selectedProduct == null) {
      setState(() => _error = 'Please select a product');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    if (qty <= 0) {
      setState(() => _error = 'Enter a valid quantity greater than 0');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _statusMessage = null;
    });

    final operationId = const Uuid().v4();
    final batchNum = _batchController.text.trim();
    final expiry = _expiryController.text.trim();
    final reason = _reasonController.text.trim();

    try {
      await widget.store.recordReceiving(
        operationId: operationId,
        productId: _selectedProduct!.id,
        quantity: qty,
        reason: reason,
        batchNumber: batchNum.isEmpty ? null : batchNum,
        expiryDate: expiry.isEmpty ? null : expiry,
      );

      if (mounted) {
        setState(() {
          _submitting = false;
          _statusMessage = 'Saved locally · Sync pending';
        });
        widget.onReceived?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receiving recorded successfully')),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Failed to record receiving: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: sariSupplyTaskAppBar(context, title: 'Receive Stock'),
      body: SariSupplyPageContent(
        maxWidth: 600,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.product == null) ...[
                  Text(
                    'Select Product',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Search products',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: _search,
                  ),
                  if (_searching)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    ),
                  if (_selectedProduct != null)
                    Card(
                      margin: const EdgeInsets.only(top: 8),
                      child: ListTile(
                        title: Text(_selectedProduct!.name),
                        subtitle: Text(
                            'SKU: ${_selectedProduct!.sku} · Base unit: ${_selectedProduct!.baseUnit}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Clear selection',
                          onPressed: () =>
                              setState(() => _selectedProduct = null),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 180),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, i) {
                          final row = _searchResults[i];
                          return ListTile(
                            title: Text(row.product.name),
                            subtitle: Text('SKU: ${row.product.sku}'),
                            onTap: () =>
                                setState(() => _selectedProduct = row.product),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 16),
                ] else ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.product!.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SKU: ${widget.product!.sku} · Base unit: ${widget.product!.baseUnit}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _selectedProduct != null
                        ? 'Quantity (${_selectedProduct!.baseUnit})'
                        : 'Quantity (base units)',
                    prefixIcon: const Icon(Icons.inventory_2_outlined),
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) {
                      return 'Enter a positive whole quantity';
                    }
                    if (n > 1000000000) return 'Quantity too large';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _batchController,
                  decoration: const InputDecoration(
                    labelText: 'Batch / Lot Number (optional)',
                    prefixIcon: Icon(Icons.tag),
                  ),
                  maxLength: 64,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _expiryController,
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    labelText: 'Expiry Date (optional)',
                    hintText: 'YYYY-MM-DD',
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.event),
                      tooltip: 'Select date',
                      onPressed: _pickDate,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Reason / Supplier info',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                  maxLength: 160,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter a reason' : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  SariSupplyStatus(message: _error!, error: true),
                ],
                if (_statusMessage != null) ...[
                  const SizedBox(height: 12),
                  SariSupplyStatus(message: _statusMessage!),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: Text(_submitting ? 'Saving…' : 'Receive Stock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
