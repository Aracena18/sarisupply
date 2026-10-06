import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  group('CatalogProduct image URL support', () {
    test('creates product with optional imageUrl and serializes toMap/fromMap',
        () {
      final product = CatalogProduct(
        id: 'p1',
        sku: 'COKE-CAN',
        name: 'Coca Cola 330ml Can',
        baseUnit: 'can',
        revision: 1,
        active: true,
        imageUrl: 'https://images.unsplash.com/coke.png',
        units: [
          CatalogUnit(name: 'can', factor: 1, priceCentavos: 3500),
        ],
      );

      expect(product.imageUrl, 'https://images.unsplash.com/coke.png');
      final map = product.toMap();
      expect(map['imageUrl'], 'https://images.unsplash.com/coke.png');

      final deserialized = CatalogProduct.fromMap(map);
      expect(deserialized.id, 'p1');
      expect(deserialized.name, 'Coca Cola 330ml Can');
      expect(deserialized.imageUrl, 'https://images.unsplash.com/coke.png');
    });

    test(
        'creates product without imageUrl and preserves null backwards compatibility',
        () {
      final product = CatalogProduct(
        id: 'p2',
        sku: 'RICE-1KG',
        name: 'Sinandomeng Rice 1kg',
        baseUnit: 'kg',
        revision: 0,
        active: true,
        units: [
          CatalogUnit(name: 'kg', factor: 1, priceCentavos: 5200),
        ],
      );

      expect(product.imageUrl, isNull);
      final map = product.toMap();
      expect(map.containsKey('imageUrl'), isFalse);

      final deserialized = CatalogProduct.fromMap(map);
      expect(deserialized.imageUrl, isNull);
    });

    test('copyWith updates imageUrl and active flags correctly', () {
      final product = CatalogProduct(
        id: 'p3',
        sku: 'SOAP-BAR',
        name: 'Bath Soap',
        baseUnit: 'piece',
        revision: 0,
        active: true,
        units: [
          CatalogUnit(name: 'piece', factor: 1, priceCentavos: 2500),
        ],
      );

      final withImage = product.copyWith(
        imageUrl: 'https://example.com/soap.jpg',
      );
      expect(withImage.imageUrl, 'https://example.com/soap.jpg');
      expect(withImage.active, isTrue);

      final archived = withImage.copyWith(active: false);
      expect(archived.active, isFalse);
      expect(archived.imageUrl, 'https://example.com/soap.jpg');
    });
  });
}
