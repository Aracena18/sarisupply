import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_pos/features/catalog/product_dialog.dart';

class _Photos implements ProductImageGateway {
  final uploads = <String>[];
  final saves = <String>[];
  @override
  Future<ProductImageRef> uploadProductPhoto(String merchantId,
      String productId, String uploadId, List<int> bytes, String format) async {
    uploads.add(uploadId);
    return const ProductImageRef(
        assetId: 'asset',
        publicId: 'photo',
        version: 1,
        secureUrl: 'https://example.com/photo.webp',
        thumbnailUrl: 'https://example.com/thumb.webp');
  }

  @override
  Future<CatalogProduct> saveProductWithImage(
      String merchantId,
      CatalogProduct product,
      String operationId,
      ProductImageChange change) async {
    saves.add(operationId);
    expect(change.action, 'set');
    expect(change.uploadId, uploads.single);
    if (saves.length == 1) {
      throw FirebaseException(plugin: 'test', code: 'unavailable');
    }
    return product.copyWith(revision: product.revision + 1);
  }
}

void main() {
  testWidgets(
      'uncertain product save retries the same operation without another upload',
      (tester) async {
    final photos = _Photos();
    final product = CatalogProduct(
        id: 'p',
        sku: 'P',
        name: 'Product',
        baseUnit: 'piece',
        revision: 1,
        active: true,
        units: [CatalogUnit(name: 'piece', factor: 1, priceCentavos: 100)]);
    final bytes = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a1ioAAAAASUVORK5CYII=');
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ProductDialog(
      product: product,
      merchantId: 'm',
      photoGateway: photos,
      pickPhoto: (_) async => XFile.fromData(bytes, name: 'photo.png'),
      onSave: (product, operationId) async =>
          throw StateError('Must use photo-aware save'),
    ))));
    await tester.ensureVisible(find.text('Choose photo'));
    await tester.tap(find.text('Choose photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    expect(photos.uploads, hasLength(1));
    expect(photos.saves, hasLength(1));
    expect(find.text('Photo uploaded · Product not saved'), findsOneWidget);
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    expect(photos.uploads, hasLength(1));
    expect(photos.saves, hasLength(2));
    expect(photos.saves[0], photos.saves[1]);
  });
}
