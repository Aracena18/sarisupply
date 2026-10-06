class ProductValuationRow {
  const ProductValuationRow({
    required this.productId,
    required this.sku,
    required this.name,
    this.unitName = 'unit',
    required this.physicalQuantity,
    required this.costPriceCentavos,
    required this.retailPriceCentavos,
  });

  final String productId;
  final String sku;
  final String name;
  final String unitName;
  final int physicalQuantity;
  final int? costPriceCentavos;
  final int retailPriceCentavos;

  int? get totalCostValueCentavos =>
      costPriceCentavos == null ? null : physicalQuantity * costPriceCentavos!;
  int get totalRetailValueCentavos => physicalQuantity * retailPriceCentavos;
  int? get potentialProfitCentavos => totalCostValueCentavos == null
      ? null
      : totalRetailValueCentavos - totalCostValueCentavos!;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'sku': sku,
        'name': name,
        'unitName': unitName,
        'physicalQuantity': physicalQuantity,
        'costPriceCentavos': costPriceCentavos,
        'retailPriceCentavos': retailPriceCentavos,
        'totalCostValueCentavos': totalCostValueCentavos,
        'totalRetailValueCentavos': totalRetailValueCentavos,
        'potentialProfitCentavos': potentialProfitCentavos,
      };

  factory ProductValuationRow.fromMap(Map<String, dynamic> map) =>
      ProductValuationRow(
        productId: map['productId'] as String? ?? '',
        sku: map['sku'] as String? ?? '',
        name: map['name'] as String? ?? '',
        unitName: map['unitName'] as String? ?? 'unit',
        physicalQuantity: (map['physicalQuantity'] as num?)?.toInt() ?? 0,
        costPriceCentavos: (map['costPriceCentavos'] as num?)?.toInt(),
        retailPriceCentavos: (map['retailPriceCentavos'] as num?)?.toInt() ?? 0,
      );
}

class StockMovementSummary {
  const StockMovementSummary({
    this.receivedQuantity = 0,
    this.soldQuantity = 0,
    this.returnedCustomerQuantity = 0,
    this.returnedVendorQuantity = 0,
    this.transferredOutQuantity = 0,
    this.transferredInQuantity = 0,
    this.adjustedQuantity = 0,
    this.wasteQuantity = 0,
  });

  final int receivedQuantity;
  final int soldQuantity;
  final int returnedCustomerQuantity;
  final int returnedVendorQuantity;
  final int transferredOutQuantity;
  final int transferredInQuantity;
  final int adjustedQuantity;
  final int wasteQuantity;

  Map<String, dynamic> toMap() => {
        'receivedQuantity': receivedQuantity,
        'soldQuantity': soldQuantity,
        'returnedCustomerQuantity': returnedCustomerQuantity,
        'returnedVendorQuantity': returnedVendorQuantity,
        'transferredOutQuantity': transferredOutQuantity,
        'transferredInQuantity': transferredInQuantity,
        'adjustedQuantity': adjustedQuantity,
        'wasteQuantity': wasteQuantity,
      };

  factory StockMovementSummary.fromMap(Map<String, dynamic> map) =>
      StockMovementSummary(
        receivedQuantity: (map['receivedQuantity'] as num?)?.toInt() ?? 0,
        soldQuantity: (map['soldQuantity'] as num?)?.toInt() ?? 0,
        returnedCustomerQuantity:
            (map['returnedCustomerQuantity'] as num?)?.toInt() ?? 0,
        returnedVendorQuantity:
            (map['returnedVendorQuantity'] as num?)?.toInt() ?? 0,
        transferredOutQuantity:
            (map['transferredOutQuantity'] as num?)?.toInt() ?? 0,
        transferredInQuantity:
            (map['transferredInQuantity'] as num?)?.toInt() ?? 0,
        adjustedQuantity: (map['adjustedQuantity'] as num?)?.toInt() ?? 0,
        wasteQuantity: (map['wasteQuantity'] as num?)?.toInt() ?? 0,
      );
}

class InventoryValuationReport {
  const InventoryValuationReport({
    required this.generatedAt,
    required this.branchId,
    this.products = const [],
    this.movementSummary,
  });

  final DateTime generatedAt;
  final String branchId;
  final List<ProductValuationRow> products;
  final StockMovementSummary? movementSummary;

  int? get totalCostValueCentavos =>
      products.any((p) => p.costPriceCentavos == null)
          ? null
          : products.fold<int>(0, (sum, p) => sum + p.totalCostValueCentavos!);

  int get totalRetailValueCentavos =>
      products.fold(0, (sum, p) => sum + p.totalRetailValueCentavos);

  int? get totalPotentialProfitCentavos => totalCostValueCentavos == null
      ? null
      : totalRetailValueCentavos - totalCostValueCentavos!;

  int get totalSkus => products.length;

  int get lowStockCount => products
      .where((p) => p.physicalQuantity > 0 && p.physicalQuantity <= 10)
      .length;

  int get outOfStockCount =>
      products.where((p) => p.physicalQuantity <= 0).length;

  Map<String, dynamic> toMap() => {
        'generatedAt': generatedAt.toIso8601String(),
        'branchId': branchId,
        'products': products.map((p) => p.toMap()).toList(),
        'totalCostValueCentavos': totalCostValueCentavos,
        'totalRetailValueCentavos': totalRetailValueCentavos,
        'totalPotentialProfitCentavos': totalPotentialProfitCentavos,
        'totalSkus': totalSkus,
        'lowStockCount': lowStockCount,
        'outOfStockCount': outOfStockCount,
        'movementSummary': movementSummary?.toMap(),
      };

  factory InventoryValuationReport.fromMap(Map<String, dynamic> map) =>
      InventoryValuationReport(
        generatedAt: DateTime.tryParse(map['generatedAt'] as String? ?? '') ??
            DateTime.now(),
        branchId: map['branchId'] as String? ?? '',
        products: (map['products'] as List<dynamic>? ?? [])
            .map((p) => ProductValuationRow.fromMap(
                Map<String, dynamic>.from(p as Map)))
            .toList(),
        movementSummary: map['movementSummary'] != null
            ? StockMovementSummary.fromMap(
                Map<String, dynamic>.from(map['movementSummary'] as Map))
            : null,
      );
}
