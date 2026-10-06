import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import '../support/checkout_fixtures.dart';

void main() {
  testWidgets(
      'cash shows change and double save creates one local receipt despite offline sync',
      (tester) async {
    final f = CheckoutFixture();
    await tester.runAsync(f.create);
    addTearDown(f.dispose);
    await tester.pumpWidget(f.screen());
    await pumpCheckout(tester);
    await scanPack(tester, f);
    await tester.tap(find.text('Pay ₱75.00'));
    await pumpCheckout(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Cash received'), '100.00');
    await pumpCheckout(tester);
    expect(find.text('Change ₱25.00'), findsOneWidget);
    await tester.tap(find.text('Save payment'));
    await tester.tap(find.text('Save payment'));
    await pumpCheckoutUntil(tester, find.text('Receipt'));
    expect(find.text('Receipt'), findsOneWidget);
    expect(find.text('Ana Store'), findsOneWidget);
    expect(find.text('Saved locally · Sync pending'), findsOneWidget);
    final receipts = await tester.runAsync(() => f.store.checkout.receipts());
    expect(receipts, hasLength(1));
    expect(receipts!.single.changeCentavos, 2500);
    await tester.pumpWidget(const SizedBox());
    await pumpCheckout(tester);
  });
  testWidgets(
      'receipt presentation metadata failure retains the sale and recovery without an unhandled error',
      (tester) async {
    final f = CheckoutFixture();
    await tester.runAsync(f.create);
    addTearDown(f.dispose);
    final db = await tester.runAsync(() => databaseFactoryFfi.openDatabase(
        '${f.dir.path}/db',
        options: OpenDatabaseOptions(singleInstance: false)));
    await tester.runAsync(() => db!.execute(
        "CREATE TRIGGER fail_seen BEFORE UPDATE ON checkout_recovery BEGIN SELECT RAISE(ABORT,'disk failure'); END"));
    await tester.pumpWidget(f.screen());
    await pumpCheckout(tester);
    await scanPack(tester, f);
    await tester.tap(find.text('Pay ₱75.00'));
    await pumpCheckout(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Cash received'), '100');
    await pumpCheckout(tester);
    await tester.tap(find.text('Save payment'));
    await pumpCheckoutUntil(tester, find.text('Receipt'));
    await pumpCheckout(tester);
    expect(tester.takeException(), isNull);
    final receipt =
        await tester.runAsync(() => f.store.checkout.unseenReceipt('d', 'c'));
    expect(receipt, isNotNull);
    expect(
        (await tester.runAsync(() => f.store.checkout.receipts()))!.single.id,
        receipt!.id);
    expect(find.text('New sale'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pumpCheckout(tester);
    await tester.runAsync(() => db!.close());
  });
  testWidgets(
      'manual QR requires reference and confirmation; resume keeps draft and expiry blocks save',
      (tester) async {
    final f = CheckoutFixture();
    await tester.runAsync(f.create);
    addTearDown(f.dispose);
    await tester.pumpWidget(f.screen());
    await pumpCheckout(tester);
    await scanPack(tester, f);
    await tester.tap(find.text('Pay ₱75.00'));
    await pumpCheckout(tester);
    await tester.tap(find.text('QR'));
    await pumpCheckout(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Payment reference'), 'bank-001');
    await pumpCheckout(tester);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Save payment'));
    expect(button.onPressed, isNull);
    await tester.tap(find.byType(CheckboxListTile));
    await pumpCheckout(tester);
    f.authorized = false;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpCheckout(tester);
    expect(find.text('Reconnect and sign in to continue checkout'),
        findsOneWidget);
    final draft =
        await tester.runAsync(() => f.store.checkout.readDraft('d', 'c'));
    expect(draft!.qrReference, 'bank-001');
    expect(draft.qrConfirmed, true);
    expect(await tester.runAsync(() => f.store.checkout.receipts()), isEmpty);
  });
  testWidgets(
      'commit failure retains frozen UUID and exact tender for retry after restart',
      (tester) async {
    final f = CheckoutFixture();
    await tester.runAsync(f.create);
    addTearDown(f.dispose);
    await tester.pumpWidget(f.screen());
    await pumpCheckout(tester);
    await scanPack(tester, f);
    await tester.tap(find.text('Pay ₱75.00'));
    await pumpCheckout(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Cash received'), '100');
    await pumpCheckout(tester);
    final db = await tester.runAsync(() => databaseFactoryFfi.openDatabase(
        '${f.dir.path}/db',
        options: OpenDatabaseOptions(singleInstance: false)));
    await tester.runAsync(() => db!.execute(
        "CREATE TRIGGER fail_pay BEFORE INSERT ON checkout_outbox BEGIN SELECT RAISE(ABORT,'disk failure'); END"));
    await tester.tap(find.text('Save payment'));
    await pumpCheckoutUntil(
        tester, find.text('Payment not finished. Retry this saved payment.'));
    final draft =
        await tester.runAsync(() => f.store.checkout.readDraft('d', 'c'));
    final id = draft!.frozenSale!.id;
    expect(find.text('Finish saved payment'), findsOneWidget);
    expect(await tester.runAsync(() => f.store.checkout.receipts()), isEmpty);
    await tester.pumpWidget(const SizedBox());
    await pumpCheckout(tester);
    await tester.runAsync(() => db!.execute('DROP TRIGGER fail_pay'));
    await tester.runAsync(() => db!.close());
    await tester.pumpWidget(f.screen());
    await pumpCheckout(tester);
    await tester.tap(find.text('Finish saved payment'));
    await pumpCheckout(tester);
    await tester.tap(find.text('Finish saved payment'));
    await pumpCheckoutUntil(tester, find.text('Receipt'));
    final receipts = await tester.runAsync(() => f.store.checkout.receipts());
    expect(receipts!.single.id, id);
    expect(receipts.single.tender.receivedCentavos, 10000);
    expect(find.text('Receipt'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await pumpCheckout(tester);
    await tester.pumpWidget(f.screen());
    await pumpCheckout(tester);
    expect(find.text('Receipt'),
        findsNothing); // The receipt was actually presented.
  });
  testWidgets(
      'QR inputs survive wallet switching and restart; QR never increases cash',
      (tester) async {
    final f = CheckoutFixture();
    await tester.runAsync(f.create);
    addTearDown(f.dispose);
    await tester.pumpWidget(f.screen());
    await pumpCheckout(tester);
    await scanPack(tester, f);
    await tester.tap(find.text('Pay ₱75.00'));
    await pumpCheckout(tester);
    await tester.tap(find.text('QR'));
    await pumpCheckout(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Payment reference'), 'wallet-123');
    await pumpCheckout(tester);
    await tester.tap(find.byType(CheckboxListTile));
    await pumpCheckout(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpCheckout(tester);
    await tester.pumpWidget(const SizedBox());
    await pumpCheckout(tester);
    await tester.pumpWidget(f.screen());
    await pumpCheckout(tester);
    await tester.tap(find.text('Pay ₱75.00'));
    await pumpCheckout(tester);
    expect(
        tester
            .widget<TextField>(
                find.widgetWithText(TextField, 'Payment reference'))
            .controller!
            .text,
        'wallet-123');
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        true);
    await tester.tap(find.text('Save payment'));
    await pumpCheckout(tester);
    await pumpCheckoutUntil(tester, find.text('QR · Checked manually'));
    expect(find.text('QR · Checked manually'), findsOneWidget);
    expect(
        (await tester.runAsync(() => f.store.checkout.activeShift('d')))!
            .expectedCashCentavos,
        5000);
    await tester.pumpWidget(const SizedBox());
    await pumpCheckout(tester);
  });
  testWidgets(
      'catalog refresh never silently reprices cart; explicit review updates quote',
      (tester) async {
    final f = CheckoutFixture();
    await tester.runAsync(f.create);
    addTearDown(f.dispose);
    await tester.pumpWidget(f.screen());
    await pumpCheckout(tester);
    await scanPack(tester, f);
    final changed = CatalogProduct(
        id: 'p',
        sku: 'MILK',
        name: 'Milk',
        baseUnit: 'piece',
        active: true,
        revision: 2,
        units: [
          CatalogUnit(
              name: 'piece', factor: 1, priceCentavos: 1500, barcode: '00123'),
          CatalogUnit(
              name: 'pack', factor: 6, priceCentavos: 8000, barcode: '00124')
        ]);
    await tester.runAsync(() => f.store.applyCatalog(DeltaPage(
        cursor: 2, hasMore: false, changes: [CatalogChange(2, changed)])));
    expect(find.text('Pay ₱75.00'), findsOneWidget);
    await tester.tap(find.text('Pay ₱75.00'));
    await pumpCheckout(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'Cash received'), '100');
    await pumpCheckout(tester);
    await tester.tap(find.text('Save payment'));
    await pumpCheckoutUntil(tester,
        find.text('Check payment details or review prices in the cart.'));
    expect(find.text('Check payment details or review prices in the cart.'),
        findsOneWidget);
    expect(await tester.runAsync(() => f.store.checkout.receipts()), isEmpty);
    await tester.pageBack();
    await pumpCheckout(tester);
    await tester.ensureVisible(find.text('Review prices'));
    await tester.tap(find.text('Review prices'));
    await pumpCheckout(tester);
    expect(find.text('₱75.00 → ₱80.00'), findsOneWidget);
    await tester.tap(find.text('Apply changes'));
    await pumpCheckout(tester);
    expect(find.text('Pay ₱80.00'), findsOneWidget);
  });
}
