import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  group('BatchExpiryRecord', () {
    test('validates batch record attributes and serialization', () {
      final batch = BatchExpiryRecord(
        productId: 'prod-1',
        batchNumber: 'BATCH-2026-A',
        expiryDate: '2026-12-31',
        quantity: 50,
      );
      expect(batch.productId, 'prod-1');
      expect(batch.batchNumber, 'BATCH-2026-A');
      expect(batch.expiryDate, '2026-12-31');
      expect(batch.quantity, 50);

      final map = batch.toMap();
      final roundtrip = BatchExpiryRecord.fromMap(map);
      expect(roundtrip.productId, batch.productId);
      expect(roundtrip.batchNumber, batch.batchNumber);
      expect(roundtrip.expiryDate, batch.expiryDate);
      expect(roundtrip.quantity, batch.quantity);
    });

    test('rejects invalid batch attributes', () {
      expect(
          () => BatchExpiryRecord(
              productId: '',
              batchNumber: 'B1',
              expiryDate: '2026-12-31',
              quantity: 10),
          throwsArgumentError);
      expect(
          () => BatchExpiryRecord(
              productId: 'p1',
              batchNumber: '',
              expiryDate: '2026-12-31',
              quantity: 10),
          throwsArgumentError);
      expect(
          () => BatchExpiryRecord(
              productId: 'p1',
              batchNumber: 'B1',
              expiryDate: 'invalid-date',
              quantity: 10),
          throwsArgumentError);
      expect(
          () => BatchExpiryRecord(
              productId: 'p1',
              batchNumber: 'B1',
              expiryDate: '2026-12-31',
              quantity: -5),
          throwsArgumentError);
      expect(
          () => BatchExpiryRecord(
              productId: 'p1',
              batchNumber: 'B1',
              expiryDate: '2026-12-31',
              quantity: 0),
          throwsArgumentError);
    });
  });

  group('StockTransferIntent', () {
    test('validates transfer intent attributes and serialization', () {
      final item = StockTransferItem(productId: 'prod-1', quantity: 24);
      final transfer = StockTransferIntent(
        id: 'xfer-1',
        sourceBranchId: 'branch-a',
        destinationBranchId: 'branch-b',
        items: [item],
        occurredAt: DateTime.utc(2026, 10, 5),
        status: StockTransferStatus.dispatched,
      );

      expect(transfer.id, 'xfer-1');
      expect(transfer.sourceBranchId, 'branch-a');
      expect(transfer.destinationBranchId, 'branch-b');
      expect(transfer.items.first.quantity, 24);
      expect(transfer.status, StockTransferStatus.dispatched);

      final map = transfer.toMap();
      final roundtrip = StockTransferIntent.fromMap(map);
      expect(roundtrip.id, transfer.id);
      expect(roundtrip.sourceBranchId, transfer.sourceBranchId);
      expect(roundtrip.destinationBranchId, transfer.destinationBranchId);
      expect(roundtrip.items.first.productId, 'prod-1');
      expect(roundtrip.items.first.quantity, 24);
      expect(roundtrip.status, StockTransferStatus.dispatched);
    });

    test('rejects transfer with same source and destination branch', () {
      expect(
          () => StockTransferIntent(
                id: 'xfer-invalid',
                sourceBranchId: 'branch-a',
                destinationBranchId: 'branch-a',
                items: [
                  StockTransferItem(productId: 'p', quantity: 1),
                ],
                occurredAt: DateTime.utc(2026, 10, 5),
                status: StockTransferStatus.draft,
              ),
          throwsArgumentError);
    });

    test('rejects transfer with empty or invalid items', () {
      expect(
          () => StockTransferIntent(
                id: 'xfer-invalid',
                sourceBranchId: 'branch-a',
                destinationBranchId: 'branch-b',
                items: [],
                occurredAt: DateTime.utc(2026, 10, 5),
                status: StockTransferStatus.draft,
              ),
          throwsArgumentError);

      expect(() => StockTransferItem(productId: 'p', quantity: 0),
          throwsArgumentError);
      expect(() => StockTransferItem(productId: 'p', quantity: -10),
          throwsArgumentError);
    });
  });

  group('Extended StockPosition & StockEvent', () {
    test('allows positive delta for receiving and negative for transferOut',
        () {
      final posIn = StockPosition('p1', 100, 2, delta: 50);
      expect(posIn.delta, 50);
      expect(posIn.quantity, 100);

      final posOut = StockPosition('p1', 50, 3, delta: -50);
      expect(posOut.delta, -50);

      final eventRecv = StockEvent(
        sequence: 10,
        operationId: 'recv-1',
        kind: 'receiving',
        positions: [posIn],
      );
      expect(eventRecv.kind, 'receiving');
      expect(eventRecv.positions.first.delta, 50);

      final eventXferOut = StockEvent(
        sequence: 11,
        operationId: 'xfer-out-1',
        kind: 'transferOut',
        positions: [posOut],
      );
      expect(eventXferOut.kind, 'transferOut');
      expect(eventXferOut.positions.first.delta, -50);
    });

    test(
        'rejects receiving with negative delta and transferOut with positive delta',
        () {
      final posNegative = StockPosition('p1', 50, 2, delta: -10);
      final posPositive = StockPosition('p1', 50, 2, delta: 10);

      expect(
          () => StockEvent(
                sequence: 1,
                operationId: 'bad-recv',
                kind: 'receiving',
                positions: [posNegative],
              ),
          throwsArgumentError);

      expect(
          () => StockEvent(
                sequence: 2,
                operationId: 'bad-xfer-out',
                kind: 'transferOut',
                positions: [posPositive],
              ),
          throwsArgumentError);
    });
  });
}
