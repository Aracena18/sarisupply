import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

void main() {
  group('Supplier model', () {
    test('serializes and deserializes correctly', () {
      const supplier = Supplier(
        id: 'sup-1',
        name: 'Mega Distribution Inc.',
        contactPerson: 'Juan Dela Cruz',
        phone: '09171234567',
        email: 'sales@megadist.com',
        address: 'Quezon City',
        leadTimeDays: 3,
      );

      final map = supplier.toMap();
      final fromMap = Supplier.fromMap(map);

      expect(fromMap.id, 'sup-1');
      expect(fromMap.name, 'Mega Distribution Inc.');
      expect(fromMap.leadTimeDays, 3);
      expect(fromMap.active, isTrue);
    });
  });

  group('PurchaseOrder model & Integer Centavos', () {
    test('computes line total and order total in exact centavos', () {
      const line1 = PurchaseOrderLine(
        productId: 'prod-coke',
        productName: 'Coca-Cola 1.5L',
        sku: 'COKE-15',
        quantity: 10,
        unitCostCentavos: 6550, // ₱65.50
        quantityReceived: 4,
      );

      const line2 = PurchaseOrderLine(
        productId: 'prod-chips',
        productName: 'Piattos Cheese',
        sku: 'PIAT-01',
        quantity: 20,
        unitCostCentavos: 1850, // ₱18.50
        quantityReceived: 20,
      );

      expect(line1.totalCostCentavos, 65500); // ₱655.00
      expect(line1.remainingQuantity, 6);
      expect(line1.isFullyReceived, isFalse);

      expect(line2.totalCostCentavos, 37000); // ₱370.00
      expect(line2.remainingQuantity, 0);
      expect(line2.isFullyReceived, isTrue);

      final po = PurchaseOrder(
        id: 'po-101',
        supplierId: 'sup-1',
        supplierName: 'Mega Distribution Inc.',
        warehouseId: 'wh-main',
        status: PurchaseOrderStatus.submitted,
        lines: [line1, line2],
        createdAt: DateTime.utc(2026, 10, 5),
      );

      expect(po.totalCostCentavos, 102500); // ₱1,025.00
      expect(po.isFullyReceived, isFalse);
    });
  });

  group('WarehouseStock Reservation', () {
    test('computes availableQuantity accurately', () {
      const stock = WarehouseStock(
        warehouseId: 'wh-main',
        productId: 'prod-coke',
        physicalQuantity: 100,
        reservedQuantity: 35,
      );

      expect(stock.physicalQuantity, 100);
      expect(stock.reservedQuantity, 35);
      expect(stock.availableQuantity, 65);
    });

    test('clamps availableQuantity to 0 if reserved exceeds physical', () {
      const stock = WarehouseStock(
        warehouseId: 'wh-main',
        productId: 'prod-coke',
        physicalQuantity: 10,
        reservedQuantity: 15,
      );

      expect(stock.availableQuantity, 0);
    });
  });

  group('RestockProposal & Pick/Pack', () {
    test('calculates suggested and approved item sums', () {
      const line1 = RestockProposalLine(
        productId: 'prod-1',
        productName: 'Item 1',
        sku: 'IT-1',
        currentStock: 2,
        suggestedQuantity: 20,
        approvedQuantity: 15,
      );
      const line2 = RestockProposalLine(
        productId: 'prod-2',
        productName: 'Item 2',
        sku: 'IT-2',
        currentStock: 0,
        suggestedQuantity: 50,
        approvedQuantity: 50,
      );

      final proposal = RestockProposal(
        id: 'prop-1',
        branchId: 'b-1',
        warehouseId: 'wh-1',
        status: RestockProposalStatus.approved,
        lines: [line1, line2],
        requestedAt: DateTime.utc(2026, 10, 5),
      );

      expect(proposal.totalSuggestedItems, 70);
      expect(proposal.totalApprovedItems, 65);
    });
  });
}
