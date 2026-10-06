import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

class Gateway implements MerchantCallableGateway {
  Map<String, Object?> result = {};
  String? command;
  Map<String, Object?>? payload;
  @override
  Future<Map<String, Object?>> call(
      String name, Map<String, Object?> data) async {
    command = name;
    payload = data;
    return result;
  }
}

void main() {
  test('incoming transfer page keeps cursor and rejects foreign destination',
      () async {
    final transfer = StockTransferIntent(
        id: 'transfer',
        sourceBranchId: 'a',
        destinationBranchId: 'b',
        items: [StockTransferItem(productId: 'p', quantity: 3)],
        occurredAt: DateTime.utc(2026, 10, 6),
        status: StockTransferStatus.dispatched);
    final gateway = Gateway()
      ..result = {
        'transfers': [transfer.toMap()],
        'hasMore': true,
        'nextCursor': 'transfer'
      };
    final adapter = InventoryFunctions(gateway: gateway);
    final page = await adapter.incomingTransfers('m', 'b', cursor: 'previous');
    expect(page.nextCursor, 'transfer');
    expect(gateway.payload!['cursor'], 'previous');
    await expectLater(
        adapter.incomingTransfers('m', 'foreign'), throwsFormatException);
  });
  test('typed catalog page preserves barcode zeroes and integer price',
      () async {
    final gateway = Gateway()
      ..result = {
        'cursor': 1,
        'hasMore': false,
        'changes': [
          {
            'sequence': 1,
            'product': {
              'id': 'p',
              'sku': 'MILK',
              'name': 'Milk',
              'baseUnit': 'piece',
              'active': true,
              'revision': 1,
              'units': [
                {
                  'name': 'piece',
                  'factor': 1,
                  'priceCentavos': 1250,
                  'barcode': '00123'
                }
              ]
            }
          }
        ]
      };
    final adapter = InventoryFunctions(gateway: gateway);
    final page = await adapter.pullCatalog('m', 'b', 0);
    expect(page.changes.single.product.units.single.barcode, '00123');
    expect(gateway.payload,
        {'merchantId': 'm', 'branchId': 'b', 'feed': 'catalog', 'cursor': 0});
  });
  test('wrong or malformed ACK fails without inventing acceptance', () async {
    final gateway = Gateway()
      ..result = {
        'operationId': 'foreign',
        'status': 'accepted',
        'sequence': 1
      };
    final adapter = InventoryFunctions(gateway: gateway);
    const op = StockOperation(
        id: 'mine',
        productId: 'p',
        kind: 'opening',
        quantity: 12,
        expectedRevision: 0,
        reason: 'Initial');
    await expectLater(adapter.push('m', 'b', op), throwsA(anything));
    gateway.result = {'operationId': 'mine', 'status': 'accepted'};
    await expectLater(adapter.push('m', 'b', op), throwsA(anything));
  });

  test('recordReceiving sends proper command and parses StockAck', () async {
    final gateway = Gateway()
      ..result = {
        'operationId': 'recv_1',
        'status': 'accepted',
        'sequence': 5,
      };
    final adapter = InventoryFunctions(gateway: gateway);
    final ack = await adapter.recordReceiving(
      merchantId: 'm1',
      branchId: 'b1',
      operationId: 'recv_1',
      productId: 'p1',
      quantity: 50,
      reason: 'Delivered',
      batchNumber: 'BATCH-A',
      expiryDate: '2026-12-31',
    );
    expect(ack.operationId, 'recv_1');
    expect(ack.status, 'accepted');
    expect(ack.sequence, 5);
    expect(gateway.command, 'recordReceiving');
    expect(gateway.payload!['batchNumber'], 'BATCH-A');
  });

  test('recordStockAdjustment sends proper command and parses StockAck',
      () async {
    final gateway = Gateway()
      ..result = {
        'operationId': 'adj_1',
        'status': 'conflict',
        'message': 'Stock changed',
      };
    final adapter = InventoryFunctions(gateway: gateway);
    final ack = await adapter.recordStockAdjustment(
      merchantId: 'm1',
      branchId: 'b1',
      operationId: 'adj_1',
      productId: 'p1',
      delta: -5,
      expectedRevision: 3,
      reason: 'Spoilage',
    );
    expect(ack.status, 'conflict');
    expect(ack.message, 'Stock changed');
    expect(gateway.command, 'recordStockAdjustment');
  });

  test('branch transfers dispatch and receive properly', () async {
    final gateway = Gateway()
      ..result = {
        'transferId': 't1',
        'status': 'dispatched',
        'sequence': 10,
      };
    final adapter = InventoryFunctions(gateway: gateway);
    final ack1 = await adapter.initiateBranchTransfer(
      merchantId: 'm1',
      sourceBranchId: 'b1',
      destinationBranchId: 'b2',
      transferId: 't1',
      items: [StockTransferItem(productId: 'p1', quantity: 10)],
      reason: 'Transfer',
    );
    expect(ack1.status, 'dispatched');
    expect(gateway.command, 'initiateBranchTransfer');

    gateway.result = {
      'transferId': 't1',
      'status': 'accepted',
      'sequence': 11,
    };
    final ack2 = await adapter.receiveBranchTransfer(
      merchantId: 'm1',
      destinationBranchId: 'b2',
      transferId: 't1',
      operationId: 'recv_t1',
    );
    expect(ack2.status, 'accepted');
    expect(gateway.command, 'receiveBranchTransfer');
  });
}
