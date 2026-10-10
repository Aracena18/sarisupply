import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  test(
      'managed photo survives catalog serialization, edits and explicit removal',
      () {
    const image = ProductImageRef(
        assetId: 'a',
        publicId: 'tenant/photo',
        version: 2,
        secureUrl: 'https://example.com/detail.webp',
        thumbnailUrl: 'https://example.com/thumb.webp');
    final product = CatalogProduct(
        id: 'p',
        sku: 'P',
        name: 'Product',
        baseUnit: 'piece',
        revision: 1,
        active: true,
        units: [CatalogUnit(name: 'piece', factor: 1, priceCentavos: 100)],
        image: image,
        imageUrl: image.secureUrl);
    final restored = CatalogProduct.fromMap(product.toMap());
    expect(restored.image!.toMap(), image.toMap());
    expect(restored.thumbnailUrl, image.thumbnailUrl);
    expect(restored.copyWith(name: 'Changed').image!.assetId, 'a');
    final cleared = restored.copyWith(clearImage: true);
    expect(cleared.image, isNull);
    expect(cleared.imageUrl, isNull);
    expect(cleared.toMap().containsKey('image'), isFalse);
    expect(ProductImageChange.upload('u').toMap(),
        {'action': 'set', 'uploadId': 'u'});
  });
}
