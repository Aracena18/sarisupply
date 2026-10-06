import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_pos/features/catalog/product_dialog.dart';

void main() {
  testWidgets(
      'small phone form retains zero barcode and exact centavos across uncertain retry',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final attempts = <CatalogProduct>[];
    final ids = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => ProductDialog(onSave: (p, id) async {
                              attempts.add(p);
                              ids.add(id);
                              if (attempts.length == 1) {
                                throw FirebaseException(
                                    plugin: 'test',
                                    code: 'unavailable',
                                    message: 'internal secret');
                              }
                              return CatalogProduct(
                                  id: p.id,
                                  sku: p.sku,
                                  name: p.name,
                                  baseUnit: p.baseUnit,
                                  revision: 1,
                                  active: true,
                                  units: p.units);
                            })),
                    child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Milk');
    await tester.enterText(fields.at(1), 'milk');
    await tester.enterText(fields.at(2), 'piece');
    await tester.enterText(fields.at(3), '12.50');
    await tester.ensureVisible(fields.at(4));
    await tester.enterText(fields.at(4), '00123');
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    expect(find.textContaining('internal secret'), findsNothing);
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    expect(attempts, hasLength(2));
    expect(ids[0], ids[1]);
    expect(attempts[0].id, attempts[1].id);
    expect(attempts[0].units.single.priceCentavos, 1250);
    expect(attempts[0].units.single.barcode, '00123');
    expect(tester.takeException(), isNull);
  });
}
