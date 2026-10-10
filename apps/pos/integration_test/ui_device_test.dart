import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_pos/features/cashier_auth/domain/cashier_login_service.dart';
import 'package:sarisupply_pos/features/cashier_auth/presentation/cashier_login_screen.dart';
import 'package:sarisupply_pos/features/catalog/catalog_screen.dart';
import 'package:sarisupply_pos/features/catalog/product_dialog.dart';
import 'package:sarisupply_pos/features/management/presentation/management_screen.dart';
import 'package:sqflite/sqflite.dart';

import '../test/support/ui_fixtures.dart';

// Hardware acceptance uses existing screens, fake repositories and an isolated
// in-memory native SQLite database. It makes no Firebase or real storage calls.
Widget deviceApp(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SariSupplyTheme.light,
      builder: (context, child) {
        const scale = String.fromEnvironment('SARISUPPLY_TEST_TEXT_SCALE');
        return scale.isEmpty
            ? child!
            : MediaQuery(
                data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(double.parse(scale))),
                child: child!,
              );
      },
      home: home,
    );

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  var surfaceConverted = false;
  setUp(() => surfaceConverted = false);

  Future<void> capture(WidgetTester tester, String name) async {
    if (!surfaceConverted) {
      await binding.convertFlutterSurfaceToImage();
      surfaceConverted = true;
    }
    await tester.pumpAndSettle();
    final bytes = await binding.takeScreenshot(name);
    final directory =
        Directory('${Directory.systemTemp.path}/sarisupply-ui-device');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png').writeAsBytes(bytes);
  }

  Future<void> keyboard(WidgetTester tester, Finder field) async {
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.view.viewInsets.bottom, greaterThan(0),
        reason: 'The physical Android keyboard must be open');
  }

  testWidgets('cashier modes, PIN failure and real keyboard', (tester) async {
    await tester.pumpWidget(deviceApp(CashierLoginScreen(
      loadCashiers: () async => [
        CashierCredentialProjection(
          cashierId: 'ana',
          displayName: 'Ana Santos',
          employeeCode: 'EMP01',
          status: 'active',
          assignedBranchIds: ['main'],
          mustChangePin: false,
          credentialVersion: 1,
        )
      ],
      onLogin: (_, __) async =>
          const CashierLoginResult(CashierLoginStatus.invalidPin),
      onResult: (_, __) {},
    )));
    await tester.pumpAndSettle();
    await capture(tester, 'cashier');
    await tester.tap(find.text('Use cashier ID'));
    await tester.pumpAndSettle();
    final id = find.widgetWithText(TextField, 'Cashier ID');
    await keyboard(tester, id);
    await tester.enterText(id, 'ana');
    final pin = find.widgetWithText(TextField, 'PIN');
    await tester.ensureVisible(pin);
    await tester.enterText(pin, '1234');
    await tester.ensureVisible(find.text('Sign in'));
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect PIN'), findsOneWidget);
    expect(tester.widget<TextField>(pin).controller!.text, isEmpty);
    expect(tester.widget<TextField>(id).controller!.text, 'ana');
    await tester.ensureVisible(find.text('Choose cashier name'));
    await tester.tap(find.text('Choose cashier name'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('twelve-unit product saves above physical keyboard',
      (tester) async {
    CatalogProduct? saved;
    await tester.pumpWidget(deviceApp(Scaffold(
      body: Builder(
          builder: (context) => Center(
                child: FilledButton(
                  onPressed: () => showSariSupplyForm<bool>(
                    context: context,
                    builder: (_) => ProductDialog(
                      product: fixtureProduct(units: 12),
                      onSave: (product, _) async {
                        saved = product;
                        return product;
                      },
                    ),
                  ),
                  child: const Text('Open form'),
                ),
              )),
    )));
    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    final name = find.widgetWithText(TextFormField, 'Product name');
    await keyboard(tester, name);
    await tester.enterText(name, 'A long product name from a local supplier');
    await tester.pumpAndSettle();
    await capture(tester, 'product-keyboard');
    final action = find.text('Save product');
    expect(
        tester.getRect(action).bottom,
        lessThan(
            tester.view.physicalSize.height / tester.view.devicePixelRatio -
                tester.view.viewInsets.bottom / tester.view.devicePixelRatio));
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(saved!.units.length, 12);
    expect(saved!.units.first.barcode, '000123');
    expect(saved!.units.first.priceCentavos, 5500);
    expect(saved!.name, 'A long product name from a local supplier');
    expect(find.byType(ProductDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('management form cancel stays reachable with keyboard',
      (tester) async {
    await tester.pumpWidget(deviceApp(ManagementScreen(
      memberships: [fixtureMember()],
      management: FixtureManagement(),
      membershipRepository: FixtureMemberships(),
      cashiers: FixtureCashiers(),
      devices: FixtureDevices(),
    )));
    await tester.pumpAndSettle();
    await capture(tester, 'management');
    await tester.tap(find.text('Add cashier'));
    await tester.pumpAndSettle();
    await keyboard(tester, find.widgetWithText(TextFormField, 'Cashier name'));
    await capture(tester, 'management-keyboard');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Santos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('native SQLite inventory, count context and Lock',
      (tester) async {
    final store = await InventoryStore.open(
        databaseFactory, inMemoryDatabasePath,
        merchantId: 'store', branchId: 'main');
    await store.applyCatalog(DeltaPage(
        cursor: 1,
        hasMore: false,
        changes: [CatalogChange(1, fixtureProduct())]));
    await store.applyStock(DeltaPage(cursor: 1, hasMore: false, changes: [
      StockEvent.legacy(const StockChange(1, 'rice', 24, 1, 'cloud'))
    ]));
    bool locked = false;
    await tester.pumpWidget(deviceApp(CatalogScreen(
      branchName: 'Main branch',
      openStore: () async => store,
      gateway: FixtureGateway(),
      canUpload: true,
      canEdit: true,
      onLock: () {
        locked = true;
      },
    )));
    for (var attempt = 0;
        attempt < 50 && find.text('Sinandomeng rice').evaluate().isEmpty;
        attempt++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    expect(find.text('24 in stock bag'), findsOneWidget);
    await capture(tester, 'inventory');
    await tester.ensureVisible(find.text('Sinandomeng rice'));
    await tester.tap(find.text('Sinandomeng rice'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Record count'));
    await tester.tap(find.text('Record count'));
    await tester.pumpAndSettle();
    expect(find.text('Current stock: 24 bag'), findsOneWidget);
    await capture(tester, 'count');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Lock'));
    expect(locked, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
