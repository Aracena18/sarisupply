import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_pos/features/checkout/checkout_controller.dart';
import '../support/checkout_fixtures.dart';

void main() {
  test(
      'cart limit preserves twenty products and still permits existing quantities',
      () async {
    final f = CheckoutFixture();
    await f.create();
    addTearDown(f.dispose);
    final c = CheckoutController(
        store: f.store,
        session: f.session,
        authorize: f.authorize,
        inventoryGateway: f.inventory,
        checkoutGateway: f.gateway,
        grantResolver: (_) async => null);
    await c.load();
    final first = c.products.single.product;
    final products = [
      first,
      for (var i = 2; i <= 21; i++)
        CatalogProduct(
            id: 'p$i',
            sku: 'SKU$i',
            name: 'Product $i',
            baseUnit: 'piece',
            active: true,
            revision: 1,
            units: [
              CatalogUnit(
                  name: 'piece', factor: 1, priceCentavos: 100, barcode: '')
            ])
    ];
    await f.store.applyCatalog(DeltaPage(cursor: 21, hasMore: false, changes: [
      for (var i = 1; i < products.length; i++)
        CatalogChange(i + 1, products[i])
    ]));
    for (final p in products.take(20)) {
      await c.add(p, p.units.first);
    }
    await c.add(products.last, products.last.units.first);
    expect(c.draft!.lines.length, 20);
    expect(c.takeNotice(), contains('20 different products'));
    expect((await f.store.checkout.readDraft('d', 'c'))!.lines.length, 20);
    await c.add(first, first.units.first);
    expect(c.draft!.lines.first.quantity, 2);
    expect(c.takeNotice(), isNull);
    c.dispose();
  });

  test(
      'cart adds persist and changed prices can be reviewed before adding again',
      () async {
    final f = CheckoutFixture();
    await f.create();
    addTearDown(f.dispose);
    final c = CheckoutController(
        store: f.store,
        session: f.session,
        authorize: f.authorize,
        inventoryGateway: f.inventory,
        checkoutGateway: f.gateway,
        grantResolver: (_) async => null);
    await c.load();
    final old = c.products.single.product;
    await c.add(old, old.units.first);
    await c.add(old, old.units.first);
    expect(c.draft!.lines.single.quantity, 2);
    expect((await f.store.checkout.readDraft('d', 'c'))!.totalCentavos, 2500);
    final updated = CatalogProduct(
        id: old.id,
        sku: old.sku,
        name: old.name,
        baseUnit: old.baseUnit,
        active: true,
        revision: 2,
        units: [
          CatalogUnit(
              name: 'piece', factor: 1, priceCentavos: 1400, barcode: '00123')
        ]);
    await f.store.applyCatalog(DeltaPage(
        cursor: 2, hasMore: false, changes: [CatalogChange(2, updated)]));
    await c.add(updated, updated.units.first);
    expect(c.draft!.lines.single.priceCentavos, 1250);
    expect(c.draft!.lines.single.quantity, 2);
    expect(c.noticeNeedsPriceReview, isTrue);
    expect(c.takeNotice(), contains('Review prices'));
    expect(c.error, isNull);
    await c.applyPrices(await c.currentPrices());
    await c.add(updated, updated.units.first);
    expect(c.draft!.lines.single.quantity, 3);
    expect(c.draft!.totalCentavos, 4200);
    expect(c.takeNotice(), isNull);
    c.dispose();
  });

  test(
      'authorization started before observed denial cannot restore checkout access',
      () async {
    final f = CheckoutFixture();
    await f.create();
    addTearDown(f.dispose);
    final original = await f.authorize();
    final delayed = Completer<CheckoutAuthorization>();
    var wait = false;
    final c = CheckoutController(
        store: f.store,
        session: f.session,
        authorize: () => wait ? delayed.future : f.authorize(),
        inventoryGateway: f.inventory,
        checkoutGateway: f.gateway,
        grantResolver: (_) async => null);
    await c.load();
    expect(c.allowed, isTrue);
    wait = true;
    final revalidation = c.revalidate();
    f.inventory.denied = true;
    await c.sync();
    expect(c.allowed, isFalse);
    delayed.complete(original);
    expect(await revalidation, isFalse);
    expect(c.allowed, isFalse);
    c.dispose();
  });
}
