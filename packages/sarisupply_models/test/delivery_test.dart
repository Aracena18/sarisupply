import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  group('DeliveryStopItem', () {
    test('computes remainingQuantity and isCompleted correctly', () {
      const item = DeliveryStopItem(
        productId: 'prod-milk',
        productName: 'Bear Brand Powdered Milk 33g',
        sku: 'BB-33G',
        quantityOrdered: 50,
        quantityDelivered: 45,
        quantityReturned: 5,
        unitCostCentavos: 1500,
        returnReason: 'damaged',
      );

      expect(item.remainingQuantity, 0);
      expect(item.isCompleted, true);

      final map = item.toMap();
      final roundTrip = DeliveryStopItem.fromMap(map);
      expect(roundTrip.productId, 'prod-milk');
      expect(roundTrip.quantityDelivered, 45);
      expect(roundTrip.quantityReturned, 5);
      expect(roundTrip.returnReason, 'damaged');
    });

    test('remaining quantity clamps properly on partial delivery', () {
      const partialItem = DeliveryStopItem(
        productId: 'prod-noodles',
        productName: 'Instant Noodles',
        sku: 'IN-01',
        quantityOrdered: 20,
        quantityDelivered: 12,
        quantityReturned: 0,
      );

      expect(partialItem.remainingQuantity, 8);
      expect(partialItem.isCompleted, false);
    });
  });

  group('DeliveryProof', () {
    test('serializes and deserializes proof with signature and cash collected',
        () {
      final now = DateTime.utc(2026, 10, 5, 14, 30);
      final proof = DeliveryProof(
        id: 'proof-001',
        stopId: 'stop-001',
        recipientName: 'Maria Santos',
        recipientRole: 'Store Owner',
        signatureSvg: 'M 10 10 L 20 20 Z',
        deliveredAt: now,
        cashCollectedCentavos: 75000, // ₱750.00
        driverNotes: 'Left package at back counter',
      );

      final map = proof.toMap();
      final roundTrip = DeliveryProof.fromMap(map);

      expect(roundTrip.id, 'proof-001');
      expect(roundTrip.recipientName, 'Maria Santos');
      expect(roundTrip.recipientRole, 'Store Owner');
      expect(roundTrip.cashCollectedCentavos, 75000);
      expect(roundTrip.signatureSvg, 'M 10 10 L 20 20 Z');
      expect(roundTrip.deliveredAt, now);
      expect(roundTrip.offlineCreated, true);
    });
  });

  group('DeliveryStop and DeliveryRun', () {
    test('computes totals across stops and items correctly', () {
      final stop1 = DeliveryStop(
        id: 'stop-1',
        deliveryRunId: 'run-1',
        sequence: 1,
        destinationId: 'branch-1',
        destinationName: 'Aling Nena Store',
        destinationAddress: 'Barangay 1, Davao City',
        status: DeliveryStopStatus.delivered,
        items: const [
          DeliveryStopItem(
            productId: 'prod-1',
            productName: 'Item 1',
            sku: 'SKU-1',
            quantityOrdered: 20,
            quantityDelivered: 20,
          ),
          DeliveryStopItem(
            productId: 'prod-2',
            productName: 'Item 2',
            sku: 'SKU-2',
            quantityOrdered: 10,
            quantityDelivered: 8,
            quantityReturned: 2,
          ),
        ],
      );

      final stop2 = DeliveryStop(
        id: 'stop-2',
        deliveryRunId: 'run-1',
        sequence: 2,
        destinationId: 'branch-2',
        destinationName: 'Mang Tomas Corner Store',
        destinationAddress: 'Barangay 2, Davao City',
        status: DeliveryStopStatus.pending,
        items: const [
          DeliveryStopItem(
            productId: 'prod-1',
            productName: 'Item 1',
            sku: 'SKU-1',
            quantityOrdered: 15,
          ),
        ],
      );

      final run = DeliveryRun(
        id: 'run-1',
        driverId: 'driver-kuya-ben',
        driverName: 'Ben Magtanggol',
        vehicleInfo: 'L300 - ABC 1234',
        warehouseId: 'wh-main',
        createdAt: DateTime.utc(2026, 10, 5, 8, 0),
        status: DeliveryRunStatus.inTransit,
        stops: [stop1, stop2],
      );

      expect(run.totalStops, 2);
      expect(run.completedStops, 1);
      expect(run.pendingStops, 1);
      expect(run.totalDeliveredUnits, 28);
      expect(run.totalReturnedUnits, 2);
      expect(run.isAllStopsCompleted, false);

      final map = run.toMap();
      final roundTrip = DeliveryRun.fromMap(map);
      expect(roundTrip.driverName, 'Ben Magtanggol');
      expect(roundTrip.vehicleInfo, 'L300 - ABC 1234');
      expect(roundTrip.stops.length, 2);
      expect(roundTrip.stops.first.destinationName, 'Aling Nena Store');
    });
  });
}
