class DeliveryStopItem {
  const DeliveryStopItem({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantityOrdered,
    this.unitName = '',
    this.quantityDelivered = 0,
    this.quantityReturned = 0,
    this.unitCostCentavos = 0,
    this.returnReason,
  });

  final String productId;
  final String productName;
  final String sku;
  final String unitName;
  final int quantityOrdered;
  final int quantityDelivered;
  final int quantityReturned;
  final int unitCostCentavos;
  final String? returnReason;

  int get remainingQuantity =>
      (quantityOrdered - (quantityDelivered + quantityReturned))
          .clamp(0, quantityOrdered);

  bool get isCompleted =>
      (quantityDelivered + quantityReturned) >= quantityOrdered;

  DeliveryStopItem copyWith({
    String? productId,
    String? productName,
    String? sku,
    String? unitName,
    int? quantityOrdered,
    int? quantityDelivered,
    int? quantityReturned,
    int? unitCostCentavos,
    String? returnReason,
  }) =>
      DeliveryStopItem(
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        sku: sku ?? this.sku,
        unitName: unitName ?? this.unitName,
        quantityOrdered: quantityOrdered ?? this.quantityOrdered,
        quantityDelivered: quantityDelivered ?? this.quantityDelivered,
        quantityReturned: quantityReturned ?? this.quantityReturned,
        unitCostCentavos: unitCostCentavos ?? this.unitCostCentavos,
        returnReason: returnReason ?? this.returnReason,
      );

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'unitName': unitName,
        'quantityOrdered': quantityOrdered,
        'quantityDelivered': quantityDelivered,
        'quantityReturned': quantityReturned,
        'unitCostCentavos': unitCostCentavos,
        'returnReason': returnReason,
      };

  factory DeliveryStopItem.fromMap(Map<String, dynamic> map) =>
      DeliveryStopItem(
        productId: map['productId'] as String? ?? '',
        productName: map['productName'] as String? ?? '',
        sku: map['sku'] as String? ?? '',
        unitName: map['unitName'] as String? ?? '',
        quantityOrdered: (map['quantityOrdered'] as num?)?.toInt() ?? 0,
        quantityDelivered: (map['quantityDelivered'] as num?)?.toInt() ?? 0,
        quantityReturned: (map['quantityReturned'] as num?)?.toInt() ?? 0,
        unitCostCentavos: (map['unitCostCentavos'] as num?)?.toInt() ?? 0,
        returnReason: map['returnReason'] as String?,
      );
}
