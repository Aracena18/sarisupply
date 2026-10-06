import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';

void main() {
  group('ProductImagePresets', () {
    test('suggestForProduct identifies matching presets', () {
      expect(ProductImagePresets.suggestForProduct('Corned Beef Can'),
          contains('unsplash.com'));
      expect(ProductImagePresets.suggestForProduct('Coca Cola 1.5L'),
          contains('unsplash.com'));
      expect(ProductImagePresets.suggestForProduct('Potato Chips Barbeque'),
          contains('unsplash.com'));
      expect(ProductImagePresets.suggestForProduct('Lucky Me Pancit Canton'),
          contains('unsplash.com'));
      expect(ProductImagePresets.suggestForProduct('Nescafe Coffee 3-in-1'),
          contains('unsplash.com'));
      expect(ProductImagePresets.suggestForProduct('Sinandomeng Bigas Rice'),
          contains('unsplash.com'));
      expect(ProductImagePresets.suggestForProduct('Safeguard Soap White'),
          contains('unsplash.com'));
      expect(ProductImagePresets.suggestForProduct('Cooking Oil Bottle'),
          contains('unsplash.com'));
      expect(ProductImagePresets.suggestForProduct('Random Hardware Screw'),
          isNull);
    });
  });

  group('ProductThumbnail Widget', () {
    testWidgets('renders fallback icon when no imageUrl is provided',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductThumbnail(
              productName: 'Instant Noodles Special',
              size: 60,
            ),
          ),
        ),
      );

      expect(find.byType(ProductThumbnail), findsOneWidget);
    });
  });
}
