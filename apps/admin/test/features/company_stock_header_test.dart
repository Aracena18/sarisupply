import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_company/src/company_stock_header.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';

void main() {
  testWidgets('stock header in a sliver renders owner actions and filters',
      (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final search = TextEditingController();
    addTearDown(search.dispose);
    var added = 0, received = 0, refreshed = 0;
    await tester.pumpWidget(MaterialApp(
      theme: SariSupplyTheme.light,
      home: Scaffold(
          body: CustomScrollView(slivers: [
        SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList.list(children: [
              CompanyStockHeader(
                owner: true,
                searchController: search,
                onSearch: (_) {},
                onAddProduct: () => added++,
                onReceiveStock: () => received++,
                onRefresh: () => refreshed++,
                filters: const [
                  SizedBox(height: 56, child: Text('All')),
                  SizedBox(height: 56, child: Text('Low stock'))
                ],
                sortControl: const SizedBox(
                    width: 48, height: 48, child: Icon(Icons.tune)),
              ),
            ])),
      ])),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Stock'), findsOneWidget);
    await tester.tap(find.text('Add product'));
    await tester.tap(find.text('Receive stock'));
    await tester.tap(find.byTooltip('Refresh stock'));
    expect([added, received, refreshed], [1, 1, 1]);
    expect(find.text('All').hitTestable(), findsOneWidget);
  });

  testWidgets(
      'loading displays stock controls immediately without enabling writes',
      (tester) async {
    final search = TextEditingController();
    addTearDown(search.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: SingleChildScrollView(
          child: CompanyStockHeader(
        owner: true,
        loading: true,
        searchController: search,
        onSearch: (_) {},
        filters: const [SizedBox(height: 56, child: Text('All'))],
        sortControl: const SizedBox(width: 48, height: 48),
      )),
    )));
    expect(tester.takeException(), isNull);
    expect(find.text('Loading warehouse stock…'), findsOneWidget);
    expect(find.text('Add product'), findsOneWidget);
    expect(find.text('Receive stock'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);
  });
}
