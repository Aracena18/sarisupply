import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_pos/features/checkout/checkout_controller.dart';
import '../support/checkout_fixtures.dart';

void main() {
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
