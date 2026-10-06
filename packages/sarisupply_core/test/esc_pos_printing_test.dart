import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_core/sarisupply_core.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  group('EscPosBuilder', () {
    test('Initializes with ESC @ and paper sizes', () {
      final builder58 = EscPosBuilder(paperSize: EscPosPaperSize.mm58);
      expect(builder58.maxColumns, 32);
      expect(builder58.toBytes().sublist(0, 2), [0x1B, 0x40]);

      final builder80 = EscPosBuilder(paperSize: EscPosPaperSize.mm80);
      expect(builder80.maxColumns, 42);
    });

    test('Generates styling and control commands', () {
      final builder = EscPosBuilder();
      builder
        ..align(EscPosAlign.center)
        ..bold(true)
        ..doubleHeight(true)
        ..textLine('HEADER')
        ..hr()
        ..twoColumns('Milk', 'PHP 50.00')
        ..kickDrawer()
        ..cut();

      final bytes = builder.toBytes();
      expect(bytes.isNotEmpty, true);

      // Contains ESC p drawer pulse
      expect(bytes.contains(0x1B), true);
      // Contains GS V cut
      expect(bytes.contains(0x1D), true);
    });

    test('twoColumns justifies text to exact column width', () {
      final builder = EscPosBuilder(paperSize: EscPosPaperSize.mm58);
      builder.twoColumns('Apple', 'PHP 25.00');
      final str = utf8.decode(builder.toBytes().sublist(2)); // skip ESC @
      final line = str.split('\n').first;
      expect(line.length, 32);
      expect(line.startsWith('Apple'), true);
      expect(line.endsWith('PHP 25.00'), true);
    });
  });

  group('ReceiptFormatter', () {
    test(
        'formatSalesReceipt produces structured document with monospace plaintext',
        () {
      final doc = ReceiptFormatter.formatSalesReceipt(
        merchantName: 'Aling Nena Store',
        branchName: 'Main Barangay',
        saleId: 'SALE-123456789',
        shiftId: 'SHIFT-01',
        cashierName: 'Maria',
        occurredAt: DateTime.utc(2026, 10, 5, 14, 30),
        lines: const [
          ReceiptCartLine(
            name: 'Instant Noodles',
            unit: 'pack',
            quantity: 2,
            unitPriceCentavos: 1500,
            totalCentavos: 3000,
          ),
          ReceiptCartLine(
            name: 'Soft Drink 500ml',
            unit: 'bottle',
            quantity: 1,
            unitPriceCentavos: 2500,
            totalCentavos: 2500,
          ),
        ],
        grossSalesCentavos: 5500,
        discountsCentavos: 500,
        netSalesCentavos: 5000,
        tenderKind: 'Cash',
        amountReceivedCentavos: 10000,
        changeCentavos: 5000,
        paperSize: EscPosPaperSize.mm58,
      );

      expect(doc.bytes.isNotEmpty, true);
      expect(doc.paperSize, EscPosPaperSize.mm58);

      final text = doc.plaintext;
      expect(text.contains('ALING NENA STORE'), true);
      expect(text.contains('Main Barangay'), true);
      expect(text.contains('Instant Noodles'), true);
      expect(text.contains('PHP 30.00'), true);
      expect(text.contains('Soft Drink 500ml'), true);
      expect(text.contains('PHP 25.00'), true);
      expect(text.contains('GROSS TOTAL:'), true);
      expect(text.contains('DISCOUNT:'), true);
      expect(text.contains('NET AMOUNT:'), true);
      expect(text.contains('PHP 50.00'), true);
      expect(text.contains('CHANGE:'), true);
    });

    test('formatZReadingReceipt generates complete financial closing layout',
        () {
      final zReading = ZReading(
        id: 'Z-20261005-001',
        readingNumber: 1,
        shiftId: 'SHIFT-01',
        branchId: 'b1',
        deviceId: 'dev_1',
        cashierId: 'CASHIER-A',
        cashierName: 'Maria Santos',
        openedAt: DateTime.utc(2026, 10, 5, 8, 0),
        closedAt: DateTime.utc(2026, 10, 5, 17, 0),
        openingFloatCentavos: 100000,
        grossSalesCentavos: 250000,
        netSalesCentavos: 235000,
        refundsCentavos: 5000,
        voidsCentavos: 10000,
        transactionCount: 45,
        tenders: const TenderBreakdown(
          cashCentavos: 180000,
          qrCentavos: 50000,
          creditCentavos: 5000,
        ),
        cashInCentavos: 20000,
        cashOutCentavos: 15000,
        expectedCashCentavos: 285000,
        countedCashCentavos: 285000,
        varianceCentavos: 0,
      );

      final doc = ReceiptFormatter.formatZReadingReceipt(
        merchantName: 'SariSupply Hub',
        branchName: 'Branch 1',
        zReading: zReading,
        paperSize: EscPosPaperSize.mm58,
      );

      expect(doc.bytes.isNotEmpty, true);
      final text = doc.plaintext;
      expect(text.contains('OFFICIAL Z-READING'), true);
      expect(text.contains('Z-20261005-001'), true);
      expect(text.contains('SHIFT-01'), true);
      expect(text.contains('Gross Sales:'), true);
      expect(text.contains('NET SALES:'), true);
      expect(text.contains('TENDER BREAKDOWN'), true);
      expect(text.contains('CASH DRAWER RECONCILIATION'), true);
      expect(text.contains('Expected In Drawer:'), true);
      expect(text.contains('Counted In Drawer:'), true);
      expect(text.contains('OVER / (SHORT):'), true);
    });

    test('formatDeliveryReceipt formats delivery proof summary', () {
      final stop = DeliveryStop(
        id: 'stop_1',
        deliveryRunId: 'run_101',
        sequence: 1,
        destinationId: 'dest_1',
        destinationName: 'Ate Joy Store',
        destinationAddress: 'Block 5 Lot 2',
        contactPhone: '09171234567',
        status: DeliveryStopStatus.delivered,
        items: const [
          DeliveryStopItem(
            productId: 'p1',
            productName: 'Evaporated Milk 370ml',
            sku: 'MILK-370',
            unitName: 'can',
            quantityOrdered: 24,
            quantityDelivered: 24,
          ),
        ],
        proof: DeliveryProof(
          id: 'proof_1',
          stopId: 'stop_1',
          recipientName: 'Joy Santos',
          recipientRole: 'Owner',
          signatureSvg: '<svg></svg>',
          cashCollectedCentavos: 120000,
          deliveredAt: DateTime.utc(2026, 10, 5, 11, 15),
        ),
      );

      final doc = ReceiptFormatter.formatDeliveryReceipt(
        merchantName: 'Central Wholesale Depot',
        runId: 'RUN-101',
        stop: stop,
        paperSize: EscPosPaperSize.mm58,
      );

      expect(doc.bytes.isNotEmpty, true);
      final text = doc.plaintext;
      expect(text.contains('DELIVERY RECEIPT'), true);
      expect(text.contains('Ate Joy Store'), true);
      expect(text.contains('Evaporated Milk 370ml'), true);
      expect(text.contains('24/24 can'), true);
      expect(text.contains('Joy Santos'), true);
      expect(text.contains('PHP 1200.00'), true);
    });
  });
}
