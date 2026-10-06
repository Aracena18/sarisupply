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
    dir = await Directory.systemTemp.createTemp('procurement-test-');
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

  test('Supplier and Purchase Order workflow with warehouse stock', () async {
    // 1. Create warehouse and supplier
    const wh = Warehouse(
      id: 'wh-central',
      name: 'Central Warehouse',
      code: 'CWH',
      address: 'Davao City Hub',
    );
    await store.saveWarehouse(wh);

    const sup = Supplier(
      id: 'sup-san-miguel',
      name: 'San Miguel Foods',
      contactPerson: 'Maria Santos',
      phone: '09181234567',
      email: 'orders@sanmiguel.com',
      address: 'Pasig City',
      leadTimeDays: 2,
    );
    await store.saveSupplier(sup);

    final suppliers = await store.listSuppliers();
    expect(suppliers, hasLength(1));
    expect(suppliers.first.name, 'San Miguel Foods');

    // 2. Issue a Purchase Order for 100 cans @ ₱38.00 (3800 centavos)
    final po = PurchaseOrder(
      id: 'po-2026-001',
      supplierId: sup.id,
      supplierName: sup.name,
      warehouseId: wh.id,
      status: PurchaseOrderStatus.submitted,
      lines: const [
        PurchaseOrderLine(
          productId: 'prod-corned-beef',
          productName: 'Purefoods Corned Beef 150g',
          sku: 'CB-150',
          quantity: 100,
          unitCostCentavos: 3800,
        ),
      ],
      createdAt: DateTime.utc(2026, 10, 5),
    );
    await store.savePurchaseOrder(po);

    final pos = await store.listPurchaseOrders();
    expect(pos, hasLength(1));
    expect(pos.first.totalCostCentavos, 380000); // ₱3,800.00

    // 3. Receive partial supplier shipment (40 cans) with lot and expiry
    await store.recordSupplierReceiving(
      poId: 'po-2026-001',
      productId: 'prod-corned-beef',
      quantityReceived: 40,
      batchNumber: 'LOT-CB-101',
      expiryDate: '2028-06-30',
    );

    final updatedPos = await store.listPurchaseOrders();
    expect(updatedPos.first.status, PurchaseOrderStatus.partiallyReceived);
    expect(updatedPos.first.lines.first.quantityReceived, 40);
    expect(updatedPos.first.lines.first.remainingQuantity, 60);

    // Warehouse stock now has 40 physical
    final whStock = await store.getWarehouseStock(
      warehouseId: wh.id,
      productId: 'prod-corned-beef',
    );
    expect(whStock, isNotNull);
    expect(whStock!.physicalQuantity, 40);
    expect(whStock.reservedQuantity, 0);
    expect(whStock.availableQuantity, 40);
  });

  test('Restock proposal, owner approval reservation, pick & pack lifecycle',
      () async {
    const wh = Warehouse(
      id: 'wh-central',
      name: 'Central Warehouse',
      code: 'CWH',
      address: 'Davao City Hub',
    );
    await store.saveWarehouse(wh);

    // Pre-load warehouse with 50 units
    await store.adjustWarehouseStock(
      warehouseId: wh.id,
      productId: 'prod-corned-beef',
      physicalDelta: 50,
    );

    // Branch b1 requests 30 units
    final proposal = RestockProposal(
      id: 'restock-001',
      branchId: 'b1',
      warehouseId: wh.id,
      status: RestockProposalStatus.pendingApproval,
      lines: const [
        RestockProposalLine(
          productId: 'prod-corned-beef',
          productName: 'Purefoods Corned Beef 150g',
          sku: 'CB-150',
          currentStock: 5,
          suggestedQuantity: 30,
        ),
      ],
      requestedAt: DateTime.utc(2026, 10, 5),
    );
    await store.submitRestockProposal(proposal);

    final list = await store.listRestockProposals();
    expect(list, hasLength(1));
    expect(list.first.status, RestockProposalStatus.pendingApproval);

    // Owner reviews and approves 25 units
    await store.reviewRestockProposal(
      proposalId: 'restock-001',
      approved: true,
      reviewedBy: 'owner-juan',
      adjustedLines: [
        proposal.lines.first.copyWith(approvedQuantity: 25),
      ],
    );

    // Verify stock is reserved (physical: 50, reserved: 25, available: 25)
    var stock = await store.getWarehouseStock(
      warehouseId: wh.id,
      productId: 'prod-corned-beef',
    );
    expect(stock!.physicalQuantity, 50);
    expect(stock.reservedQuantity, 25);
    expect(stock.availableQuantity, 25);

    // Warehouse picks items
    await store.startPicking(
        proposalId: 'restock-001', pickerId: 'picker-pedro');
    await store.completePicking(
      proposalId: 'restock-001',
      pickedLines: [
        proposal.lines.first.copyWith(approvedQuantity: 25, pickedQuantity: 25),
      ],
    );

    // Warehouse packs into container
    await store.completePacking(
      proposalId: 'restock-001',
      packageCode: 'BOX-CB-099',
      sealNotes: 'Tamper tape #8841',
    );

    // After packing, physical and reserved stock are deducted:
    // physical was 50 - 25 = 25, reserved was 25 - 25 = 0, available: 25
    stock = await store.getWarehouseStock(
      warehouseId: wh.id,
      productId: 'prod-corned-beef',
    );
    expect(stock!.physicalQuantity, 25);
    expect(stock.reservedQuantity, 0);
    expect(stock.availableQuantity, 25);

    final finalOrders = await store.listRestockProposals();
    expect(finalOrders.first.status, RestockProposalStatus.packed);
  });
}
