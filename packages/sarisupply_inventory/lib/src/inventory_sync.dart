import 'package:sarisupply_models/sarisupply_models.dart';
import 'inventory_store.dart';

final class InventorySync {
  InventorySync(this.store, this.gateway, {required this.canUpload});
  final InventoryStore store;
  final InventoryGateway gateway;
  final bool canUpload;
  bool _running = false;
  Future<bool> run() async {
    if (_running) throw StateError('Sync already running');
    _running = true;
    var more = false;
    try {
      // Pull first: a missing ACK may already be present in the stock feed.
      for (var i = 0; i < 5; i++) {
        final page = await gateway.pullCatalog(
            store.merchantId, store.branchId, await store.catalogCursor());
        await store.applyCatalog(page);
        if (!page.hasMore) break;
        if (i == 4) more = true;
      }
      for (var i = 0; i < 5; i++) {
        final page = await gateway.pullStock(
            store.merchantId, store.branchId, await store.stockCursor());
        await store.applyStock(page);
        if (!page.hasMore) break;
        if (i == 4) more = true;
      }
      if (canUpload) {
        for (final op in await store.pending()) {
          final ack = await gateway.push(store.merchantId, store.branchId, op);
          await store.acknowledge(op.id, ack);
          if (ack.status == 'accepted' || ack.status == 'duplicate') {
            more = true;
          }
        }
      }
      return more || await store.unsettledCount() > 0;
    } finally {
      _running = false;
    }
  }
}
