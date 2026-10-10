import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  late Directory dir;
  late InventoryStore store;

  final sampleProduct = CatalogProduct(
    id: 'prod-corned-beef',
    sku: 'CB-150',
    name: 'Purefoods Corned Beef 150g',
    baseUnit: 'can',
    active: true,
    revision: 1,
    units: [
      CatalogUnit(
          name: 'can', factor: 1, priceCentavos: 4500, barcode: '12345'),
    ],
  );

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('delivery-test-');
    store = await InventoryStore.open(
      databaseFactoryFfi,
      '${dir.path}/db',
      merchantId: 'm1',
      branchId: 'b1',
    );
    await store.applyCatalog(
      DeltaPage(
          cursor: 1,
          hasMore: false,
          changes: [CatalogChange(1, sampleProduct)]),
    );
  });

  tearDown(() async {
    await store.close();
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  });

  test('Assigned product snapshots load without the retail catalog', () async {
    final run = DeliveryRun(
      id: 'assigned-run',
      driverId: 'rider',
      driverName: 'Rider',
      vehicleInfo: 'Van',
      warehouseId: 'warehouse',
      status: DeliveryRunStatus.dispatched,
      createdAt: DateTime.now(),
      stops: [
        DeliveryStop(
          id: 'assigned-stop',
          deliveryRunId: 'assigned-run',
          sequence: 1,
          destinationId: 'store',
          destinationName: 'Store',
          destinationAddress: 'Address',
          items: const [
            DeliveryStopItem(
              productId: 'uncached-product',
              productName: 'Assigned product',
              sku: 'assigned-sku',
              quantityOrdered: 2,
              quantityDelivered: 0,
              quantityReturned: 0,
              unitCostCentavos: 100,
            )
          ],
        )
      ],
    );
    await store.saveDeliveryRun(run);
    expect(
        (await store.getDeliveryRun(run.id))!
            .stops
            .single
            .items
            .single
            .productId,
        'uncached-product');
    expect(await store.db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });

  test('Delivery run lifecycle, stop status, and doorstep proof with returns',
      () async {
    final now = DateTime.now();

    final run = DeliveryRun(
      id: 'run-001',
      driverId: 'driver-alex',
      driverName: 'Alex Cruz',
      vehicleInfo: 'Van 101 (ABC-1234)',
      warehouseId: 'wh-main',
      status: DeliveryRunStatus.dispatched,
      createdAt: now,
      startedAt: now,
      stops: [
        DeliveryStop(
          id: 'stop-1',
          deliveryRunId: 'run-001',
          sequence: 1,
          destinationId: 'store-aling-nena',
          destinationName: 'Aling Nena Sari-Sari Store',
          destinationAddress: 'Block 4 Lot 12, Barangay Maligaya',
          contactPerson: 'Elena Cruz',
          contactPhone: '09171234567',
          status: DeliveryStopStatus.pending,
          items: const [
            DeliveryStopItem(
              productId: 'prod-corned-beef',
              productName: 'Purefoods Corned Beef 150g',
              sku: 'CB-150',
              quantityOrdered: 10,
              quantityDelivered: 0,
              quantityReturned: 0,
              unitCostCentavos: 4500,
            ),
          ],
        ),
      ],
    );

    // 1. Save and retrieve run
    await store.saveDeliveryRun(run);
    final runs = await store.listDeliveryRuns(driverId: 'driver-alex');
    expect(runs.length, 1);
    expect(runs.first.id, 'run-001');
    expect(runs.first.driverName, 'Alex Cruz');
    expect(runs.first.status, DeliveryRunStatus.dispatched);
    expect(runs.first.stops.length, 1);

    // 2. Update stop status to arrived
    await store.updateStopStatus(
      runId: 'run-001',
      stopId: 'stop-1',
      status: DeliveryStopStatus.arrived,
    );
    var updated = await store.getDeliveryRun('run-001');
    expect(updated?.stops.first.status, DeliveryStopStatus.arrived);
    expect(updated?.status, DeliveryRunStatus.inTransit);

    // 3. Record proof with partial return (8 delivered, 2 returned damaged)
    final proof = DeliveryProof(
      id: 'proof-1',
      stopId: 'stop-1',
      recipientName: 'Elena Cruz',
      recipientRole: 'Store Owner',
      signatureSvg: 'M10 10 L20 20',
      cashCollectedCentavos: 36000,
      deliveredAt: DateTime.now(),
    );
    final deliveredItems = [
      const DeliveryStopItem(
        productId: 'prod-corned-beef',
        productName: 'Purefoods Corned Beef 150g',
        sku: 'CB-150',
        quantityOrdered: 10,
        quantityDelivered: 8,
        quantityReturned: 2,
        unitCostCentavos: 4500,
        returnReason: 'Dented cans',
      ),
    ];

    await store.recordDeliveryProof(
      runId: 'run-001',
      stopId: 'stop-1',
      proof: proof,
      items: deliveredItems,
    );

    // 4. Verify stop is partiallyDelivered and run is completed
    updated = await store.getDeliveryRun('run-001');
    expect(updated, isNotNull);
    final finishedStop = updated!.stops.first;
    expect(finishedStop.status, DeliveryStopStatus.partiallyDelivered);
    expect(finishedStop.proof?.recipientName, 'Elena Cruz');
    expect(finishedStop.proof?.cashCollectedCentavos, 36000);
    expect(finishedStop.items.first.quantityDelivered, 8);
    expect(finishedStop.items.first.quantityReturned, 2);
    expect(finishedStop.items.first.returnReason, 'Dented cans');
    expect(updated.status, DeliveryRunStatus.completed);
    expect(updated.completedAt, isNotNull);

    // Recreate the legacy v10 constraint to exercise the upgrade with existing
    // delivery facts and pending operations, rather than an empty database.
    final pending = await store.pendingDeliveries();
    final itemRows = await store.db.query('delivery_stop_items');
    await store.db.execute('''CREATE TABLE legacy_items (
      id TEXT PRIMARY KEY, stop_id TEXT NOT NULL REFERENCES delivery_stops(id),
      product_id TEXT NOT NULL REFERENCES products(id), quantity_ordered INTEGER NOT NULL,
      quantity_delivered INTEGER NOT NULL, quantity_returned INTEGER NOT NULL, return_reason TEXT)''');
    await store.db
        .execute('INSERT INTO legacy_items SELECT * FROM delivery_stop_items');
    await store.db.execute('DROP TABLE delivery_stop_items');
    await store.db
        .execute('ALTER TABLE legacy_items RENAME TO delivery_stop_items');
    await store.db.execute('PRAGMA user_version = 10');
    await store.close();
    store = await InventoryStore.open(databaseFactoryFfi, '${dir.path}/db',
        merchantId: 'm1', branchId: 'b1');
    expect(await store.db.query('delivery_stop_items'), itemRows);
    expect(await store.pendingDeliveries(), pending);
    expect(
        (await store.getDeliveryRun('run-001'))!
            .stops
            .single
            .proof!
            .cashCollectedCentavos,
        36000);
    expect(await store.db.rawQuery('PRAGMA foreign_key_check'), isEmpty);
  });
}
