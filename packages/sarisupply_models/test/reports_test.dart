import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  group('SalesReport Models', () {
    test('TenderBreakdown computes total accurately', () {
      const breakdown = TenderBreakdown(
        cashCentavos: 125000,
        qrCentavos: 45000,
        creditCentavos: 20000,
      );
      expect(breakdown.totalCentavos, 190000);
      final map = breakdown.toMap();
      final revived = TenderBreakdown.fromMap(map);
      expect(revived.totalCentavos, 190000);
    });

    test('DailySalesSummary computes net sales, expected cash, and variance',
        () {
      final summary = DailySalesSummary(
        date: '2026-10-05',
        branchId: 'b1',
        grossSalesCentavos: 200000,
        discountsCentavos: 5000,
        refundsCentavos: 10000,
        cashRefundsCentavos: 10000,
        voidsCentavos: 5000,
        openingFloatCentavos: 50000,
        tenders: const TenderBreakdown(
          cashCentavos: 150000,
          qrCentavos: 30000,
        ),
        cashInCentavos: 10000,
        cashOutCentavos: 5000,
        actualCountedCashCentavos: 195000,
      );

      // netSales = 200000 - 5000 - 10000 - 5000 = 180000
      expect(summary.netSalesCentavos, 180000);

      // expectedCash = 50000 (float) + 150000 (cash) + 10000 (in) - 5000 (out) - 10000 (refunds) = 195000
      expect(summary.expectedCashCentavos, 195000);

      // variance = 195000 - 195000 = 0
      expect(summary.varianceCentavos, 0);

      final map = summary.toMap();
      final revived = DailySalesSummary.fromMap(map);
      expect(revived.netSalesCentavos, 180000);
      expect(revived.varianceCentavos, 0);
    });

    test('QR refunds leave drawer cash unchanged; cash voids reduce it', () {
      const report = DailySalesSummary(
          date: '2026-10-05',
          branchId: 'b',
          openingFloatCentavos: 1000,
          tenders: TenderBreakdown(cashCentavos: 500),
          refundsCentavos: 300,
          voidsCentavos: 200,
          cashVoidsCentavos: 200);
      expect(report.expectedCashCentavos, 1300);
      expect(
          DailySalesSummary.fromMap(report.toMap()).expectedCashCentavos, 1300);
    });

    test('ZReading balances, overage, and shortage flags work correctly', () {
      final now = DateTime.now();
      final balanced = ZReading(
        id: 'z-01',
        readingNumber: 1,
        shiftId: 'shift-101',
        branchId: 'b1',
        deviceId: 'd1',
        cashierId: 'c1',
        cashierName: 'Maria',
        openedAt: now.subtract(const Duration(hours: 8)),
        closedAt: now,
        openingFloatCentavos: 50000,
        grossSalesCentavos: 100000,
        netSalesCentavos: 100000,
        refundsCentavos: 0,
        voidsCentavos: 0,
        tenders: const TenderBreakdown(cashCentavos: 100000),
        cashInCentavos: 0,
        cashOutCentavos: 0,
        expectedCashCentavos: 150000,
        countedCashCentavos: 150000,
        varianceCentavos: 0,
        transactionCount: 25,
      );
      expect(balanced.isBalanced, isTrue);
      expect(balanced.isShort, isFalse);
      expect(balanced.isOver, isFalse);

      final short = ZReading.fromMap({
        ...balanced.toMap(),
        'varianceCentavos': -2500,
      });
      expect(short.isShort, isTrue);
      expect(short.isBalanced, isFalse);
    });
  });

  group('InventoryValuationReport Models', () {
    test('ProductValuationRow computes totals and profit margin', () {
      const row = ProductValuationRow(
        productId: 'prod-cb',
        sku: 'CB-150',
        name: 'Corned Beef',
        physicalQuantity: 20,
        costPriceCentavos: 3500,
        retailPriceCentavos: 4500,
      );
      expect(row.totalCostValueCentavos, 70000);
      expect(row.totalRetailValueCentavos, 90000);
      expect(row.potentialProfitCentavos, 20000);
    });

    test('InventoryValuationReport aggregates SKUs, low stock and values', () {
      final report = InventoryValuationReport(
        generatedAt: DateTime.now(),
        branchId: 'b1',
        products: const [
          ProductValuationRow(
            productId: 'p1',
            sku: 'SKU1',
            name: 'P1',
            physicalQuantity: 5, // low stock (<= 10)
            costPriceCentavos: 1000,
            retailPriceCentavos: 1500,
          ),
          ProductValuationRow(
            productId: 'p2',
            sku: 'SKU2',
            name: 'P2',
            physicalQuantity: 0, // out of stock
            costPriceCentavos: 2000,
            retailPriceCentavos: 3000,
          ),
          ProductValuationRow(
            productId: 'p3',
            sku: 'SKU3',
            name: 'P3',
            physicalQuantity: 50, // normal stock
            costPriceCentavos: 500,
            retailPriceCentavos: 700,
          ),
        ],
      );

      expect(report.totalSkus, 3);
      expect(report.lowStockCount, 1);
      expect(report.outOfStockCount, 1);
      // Cost: 5*1000 + 0 + 50*500 = 5000 + 25000 = 30000
      expect(report.totalCostValueCentavos, 30000);
      // Retail: 5*1500 + 0 + 50*700 = 7500 + 35000 = 42500
      expect(report.totalRetailValueCentavos, 42500);
      expect(report.totalPotentialProfitCentavos, 12500);
    });
  });

  group('SariNotification Models', () {
    test('SariNotification serializes correctly with category and severity',
        () {
      final notif = SariNotification(
        id: 'notif-1',
        title: 'Low Stock Alert',
        message: 'Corned Beef 150g has 2 units remaining',
        category: NotificationCategory.stock,
        severity: NotificationSeverity.warning,
        createdAt: DateTime.now(),
        actionPayload: const {'productId': 'prod-cb'},
      );

      final map = notif.toMap();
      final revived = SariNotification.fromMap(map);
      expect(revived.id, 'notif-1');
      expect(revived.category, NotificationCategory.stock);
      expect(revived.severity, NotificationSeverity.warning);
      expect(revived.actionPayload['productId'], 'prod-cb');
    });
  });
}
