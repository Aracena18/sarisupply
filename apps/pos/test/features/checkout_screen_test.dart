import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_pos/features/cashier_auth/domain/cashier_login_service.dart';
import '../support/checkout_fixtures.dart';
import '../support/ui_fixtures.dart';

void main() {
  testWidgets('empty cart shows cached products before entering a search',
      (tester) async {
    final f = CheckoutFixture(productName: 'Test product');
    await tester.runAsync(f.create);
    addTearDown(f.dispose);
    fixtureSize(tester, 390);
    await tester.pumpWidget(f.screen());
    await pumpCheckout(tester);
    expect(find.text('Test product'), findsOneWidget);
    await tester.tap(find.text('Test product'));
    await pumpCheckout(tester);
    await tester.tap(find.text('piece · ₱12.50'));
    await pumpCheckout(tester);
    await pumpCheckoutUntil(tester, find.text('Pay ₱12.50'));
    expect(find.text('Pay ₱12.50'), findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '));
    expect(find.byType(ListTile), findsNothing);
    await tester.enterText(find.byKey(const Key('product-search')), 'Test');
    await pumpCheckout(tester);
    expect(find.byType(ListTile), findsOneWidget);
  });
  testWidgets(
      'phone scan selects six-piece pack once and persists cart across restart',
      (tester) async {
    final f = CheckoutFixture(productName: 'Test product');
    await tester.runAsync(f.create);
    addTearDown(f.dispose);
    fixtureSize(tester, 390);
    await tester.pumpWidget(f.screen());
    await pumpCheckout(tester);
    await scanPack(tester, f);
    expect(find.text('1 × pack'), findsOneWidget);
    expect(find.text('Pay ₱75.00'), findsOneWidget);
    expect(
        (await tester.runAsync(() => f.store.checkout.readDraft('d', 'c')))!
            .lines
            .single
            .factor,
        6);
    await tester.pumpWidget(const SizedBox());
    await pumpCheckout(tester);
    await tester.pumpWidget(f.screen());
    await pumpCheckout(tester);
    expect(find.text('1 × pack'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('product-search')), '00123');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await pumpCheckout(tester);
    expect(find.text('1 × piece'), findsOneWidget);
  });
  testWidgets('unknown barcode offers search and cancel keeps cart',
      (tester) async {
    final f = CheckoutFixture(productName: 'Test product');
    await tester.runAsync(f.create);
    addTearDown(f.dispose);
    await tester.pumpWidget(f.screen());
    await pumpCheckout(tester);
    await scanPack(tester, f);
    await tester.tap(find.text('Scan'));
    await pumpCheckout(tester);
    f.camera.emit('00999');
    await pumpCheckout(tester);
    expect(find.text('Barcode not found: 00999'), findsOneWidget);
    expect(find.text('Scan barcode'), findsOneWidget);
    await tester.tap(find.text('Search instead'));
    await pumpCheckout(tester);
    expect(find.text('1 × pack'), findsOneWidget);
  });
  testWidgets(
      'continuous scanning edits quantity and ignores held duplicate barcodes',
      (tester) async {
    final f = CheckoutFixture(productName: 'Test product');
    await tester.runAsync(f.create);
    addTearDown(f.dispose);
    fixtureSize(tester, 390);
    await tester.pumpWidget(f.screen());
    await pumpCheckout(tester);
    await tester.tap(find.text('Scan'));
    await pumpCheckout(tester);
    f.camera.emit('00124');
    await pumpCheckout(tester);
    f.camera.emit('00124');
    await pumpCheckout(tester);
    expect(find.text('1 × pack'), findsOneWidget);
    expect(find.text('Scan barcode'), findsOneWidget);
    await tester.tap(find.byTooltip('Increase Test product pack'));
    await pumpCheckout(tester);
    expect(find.text('2 × pack'), findsOneWidget);
    await tester.tap(find.text('2 × pack'));
    await pumpCheckout(tester);
    f.camera
        .emit('00123'); // A quantity modal must not accept camera detections.
    await tester.enterText(find.byKey(const Key('cart-quantity-input')), '5');
    await tester.tap(find.text('Apply quantity'));
    await pumpCheckout(tester);
    expect(find.text('5 × pack'), findsOneWidget);
    await pumpCheckout(
        tester); // Finish the durable quantity write before detecting another item.
    f.camera.emit('00123');
    await pumpCheckout(tester);
    expect(find.text('1 × piece'), findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join(' | '));
    await tester.ensureVisible(find.text('Scan again'));
    await tester.tap(find.text('Scan again'));
    f.camera.emit('00123');
    await pumpCheckout(tester);
    expect(find.text('2 × piece'), findsOneWidget);
    await tester.tap(find.text('Done · ₱400.00'));
    await pumpCheckout(tester);
    final draft =
        await tester.runAsync(() => f.store.checkout.readDraft('d', 'c'));
    expect(draft!.lines.map((l) => l.quantity), [5, 2]);
    expect(find.text('Pay ₱400.00'), findsOneWidget);
  });
  testWidgets(
      'another cashier cannot inherit a cart or take over the open shift',
      (tester) async {
    final f = CheckoutFixture(productName: 'Test product');
    await tester.runAsync(f.create);
    addTearDown(f.dispose);
    await tester.pumpWidget(f.screen());
    await pumpCheckout(tester);
    await scanPack(tester, f);
    await tester.pumpWidget(const SizedBox());
    await pumpCheckout(tester);
    await tester.pumpWidget(f.screen(
        cashier: CashierSession(
            cashierId: 'other', deviceId: 'd', startedAt: f.now)));
    await pumpCheckout(tester);
    expect(find.text('1 × pack'), findsNothing);
    expect(find.text('The current cashier must sign in to close this shift'),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Scan'))
            .onPressed,
        isNull);
    expect(
        (await tester.runAsync(() => f.store.checkout.readDraft('d', 'c')))!
            .lines,
        hasLength(1));
  });
  for (final width in [320.0, 390.0, 600.0, 1024.0, 1280.0]) {
    testWidgets(
        'checkout targets and cart work at width $width with 200% text and keyboard',
        (tester) async {
      final f = CheckoutFixture(productName: 'Test product');
      await tester.runAsync(f.create);
      addTearDown(f.dispose);
      fixtureSize(tester, width);
      await tester.pumpWidget(f.screen(scale: 2));
      await pumpCheckout(tester);
      await tester.ensureVisible(find.text('Scan'));
      await scanPack(tester, f);
      expect(tester.takeException(), isNull);
      expect(
          tester
              .getSize(find.widgetWithText(FilledButton, 'Pay ₱75.00'))
              .height,
          greaterThanOrEqualTo(48));
      await tester.pumpWidget(f.screen(scale: 2, keyboard: 280));
      await pumpCheckout(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.text('Pay ₱75.00')).bottom,
          lessThanOrEqualTo(564));
    });
  }
  testWidgets(
      'observed server revocation locks payment and retains the saved cart',
      (tester) async {
    final f = CheckoutFixture(productName: 'Test product');
    await tester.runAsync(f.create);
    addTearDown(f.dispose);
    await tester.pumpWidget(f.screen());
    await pumpCheckout(tester);
    await scanPack(tester, f);
    f.inventory.denied = true;
    await tester.ensureVisible(find.text('Sync'));
    await tester.tap(find.text('Sync'));
    await pumpCheckout(tester);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Pay ₱75.00'))
            .onPressed,
        isNull);
    expect(
        (await tester.runAsync(() => f.store.checkout.readDraft('d', 'c')))!
            .lines,
        hasLength(1));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pumpCheckout(tester);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Pay ₱75.00'))
            .onPressed,
        isNull);
  });
}
