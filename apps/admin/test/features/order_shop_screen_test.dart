import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_company/src/order_shop_controller.dart';
import 'package:sarisupply_company/src/order_shop_screen.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'order_shop_controller_test.dart' show Memory;

void main() {
  testWidgets(
      'phone ordering retains catalog, validates once and clears only acknowledged cart',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var reads = 0, validations = 0, submitted = 0, cleared = 0;
    final drafts = <Map<String, Object?>>[];
    final product = CompanyRecord({
      'id': 'p',
      'name': 'Product',
      'unit': 'piece',
      'priceCentavos': 100,
      'revision': 1,
      'active': true,
      'availability': 'inStock'
    });
    final catalog = OrderCatalogController(
        storage: Memory(),
        read: (w, q, c) async {
          reads++;
          return CompanyPage(
              records: [product], nextCursor: null, hasMore: false);
        });
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (c) => Scaffold(
                body: TextButton(
                    onPressed: () => Navigator.of(c).push(MaterialPageRoute(
                        builder: (_) => OrderShopScreen(
                            title: 'Company',
                            warehouses: [
                              CompanyRecord({'id': 'w', 'name': 'Warehouse'})
                            ],
                            catalog: catalog,
                            initial: {
                              'warehouseId': 'w',
                              'address': 'Branch address',
                              'contact': 'Owner',
                              'phone': '123'
                            },
                            saveDraft: (v) async {
                              drafts.add(v);
                            },
                            clearDraft: () async {
                              cleared++;
                            },
                            loadPreferences: () async => {},
                            loadMappings: () async => [],
                            validateProducts: (w, ids) async {
                              validations++;
                              return [product];
                            },
                            submit: (v) async {
                              submitted++;
                              expect(v['lines'], [
                                {
                                  'productId': 'p',
                                  'productRevision': 1,
                                  'quantity': 1
                                }
                              ]);
                            },
                            matchProduct: (r) async => null))),
                    child: const Text('Open ordering'))))));
    await tester.tap(find.text('Open ordering'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add product'));
    await tester.pump();
    expect(reads, 1);
    await tester.tap(find.widgetWithText(FilledButton, 'Review order'));
    await tester.pumpAndSettle();
    expect(validations, 1);
    expect(reads, 1);
    await tester
        .ensureVisible(find.widgetWithText(FilledButton, 'Submit order').first);
    await tester.tap(find.widgetWithText(FilledButton, 'Submit order').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash on delivery'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit order').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Submit order').last);
    await tester.pumpAndSettle();
    expect(submitted, 1);
    expect(cleared, 1);
    expect(find.text('Open ordering'), findsOneWidget);
    final count = drafts.length;
    await tester.pump(const Duration(milliseconds: 500));
    expect(drafts.length, count);
    await tester.pumpWidget(const SizedBox());
    catalog.dispose();
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('order review remains reachable with large text at $scale',
        (tester) async {
      tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final product = CompanyRecord({
        'id': 'coffee',
        'name': 'Everyday Essentials Family Value Pack',
        'unit': 'pack',
        'priceCentavos': 1200,
        'revision': 1,
        'active': true,
        'availability': 'inStock',
      });
      final catalog = OrderCatalogController(
          storage: Memory(),
          read: (_, __, ___) async => CompanyPage(
              records: [product], nextCursor: null, hasMore: false));
      var submitted = 0;
      await tester.pumpWidget(MaterialApp(
        theme: SariSupplyTheme.light,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: OrderShopScreen(
          title: 'SariSupply',
          warehouses: [
            CompanyRecord({'id': 'main', 'name': 'Main warehouse'})
          ],
          catalog: catalog,
          initial: {
            'warehouseId': 'main',
            'address': 'Branch address',
            'contact': 'Owner',
            'phone': '123'
          },
          saveDraft: (_) async {},
          clearDraft: () async {},
          loadPreferences: () async => {},
          loadMappings: () async => [],
          validateProducts: (_, __) async => [product],
          submit: (_) async {
            submitted++;
          },
          matchProduct: (_) async => null,
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (var i = 0;
          i < 10 && find.text('Add to order').hitTestable().evaluate().isEmpty;
          i++) {
        await tester.drag(find.byType(CustomScrollView), const Offset(0, -160));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Add to order').hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Review order'));
      await tester.pumpAndSettle();
      expect(find.text('Order total').hitTestable(), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Submit order').hitTestable(),
          findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Submit order'));
      await tester.pumpAndSettle();
      expect(find.text('Cash on delivery').hitTestable(), findsOneWidget);
      expect(submitted, 0);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close review'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      catalog.dispose();
    });
  }
}
