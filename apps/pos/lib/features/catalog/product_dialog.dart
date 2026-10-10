import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import 'product_photo_format.dart';

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
  const ProductDialog(
      {super.key,
      this.product,
      required this.onSave,
      this.photoGateway,
      this.merchantId,
      this.pickPhoto});
  final CatalogProduct? product;
  final Future<CatalogProduct> Function(CatalogProduct, String) onSave;
  final ProductImageGateway? photoGateway;
  final String? merchantId;
  final Future<XFile?> Function(ImageSource)? pickPhoto;
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
  Uint8List? _photo;
  String? _photoFormat, _uploadId, _photoStatus;
  ProductImageRef? _uploadedImage;
  bool _removeImage = false;
  bool _photoUploadBlocked = false;
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
    if (widget.photoGateway != null) _recoverPhoto();
  }

  Future<void> _recoverPhoto() async {
    try {
      final lost = await ImagePicker().retrieveLostData();
      if (!mounted || lost.isEmpty) return;
      if (lost.files?.isNotEmpty == true) await _selectPhoto(lost.files!.first);
      if (lost.exception != null && mounted) {
        setState(() => _error =
            'Photo selection could not be recovered. Choose the photo again.');
      }
    } catch (_) {
      // Unsupported platforms have no interrupted Android picker to recover.
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Downscale phone camera photos so they stay under the 5 MiB limit.
      // Tests inject [widget.pickPhoto]; production uses the downscaled picker.
      final selected = await (widget.pickPhoto?.call(source) ??
          ImagePicker().pickImage(
            source: source,
            maxWidth: 1600,
            maxHeight: 1600,
            imageQuality: 85,
          ));
      if (selected != null && mounted) await _selectPhoto(selected);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Photo selection unavailable. Check camera or photo permissions and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _selectPhoto(XFile selected) async {
    if (await selected.length() > 5 * 1024 * 1024) {
      if (mounted) {
        setState(() => _error =
            'That photo is over 5 MiB. Try Take photo again (auto-shrunk) or choose a smaller file. You can still save the product without a photo.');
      }
      return;
    }
    final bytes = await selected.readAsBytes();
    final format = productPhotoFormat(bytes);
    if (format == null) {
      if (mounted) {
        setState(() => _error =
            'Phone photo not supported. Use a static JPEG, PNG or WebP photo (Live/HEIC and animated images are rejected). You can still save without a photo.');
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _photo = bytes;
      _photoFormat = format;
      _uploadId = const Uuid().v4();
      _uploadedImage = null;
      _removeImage = false;
      _photoUploadBlocked = false;
      _error = null;
      _photoStatus = 'Photo selected · Internet required to save';
    });
  }

  Future<void> _saveWithoutPhoto() async {
    if (_busy) return;
    setState(() {
      _photo = null;
      _photoFormat = null;
      _uploadId = null;
      _uploadedImage = null;
      _photoStatus = null;
      _photoUploadBlocked = false;
      _error = null;
    });
    await _save();
  }

  void _useImageUrl(String url) {
    setState(() {
      _imageUrl.text = url;
      _photo = null;
      _photoFormat = null;
      _uploadId = null;
      _uploadedImage = null;
      _photoStatus = null;
      _photoUploadBlocked = false;
      _removeImage = url.trim().isEmpty;
    });
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
    var savingProduct = false;
    try {
      final units = _units
          .map((u) => CatalogUnit(
              name: u.name.text.trim(),
              factor: int.parse(u.factor.text),
              priceCentavos: _cents(u.price.text)!,
              barcode: u.barcode.text.trim()))
          .toList();
      final img = _imageUrl.text.trim();
      var change = const ProductImageChange.keep();
      if (_photo != null) {
        setState(() => _photoStatus = 'Uploading photo…');
        _uploadedImage ??= await widget.photoGateway!.uploadProductPhoto(
            widget.merchantId!, _productId, _uploadId!, _photo!, _photoFormat!);
        if (!mounted) return;
        change = ProductImageChange.upload(_uploadId);
        if (mounted) {
          setState(() => _photoStatus = 'Photo uploaded · Saving product…');
        }
      } else if (_removeImage) {
        change = const ProductImageChange.remove();
      } else if (img != (widget.product?.imageUrl ?? '')) {
        change = img.isEmpty
            ? const ProductImageChange.remove()
            : ProductImageChange.url(img);
      }
      final p = CatalogProduct(
          id: _productId,
          sku: _sku.text.trim().toUpperCase(),
          name: _name.text.trim(),
          baseUnit: units.first.name,
          revision: widget.product?.revision ?? 0,
          active: _active,
          imageUrl: _uploadedImage?.secureUrl ?? (img.isEmpty ? null : img),
          image: _uploadedImage ??
              (change.action == 'keep' ? widget.product?.image : null),
          units: units);
      final fingerprint =
          jsonEncode({'product': p.toMap(), 'imageChange': change.toMap()});
      if (fingerprint != _fingerprint) {
        _fingerprint = fingerprint;
        _operationId = const Uuid().v4();
      }
      savingProduct = true;
      if (widget.photoGateway != null && widget.merchantId != null) {
        await widget.photoGateway!
            .saveProductWithImage(widget.merchantId!, p, _operationId!, change);
      } else {
        await widget.onSave(p, _operationId!);
      }
      if (mounted) Navigator.pop(context, true);
    } on ArgumentError {
      if (mounted) {
        setState(() => _error = 'Use distinct unit names and barcodes.');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          if (_photo != null) {
            _photoStatus = _uploadedImage == null
                ? 'Photo selected · Retry requires internet'
                : 'Photo uploaded · Product not saved';
          }
          final uploadFailed = !savingProduct && _photo != null;
          _photoUploadBlocked = uploadFailed;
          _error = uploadFailed &&
                  error is FirebaseException &&
                  error.code == 'failed-precondition'
              ? 'Photo upload is unavailable (service off or photo draft expired). Save without the photo to add the item now, or remove/retry the photo.'
              : uploadFailed
                  ? '${operationErrorMessage(error)} Save without the photo to add the item now.'
                  : error is FirebaseException && error.code == 'already-exists'
                      ? 'SKU or barcode is already in use.'
                      : error is FirebaseException &&
                              error.code == 'failed-precondition'
                          ? 'Product changed. Close and sync before editing.'
                          : operationErrorMessage(error);
        });
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
            style:
                FilledButton.styleFrom(backgroundColor: SariSupplyColors.error),
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
                  Text(
                    widget.product == null
                        ? 'Add details, price, then an optional photo. You can always save without a photo.'
                        : 'Edit details, price, or photo.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: SariSupplyColors.ink600),
                  ),
                  const SizedBox(height: 12),
                  // 1 — Details.
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
                              Text('Details',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Name and SKU identify the product.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: SariSupplyColors.ink600),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                              controller: _name,
                              enabled: !_busy,
                              maxLength: 120,
                              decoration: const InputDecoration(
                                  labelText: 'Product name',
                                  hintText: 'e.g. Kopiko Blanca 28g'),
                              onChanged: (val) {
                                if (_imageUrl.text.isEmpty) setState(() {});
                              },
                              validator: (v) => (v ?? '').trim().isEmpty
                                  ? 'Enter a name'
                                  : null),
                          const SizedBox(height: 16),
                          TextFormField(
                              controller: _sku,
                              enabled: !_busy && widget.product == null,
                              maxLength: 40,
                              decoration: const InputDecoration(
                                  labelText: 'SKU',
                                  hintText: 'e.g. KOPIKO-28G',
                                  helperText:
                                      'Uppercase letters, numbers, - or _. Locked after saving.'),
                              validator: (v) => RegExp(r'^[A-Z0-9_-]{1,40}$')
                                      .hasMatch((v ?? '').trim().toUpperCase())
                                  ? null
                                  : 'Use letters, numbers, - or _'),
                        ],
                      ),
                    ),
                  ),
                  // 2 — Price & units.
                  Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.payments_outlined, size: 20),
                              const SizedBox(width: 8),
                              Text('Price & units',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Base unit is the stock unit. Add packs as sale units.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: SariSupplyColors.ink600),
                          ),
                          const SizedBox(height: 12),
                          Text('Base unit',
                              style: Theme.of(context).textTheme.titleSmall),
                          const SizedBox(height: 8),
                          _unitFields(0),
                          if (_units.length > 1) ...[
                            const Divider(height: 32),
                            Text('Sale units',
                                style: Theme.of(context).textTheme.titleSmall),
                            const SizedBox(height: 8),
                          ],
                          for (var i = 1; i < _units.length; i++)
                            Card(
                                margin: const EdgeInsets.only(bottom: 8),
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
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                  onPressed: _busy
                                      ? null
                                      : () => setState(() {
                                            final unit = _UnitFields()
                                              ..added = true;
                                            _units.add(unit);
                                          }),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add sale unit')),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // 3 — Photo (optional, never blocks saving).
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
                              Text('Photo (optional)',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Non-sensitive product photo. Photos are public and need internet.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: SariSupplyColors.ink600),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_photo != null)
                                ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.memory(_photo!,
                                        width: 64,
                                        height: 64,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                const Icon(Icons.broken_image)))
                              else
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (widget.photoGateway != null &&
                                        widget.merchantId != null)
                                      Wrap(
                                          spacing: 8,
                                          runSpacing: 8,
                                          children: [
                                            OutlinedButton.icon(
                                                onPressed: _busy
                                                    ? null
                                                    : () => _pickPhoto(
                                                        ImageSource.camera),
                                                icon: const Icon(
                                                    Icons.camera_alt_outlined),
                                                label:
                                                    const Text('Take photo')),
                                            OutlinedButton.icon(
                                                onPressed: _busy
                                                    ? null
                                                    : () => _pickPhoto(
                                                        ImageSource.gallery),
                                                icon: const Icon(Icons
                                                    .photo_library_outlined),
                                                label:
                                                    const Text('Choose photo')),
                                            if (_photo != null ||
                                                _imageUrl.text.isNotEmpty)
                                              TextButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : () => _useImageUrl(''),
                                                  child: const Text(
                                                      'Remove photo')),
                                          ]),
                                    const SizedBox(height: 4),
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Icon(
                                          _photoUploadBlocked
                                              ? Icons.cloud_off_outlined
                                              : Icons.info_outline,
                                          size: 16,
                                          color: _photoUploadBlocked
                                              ? SariSupplyColors.error
                                              : SariSupplyColors.ink600,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            _photoStatus ??
                                                'JPEG, PNG or WebP · Up to 5 MiB · Take photo auto-shrinks',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                    color: _photoUploadBlocked
                                                        ? SariSupplyColors.error
                                                        : SariSupplyColors
                                                            .ink600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: const Text('Use link or preset instead',
                                style: TextStyle(fontSize: 14)),
                            children: [
                              TextFormField(
                                controller: _imageUrl,
                                enabled: !_busy,
                                decoration: InputDecoration(
                                  labelText: 'Image URL (optional)',
                                  hintText: 'https://...',
                                  prefixIcon: const Icon(Icons.link),
                                  suffixIcon: _imageUrl.text.isNotEmpty
                                      ? IconButton(
                                          icon:
                                              const Icon(Icons.clear, size: 18),
                                          onPressed: _busy
                                              ? null
                                              : () => _useImageUrl(''),
                                        )
                                      : null,
                                ),
                                onChanged: (url) => _useImageUrl(url),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final preset in ProductImagePresets.all)
                                    ActionChip(
                                      avatar: Text(preset.emoji),
                                      label: Text(preset.name,
                                          style: const TextStyle(fontSize: 12)),
                                      onPressed: _busy
                                          ? null
                                          : () => _useImageUrl(preset.url),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (widget.product != null) ...[
                    Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Available for sale'),
                                value: _active,
                                onChanged: _busy
                                    ? null
                                    : (v) => setState(() => _active = v)),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _confirmDelete,
                              icon: const Icon(Icons.delete_outline,
                                  color: SariSupplyColors.error),
                              label: const Text(
                                'Delete / Archive Product',
                                style: TextStyle(color: SariSupplyColors.error),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                    color: SariSupplyColors.error),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SariSupplyStatus(
                        message: _error!,
                        error: true,
                        actions: [
                          if (_photoUploadBlocked && !_busy)
                            FilledButton.tonalIcon(
                              onPressed: _saveWithoutPhoto,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save without photo'),
                            ),
                          if ((_photo != null || _imageUrl.text.isNotEmpty) &&
                              !_busy)
                            TextButton(
                              onPressed: () => _useImageUrl(''),
                              child: const Text('Remove photo'),
                            ),
                        ],
                      ),
                    ),
                  if (_busy) const LinearProgressIndicator(),
                ])),
      ));
}
