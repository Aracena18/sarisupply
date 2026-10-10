import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

/// Add/edit form for a company wholesale product, including its optional photo.
///
/// Photos are preset or custom HTTPS image URLs only — the same pre-existing
/// picture links used in POS. An empty photo falls back to a category
/// placeholder wherever the product is listed. Managed camera/gallery uploads
/// are not supported for company products yet.
class CompanyProductDialog extends StatefulWidget {
  const CompanyProductDialog({super.key, this.product});

  /// Existing product for edits. SKU and base unit are locked after creation
  /// (the trusted backend rejects changes); name, price and photo are editable.
  final CompanyRecord? product;

  /// Opens the form. Returns the validated values
  /// (`name`, `sku`, `unit`, `priceCentavos`, `imageUrl`) or null on cancel.
  static Future<Map<String, Object?>?> show(
    BuildContext context, {
    CompanyRecord? product,
  }) => showSariSupplyForm<Map<String, Object?>>(
    context: context,
    builder: (_) => CompanyProductDialog(product: product),
  );

  @override
  State<CompanyProductDialog> createState() => _CompanyProductDialogState();
}

class _CompanyProductDialogState extends State<CompanyProductDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name, _sku, _unit, _price, _imageUrl;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.string('name') ?? '');
    _sku = TextEditingController(text: p?.string('sku') ?? '');
    _unit = TextEditingController(text: p?.string('unit') ?? '');
    _price = TextEditingController(
      text: p == null
          ? ''
          : (p.number('priceCentavos') / 100).toStringAsFixed(2),
    );
    _imageUrl = TextEditingController(text: p?.imageUrl ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _sku.dispose();
    _unit.dispose();
    _price.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  int? _cents(String text) {
    if (!RegExp(r'^\d{1,8}(\.\d{1,2})?$').hasMatch(text.trim())) return null;
    final parts = text.trim().split('.');
    final cents =
        int.parse(parts[0]) * 100 +
        int.parse(parts.length == 1 ? '0' : parts[1].padRight(2, '0'));
    return cents >= 1 && cents <= 100000000 ? cents : null;
  }

  String? _photoError(String text) {
    if (text.trim().isEmpty) return null;
    final uri = Uri.tryParse(text.trim());
    if (uri == null || !uri.isScheme('https') || text.trim().length > 2048) {
      return 'Use an HTTPS photo link';
    }
    return null;
  }

  void _usePreset(String url) => setState(() => _imageUrl.text = url);

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, <String, Object?>{
      'name': _name.text.trim(),
      'sku': _sku.text.trim().toUpperCase(),
      'unit': _unit.text.trim(),
      'priceCentavos': _cents(_price.text)!,
      'imageUrl': _imageUrl.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.product != null;
    return SariSupplyFormSurface(
      title: editing ? 'Edit company product' : 'Add company product',
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(editing ? 'Save changes' : 'Add product'),
        ),
      ],
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              editing
                  ? 'Name, wholesale price and photo can change. SKU and base unit stay locked.'
                  : 'Add details, wholesale price, then an optional photo. You can always save without a photo.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: SariSupplyColors.ink600),
            ),
            const SizedBox(height: 12),
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Details',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _name,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Product name',
                        hintText: 'e.g. Kopiko Blanca 28g',
                      ),
                      onChanged: (_) {
                        if (_imageUrl.text.isEmpty) setState(() {});
                      },
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Enter a name' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _sku,
                      enabled: !editing,
                      maxLength: 64,
                      decoration: const InputDecoration(
                        labelText: 'SKU',
                        hintText: 'e.g. KOPIKO-28G',
                        helperText:
                            'Uppercase letters, numbers, - or _. Locked after saving.',
                      ),
                      validator: (v) =>
                          RegExp(
                            r'^[A-Z0-9_-]{1,64}$',
                          ).hasMatch((v ?? '').trim().toUpperCase())
                          ? null
                          : 'Use letters, numbers, - or _',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _unit,
                      enabled: !editing,
                      maxLength: 30,
                      decoration: const InputDecoration(
                        labelText: 'Base unit',
                        hintText: 'piece, can, bag',
                        helperText: 'Locked after saving.',
                      ),
                      validator: (v) =>
                          (v ?? '').trim().isEmpty ? 'Enter a unit' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Wholesale price per unit (₱)',
                      ),
                      validator: (v) => _cents(v ?? '') == null
                          ? 'Enter a price above ₱0.00 with up to 2 decimals'
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.photo_camera_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Photo (optional)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Preset or link. Empty shows a category placeholder.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SariSupplyColors.ink600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ProductThumbnail(
                          imageUrl: _imageUrl.text.trim().isEmpty
                              ? null
                              : _imageUrl.text.trim(),
                          productName: _name.text.trim().isEmpty
                              ? 'Product'
                              : _name.text.trim(),
                          size: 64,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _imageUrl,
                            decoration: InputDecoration(
                              labelText: 'Image URL (optional)',
                              hintText: 'https://...',
                              prefixIcon: const Icon(Icons.link),
                              suffixIcon: _imageUrl.text.isNotEmpty
                                  ? IconButton(
                                      tooltip: 'Remove photo',
                                      icon: const Icon(Icons.clear, size: 18),
                                      onPressed: () =>
                                          setState(() => _imageUrl.text = ''),
                                    )
                                  : null,
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (v) => _photoError(v ?? ''),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final preset in ProductImagePresets.all)
                          ActionChip(
                            avatar: Text(preset.emoji),
                            label: Text(
                              preset.name,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onPressed: () => _usePreset(preset.url),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
