import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_pos/features/checkout/barcode_scanner_screen.dart';
import 'package:sarisupply_pos/features/checkout/checkout_screen.dart';
import 'package:sarisupply_pos/features/cashier_auth/domain/cashier_login_service.dart';
import 'ui_fixtures.dart';

class TestCamera implements PhoneBarcodeCamera {
  ValueChanged<String>? detected;
  int starts = 0, stops = 0, disposes = 0, settings = 0;
  bool unavailable = false;
  @override
  Widget preview(ValueChanged<String> onCode) {
    detected = onCode;
    return const SizedBox(height: 160, key: Key('camera'));
  }

  @override
  Future<void> start() async {
    starts++;
    if (unavailable) throw StateError('permission denied');
  }

  @override
  Future<void> stop() async {
    stops++;
  }

  @override
  Future<void> dispose() async {
    disposes++;
  }

  @override
  Future<void> openSettings() async {
    settings++;
  }

  void emit(String code) => detected?.call(code);
}

class InventoryApi extends Fake implements InventoryGateway {
  bool offline = false, denied = false;
  @override
  Future<DeltaPage<CatalogChange>> pullCatalog(
      String m, String b, int c) async {
    if (denied) {
      throw FirebaseFunctionsException(
          code: 'permission-denied', message: 'revoked');
    }
    if (offline) throw StateError('offline secret');
    return DeltaPage(cursor: c, hasMore: false, changes: []);
  }

  @override
  Future<DeltaPage<StockEvent>> pullStock(String m, String b, int c) async =>
      DeltaPage(cursor: c, hasMore: false, changes: []);
}

class CheckoutApi extends Fake implements CheckoutGateway {
  bool offline = true;
  @override
  Future<CheckoutAck> push(CheckoutIntent i, IssuedCashierGrant g) async {
    if (offline) throw StateError('offline secret');
    return CheckoutAck(i.id, 'accepted', sequence: i.kind == 'sale' ? 1 : null);
  }
}

class CheckoutFixture {
  final now = DateTime.utc(2026, 10, 5);
  final scope = CheckoutScope(
      merchantId: 'm',
      branchId: 'b',
      deviceId: 'd',
      cashierId: 'c',
      grantId: 'g',
      credentialVersion: 1);
  final camera = TestCamera(),
      inventory = InventoryApi(),
      gateway = CheckoutApi();
  late Directory dir;
  late InventoryStore store;
  bool authorized = true;
  CashierSession get session =>
      CashierSession(cashierId: 'c', deviceId: 'd', startedAt: now);
  Future<CheckoutAuthorization> authorize() async {
    if (!authorized) throw StateError('expired secret');
    return CheckoutAuthorization(
        scope: scope,
        occurredAt: now,
        merchantName: 'Ana Store',
        branchName: 'Main');
  }

  Future<InventoryStore> open() async =>
      store = await InventoryStore.open(databaseFactoryFfi, '${dir.path}/db',
          merchantId: 'm', branchId: 'b');
  Future<void> create({bool shift = true}) async {
    sqfliteFfiInit();
    dir = await Directory.systemTemp.createTemp('phone-checkout');
    await open();
    final p = CatalogProduct(
        id: 'p',
        sku: 'MILK',
        name: 'Milk',
        baseUnit: 'piece',
        active: true,
        revision: 1,
        units: [
          CatalogUnit(
              name: 'piece', factor: 1, priceCentavos: 1250, barcode: '00123'),
          CatalogUnit(
              name: 'pack', factor: 6, priceCentavos: 7500, barcode: '00124')
        ]);
    await store.applyCatalog(
        DeltaPage(cursor: 1, hasMore: false, changes: [CatalogChange(1, p)]));
    if (shift) {
      await store.checkout.openShift(CheckoutIntent(
          id: 'shift',
          scope: scope,
          shiftId: 'shift',
          ordinal: 1,
          occurredAt: now,
          kind: 'openShift',
          payload: {'floatCentavos': 5000}));
    }
  }

  Widget screen(
          {double scale = 1, double keyboard = 0, CashierSession? cashier}) =>
      fixtureApp(
          CheckoutScreen(
              openStore: open,
              session: cashier ?? session,
              inventoryGateway: inventory,
              checkoutGateway: gateway,
              authorize: () async {
                final a = await authorize();
                if (cashier == null) return a;
                return CheckoutAuthorization(
                    scope: CheckoutScope(
                        merchantId: scope.merchantId,
                        branchId: scope.branchId,
                        deviceId: cashier.deviceId,
                        cashierId: cashier.cashierId,
                        grantId: 'g-other',
                        credentialVersion: 1),
                    occurredAt: a.occurredAt,
                    merchantName: a.merchantName,
                    branchName: a.branchName);
              },
              grantResolver: (s) async => IssuedCashierGrant(
                  scope: s,
                  secret: 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA',
                  issuedAt: now,
                  expiresAt: now.add(const Duration(days: 7))),
              cameraFactory: () => camera,
              onLock: () {}),
          scale: scale,
          keyboard: keyboard);
  Future<void> dispose() async {
    await store.close();
    await dir.delete(recursive: true);
  }
}

Future<void> pumpCheckout(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> scanPack(WidgetTester tester, CheckoutFixture f) async {
  await tester.tap(find.text('Scan'));
  await pumpCheckout(tester);
  f.camera.emit('00124');
  f.camera.emit('00124');
  await pumpCheckout(tester);
}

/// SQLite FFI progresses in real time, independently of the test frame clock.
Future<void> pumpCheckoutUntil(WidgetTester tester, Finder visible) async {
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (visible.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 40)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
