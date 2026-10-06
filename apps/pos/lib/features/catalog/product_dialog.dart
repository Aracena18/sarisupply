import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';

class _UnitFields {
  _UnitFields([CatalogUnit? unit])
      : name = TextEditingController(text: unit?.name ?? ''),
        factor = TextEditingController(text: '${unit?.factor ?? 1}'),
        price = TextEditingController(
            text: unit == null
                ? ''
                : '${unit.priceCentavos ~/ 100}.${(unit.priceCentavos % 100).toString().padLeft(2, '0')}'),
        barcode = TextEditingController(text: unit?.barcode ?? '');
  final TextEditingController name, factor, price, barcode;
  final expansion = ExpansibleController();
  bool added = false;
  void dispose() {
    name.dispose();
    factor.dispose();
    price.dispose();
    barcode.dispose();
    expansion.dispose();
  }
}

class ProductDialog extends StatefulWidget {
  const ProductDialog({super.key, this.product, required this.onSave});
  final CatalogProduct? product;
  final Future<CatalogProduct> Function(CatalogProduct, String) onSave;
  @override
  State<ProductDialog> createState() => _ProductDialogState();
}

class _ProductDialogState extends State<ProductDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _sku, _name, _imageUrl;
  late final List<_UnitFields> _units;
  late final String _productId;
  bool _active = true, _busy = false;
  String? _error, _fingerprint, _operationId;
  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _productId = p?.id ?? const Uuid().v4();
    _sku = TextEditingController(text: p?.sku ?? '');
    _name = TextEditingController(text: p?.name ?? '');
    _imageUrl = TextEditingController(text: p?.imageUrl ?? '');
    _units =
        p == null ? [_UnitFields()] : p.units.map(_UnitFields.new).toList();
    _active = p?.active ?? true;
  }

  int? _cents(String text) {
    if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(text.trim())) return null;
    final parts = text.trim().split('.');
    final cents = int.parse(parts[0]) * 100 +
        int.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
    return cents <= 1000000000 ? cents : null;
  }

  Future<void> _save() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) {
      for (final u in _units.skip(1)) {
        u.expansion.expand();
      }
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final units = _units
          .map((u) => CatalogUnit(
              name: u.name.text.trim(),
              factor: int.parse(u.factor.text),
              priceCentavos: _cents(u.price.text)!,
              barcode: u.barcode.text.trim()))
          .toList();
      final img = _imageUrl.text.trim();
      final p = CatalogProduct(
          id: _productId,
          sku: _sku.text.trim().toUpperCase(),
          name: _name.text.trim(),
          baseUnit: units.first.name,
          revision: widget.product?.revision ?? 0,
          active: _active,
          imageUrl: img.isEmpty ? null : img,
          units: units);
      final fingerprint = jsonEncode(p.toMap());
      if (fingerprint != _fingerprint) {
        _fingerprint = fingerprint;
        _operationId = const Uuid().v4();
      }
      await widget.onSave(p, _operationId!);
      if (mounted) Navigator.pop(context, true);
    } on ArgumentError {
      if (mounted) {
        setState(() => _error = 'Use distinct unit names and barcodes.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error is FirebaseException &&
                error.code == 'already-exists'
            ? 'SKU or barcode is already in use.'
            : error is FirebaseException && error.code == 'failed-precondition'
                ? 'Product changed. Close and sync before editing.'
                : operationErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete / Archive Product?'),
        content: Text(
          'Are you sure you want to remove "${_name.text}" from the active product catalog? Existing transaction history will remain intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _active = false);
      await _save();
    }
  }

  @override
  void dispose() {
    _sku.dispose();
    _name.dispose();
    _imageUrl.dispose();
    for (final u in _units) {
      u.dispose();
    }
    super.dispose();
  }

  Widget _unitFields(int i) =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextFormField(
            controller: _units[i].name,
            enabled: !_busy && (i != 0 || widget.product == null),
            maxLength: 30,
            decoration: InputDecoration(
                labelText: i == 0 ? 'Unit (e.g. piece)' : 'Unit (e.g. pack)'),
            validator: (v) => (v ?? '').trim().isEmpty ? 'Enter a unit' : null),
        if (i > 0) ...[
          const SizedBox(height: 16),
          TextFormField(
              controller: _units[i].factor,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Base units per unit'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n < 1 || n > 1000000
                    ? 'Enter a whole conversion'
                    : null;
              }),
        ],
        const SizedBox(height: 16),
        TextFormField(
            controller: _units[i].price,
            enabled: !_busy,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Selling price (₱)'),
            validator: (v) => _cents(v ?? '') == null
                ? 'Enter a price with up to 2 decimals'
                : null),
        const SizedBox(height: 16),
        TextFormField(
            controller: _units[i].barcode,
            enabled: !_busy,
            maxLength: 64,
            decoration: const InputDecoration(labelText: 'Barcode (optional)'),
            validator: (v) =>
                RegExp(r'^[A-Za-z0-9._-]{0,64}$').hasMatch((v ?? '').trim())
                    ? null
                    : 'Use letters, numbers, . - or _'),
        if (i > 0)
          TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      final removed = _units.removeAt(i);
                      setState(() {});
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => removed.dispose());
                    },
              child: const Text('Remove unit')),
      ]);

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !_busy,
      child: SariSupplyFormSurface(
        title: widget.product == null ? 'Add product' : 'Edit product',
        actions: [
          TextButton(
              onPressed: _busy ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: _busy ? null : _save,
              child: Text(_busy ? 'Saving…' : 'Save product')),
        ],
        child: Form(
            key: _form,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              ProductThumbnail(
                                imageUrl: _imageUrl.text.trim().isEmpty
                                    ? null
                                    : _imageUrl.text.trim(),
                                productName: _name.text.trim().isEmpty
                                    ? 'Product'
                                    : _name.text.trim(),
                                size: 58,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Product Image',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall),
                                    Text(
                                      'Pick a preset category or paste an image URL',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final preset in ProductImagePresets.all)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: ActionChip(
                                      avatar: Text(preset.emoji),
                                      label: Text(preset.name,
                                          style: const TextStyle(fontSize: 12)),
                                      onPressed: _busy
                                          ? null
                                          : () => setState(() =>
                                              _imageUrl.text = preset.url),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextFormField(
                      controller: _name,
                      enabled: !_busy,
                      maxLength: 120,
                      decoration:
                          const InputDecoration(labelText: 'Product name'),
                      onChanged: (val) {
                        if (_imageUrl.text.isEmpty) setState(() {});
                      },
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Enter a name' : null),
                  const SizedBox(height: 16),
                  TextFormField(
                      controller: _sku,
                      enabled: !_busy && widget.product == null,
                      maxLength: 40,
                      decoration: const InputDecoration(labelText: 'SKU'),
                      validator: (v) => RegExp(r'^[A-Z0-9_-]{1,40}$')
                              .hasMatch((v ?? '').trim().toUpperCase())
                          ? null
                          : 'Use letters, numbers, - or _'),
                  const SizedBox(height: 16),
                  Text('Base unit',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _unitFields(0),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _imageUrl,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: 'Image URL (optional)',
                      hintText: 'https://...',
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: _imageUrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () =>
                                  setState(() => _imageUrl.clear()),
                            )
                          : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  for (var i = 1; i < _units.length; i++)
                    Card(
                        child: ExpansionTile(
                      key: ObjectKey(_units[i]),
                      controller: _units[i].expansion,
                      maintainState: true,
                      initiallyExpanded: _units[i].added,
                      title: Text(_units[i].name.text.isEmpty
                          ? 'Sale unit ${i + 1}'
                          : _units[i].name.text),
                      children: [
                        Padding(
                            padding: const EdgeInsets.all(12),
                            child: _unitFields(i))
                      ],
                    )),
                  if (_units.length < 12)
                    TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  final unit = _UnitFields()..added = true;
                                  _units.add(unit);
                                }),
                        icon: const Icon(Icons.add),
                        label: const Text('Add sale unit')),
                  if (widget.product != null) ...[
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Available for sale'),
                        value: _active,
                        onChanged:
                            _busy ? null : (v) => setState(() => _active = v)),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _confirmDelete,
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text(
                        'Delete / Archive Product',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ],
                  if (_error != null)
                    SariSupplyStatus(message: _error!, error: true),
                  if (_busy) const LinearProgressIndicator(),
                ])),
      ));
}
