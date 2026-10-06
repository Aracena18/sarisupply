import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:uuid/uuid.dart';

enum AdjustmentReasonCode {
  spoilage('Spoilage / Expired'),
  damaged('Damaged goods'),
  shrinkage('Shrinkage / Theft'),
  recount('Inventory recount');

  const AdjustmentReasonCode(this.label);
  final String label;
}

class AdjustmentScreen extends StatefulWidget {
  const AdjustmentScreen({
    super.key,
    required this.store,
    this.row,
    this.onAdjusted,
  });

  final InventoryStore store;
  final InventoryRow? row;
  final VoidCallback? onAdjusted;

  @override
  State<AdjustmentScreen> createState() => _AdjustmentScreenState();
}

class _AdjustmentScreenState extends State<AdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _notesController = TextEditingController();
  final _searchController = TextEditingController();

  InventoryRow? _selectedRow;
  List<InventoryRow> _searchResults = [];
  bool _searching = false;
  bool _isReduction = true;
  AdjustmentReasonCode _reasonCode = AdjustmentReasonCode.spoilage;
  bool _submitting = false;
  String? _error;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _selectedRow = widget.row;
    if (_selectedRow == null) {
      _search('');
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final rows = await widget.store.search(query);
      if (mounted) setState(() => _searchResults = rows);
    } catch (_) {
      // Ignored during search typing.
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  int get _delta {
    final qty = int.tryParse(_qtyController.text.trim()) ?? 0;
    return _isReduction ? -qty : qty;
  }

  Future<void> _submit() async {
    if (_selectedRow == null) {
      setState(() => _error = 'Please select a product');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final delta = _delta;
    if (delta == 0) {
      setState(() => _error = 'Adjustment quantity must be greater than 0');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
      _statusMessage = null;
    });

    final operationId = const Uuid().v4();
    final notes = _notesController.text.trim();
    final fullReason =
        notes.isEmpty ? _reasonCode.label : '${_reasonCode.label}: $notes';

    try {
      await widget.store.recordStockAdjustment(
        operationId: operationId,
        productId: _selectedRow!.product.id,
        delta: delta,
        reason: fullReason,
      );

      if (mounted) {
        setState(() {
          _submitting = false;
          _statusMessage = 'Saved locally · Sync pending';
        });
        widget.onAdjusted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock adjustment saved locally')),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Failed to record adjustment: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentQty = _selectedRow?.quantity ?? 0;
    final parsedQty = int.tryParse(_qtyController.text.trim()) ?? 0;
    final projectedQty = currentQty + (_isReduction ? -parsedQty : parsedQty);

    return Scaffold(
      appBar: sariSupplyTaskAppBar(context, title: 'Stock Adjustment'),
      body: SariSupplyPageContent(
        maxWidth: 600,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.row == null) ...[
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
                  if (_selectedRow != null)
                    Card(
                      margin: const EdgeInsets.only(top: 8),
                      child: ListTile(
                        title: Text(_selectedRow!.product.name),
                        subtitle: Text(
                            'Current stock: ${_selectedRow!.quantity} ${_selectedRow!.product.baseUnit}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Clear selection',
                          onPressed: () => setState(() => _selectedRow = null),
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
                            subtitle: Text(
                                '${row.quantity} ${row.product.baseUnit} in stock'),
                            onTap: () => setState(() => _selectedRow = row),
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
                            widget.row!.product.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'SKU: ${widget.row!.product.sku} · Current stock: ${widget.row!.quantity} ${widget.row!.product.baseUnit}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Adjustment Direction',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Reduce stock (-)')),
                        selected: _isReduction,
                        onSelected: (val) =>
                            setState(() => _isReduction = true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('Add stock (+)')),
                        selected: !_isReduction,
                        onSelected: (val) =>
                            setState(() => _isReduction = false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<AdjustmentReasonCode>(
                  initialValue: _reasonCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Reason category',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: AdjustmentReasonCode.values.map((code) {
                    return DropdownMenuItem(
                      value: code,
                      child: Text(code.label),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _reasonCode = val);
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _qtyController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: _selectedRow != null
                        ? 'Quantity to ${_isReduction ? 'reduce' : 'add'} (${_selectedRow!.product.baseUnit})'
                        : 'Quantity to ${_isReduction ? 'reduce' : 'add'}',
                    prefixIcon: Icon(_isReduction
                        ? Icons.remove_circle_outline
                        : Icons.add_circle_outline),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    if (n == null || n <= 0) {
                      return 'Enter a positive quantity';
                    }
                    if (n > 1000000000) return 'Quantity too large';
                    return null;
                  },
                ),
                if (_selectedRow != null && parsedQty > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Stock will change: $currentQty → $projectedQty ${_selectedRow!.product.baseUnit}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: projectedQty < 0
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLength: 140,
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
                  child: Text(_submitting ? 'Saving…' : 'Save Adjustment'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
