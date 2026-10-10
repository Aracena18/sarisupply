import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_company/src/company_stock_product_details.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

CompanyRecord product({int transit = 0}) => CompanyRecord({
      'id': 'product-1',
      'name': 'Another1',
      'sku': 'HDJSIDJJ',
      'priceCentavos': 2300,
      'unit': 'piece',
      'warehouseStock': {
        'physical': 0,
        'reserved': 0,
        'inTransit': transit,
        'quarantined': 0
      },
    });

void main() {
  testWidgets(
      'product sheet prioritizes receiving and hides irrelevant write-off',
      (tester) async {
    String? action;
    await tester.pumpWidget(MaterialApp(
        theme: SariSupplyTheme.light,
        home: Scaffold(
          body: CompanyStockProductDetails(
              product: product(),
              warehouseName: 'Robert',
              owner: true,
              actionsEnabled: true,
              onAction: (value) => action = value,
              onClose: () {}),
        )));
    await tester.pumpAndSettle();
    expect(find.text('Out of stock'), findsOneWidget);
    expect(find.text('0 piece'), findsNWidgets(4));
    expect(find.text('Write off missing transit stock'), findsNothing);
    await tester.tap(find.text('Receive stock'));
    expect(action, 'receiveStock');
    await tester.ensureVisible(find.text('Stock corrections'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stock corrections'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Correct physical stock'));
    await tester.tap(find.text('Correct physical stock'));
    expect(action, 'correctStock');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'disabled sheet fits small phone and large text while preserving stock',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: SariSupplyTheme.light,
      builder: (context, child) => MediaQuery(
          data:
              MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(2)),
          child: child!),
      home: Scaffold(
          body: CompanyStockProductDetails(
        product: product(transit: 3),
        warehouseName: 'Robert warehouse',
        owner: true,
        actionsEnabled: false,
        cached: true,
        onAction: (_) => fail('Cached stock must not enable mutations'),
        onClose: () {},
      )),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(find.text('3 piece'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
