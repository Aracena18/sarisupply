import 'package:sarisupply_models/sarisupply_models.dart';
import 'inventory_store.dart';

final class CheckoutSync {
  CheckoutSync(this.store, this.gateway, {required this.grantResolver});
  final CheckoutStore store;
  final CheckoutGateway gateway;
  final Future<IssuedCashierGrant?> Function(CheckoutScope) grantResolver;
  bool _running = false;
  Future<bool> run() async {
    if (_running) throw StateError('Sync already running');
    _running = true;
    try {
      for (final intent in await store.pendingIntents()) {
        if (intent.status != 'pending') break;
        final grant = await grantResolver(intent.scope);
        if (grant == null ||
            grant.scope.toMap().toString() != intent.scope.toMap().toString()) {
          break;
        }
        final ack = await gateway.push(intent, grant);
        await store.acknowledge(ack);
        if (!['accepted', 'duplicate'].contains(ack.status)) break;
      }
      return await store.unsettledCount() > 0;
    } finally {
      _running = false;
    }
  }
}
