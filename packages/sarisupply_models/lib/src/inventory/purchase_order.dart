enum PurchaseOrderStatus {
  draft,
  submitted,
  confirmed,
  partiallyReceived,
  completed,
  cancelled;

  String get label {
    switch (this) {
      case PurchaseOrderStatus.draft:
        return 'Draft';
      case PurchaseOrderStatus.submitted:
        return 'Submitted';
      case PurchaseOrderStatus.confirmed:
        return 'Confirmed';
      case PurchaseOrderStatus.partiallyReceived:
        return 'Partially Received';
      case PurchaseOrderStatus.completed:
        return 'Completed';
      case PurchaseOrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  static PurchaseOrderStatus fromString(String val) {
    for (final s in PurchaseOrderStatus.values) {
      if (s.name == val) return s;
    }
    return PurchaseOrderStatus.draft;
  }
}

class PurchaseOrderLine {
  const PurchaseOrderLine({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.quantity,
    required this.unitCostCentavos,
    this.quantityReceived = 0,
  });

  final String productId;
  final String productName;
  final String sku;
  final int quantity;
  final int unitCostCentavos;
  final int quantityReceived;

  int get totalCostCentavos => quantity * unitCostCentavos;
  int get remainingQuantity => (quantity - quantityReceived).clamp(0, quantity);
  bool get isFullyReceived => quantityReceived >= quantity;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'quantity': quantity,
        'unitCostCentavos': unitCostCentavos,
        'quantityReceived': quantityReceived,
      };

  factory PurchaseOrderLine.fromMap(Map<String, dynamic> map) =>
      PurchaseOrderLine(
        productId: map['productId'] as String,
        productName: map['productName'] as String? ?? '',
        sku: map['sku'] as String? ?? '',
        quantity: (map['quantity'] as num?)?.toInt() ?? 0,
        unitCostCentavos: (map['unitCostCentavos'] as num?)?.toInt() ?? 0,
        quantityReceived: (map['quantityReceived'] as num?)?.toInt() ?? 0,
      );

  PurchaseOrderLine copyWith({
    String? productId,
    String? productName,
    String? sku,
    int? quantity,
    int? unitCostCentavos,
    int? quantityReceived,
  }) =>
      PurchaseOrderLine(
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        sku: sku ?? this.sku,
        quantity: quantity ?? this.quantity,
        unitCostCentavos: unitCostCentavos ?? this.unitCostCentavos,
        quantityReceived: quantityReceived ?? this.quantityReceived,
      );
}

class PurchaseOrder {
  const PurchaseOrder({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.warehouseId,
    required this.status,
    required this.lines,
    required this.createdAt,
    this.expectedDeliveryDate,
    this.notes = '',
  });

  final String id;
  final String supplierId;
  final String supplierName;
  final String warehouseId;
  final PurchaseOrderStatus status;
  final List<PurchaseOrderLine> lines;
  final DateTime createdAt;
  final DateTime? expectedDeliveryDate;
  final String notes;

  int get totalCostCentavos =>
      lines.fold(0, (sum, line) => sum + line.totalCostCentavos);

  bool get isFullyReceived =>
      lines.isNotEmpty && lines.every((line) => line.isFullyReceived);

  Map<String, dynamic> toMap() => {
        'id': id,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'warehouseId': warehouseId,
        'status': status.name,
        'lines': lines.map((l) => l.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'expectedDeliveryDate': expectedDeliveryDate?.toIso8601String(),
        'notes': notes,
      };

  factory PurchaseOrder.fromMap(Map<String, dynamic> map) => PurchaseOrder(
        id: map['id'] as String,
        supplierId: map['supplierId'] as String,
        supplierName: map['supplierName'] as String? ?? '',
        warehouseId: map['warehouseId'] as String? ?? 'wh-main',
        status: PurchaseOrderStatus.fromString(map['status'] as String? ?? ''),
        lines: (map['lines'] as List<dynamic>? ?? [])
            .map((e) => PurchaseOrderLine.fromMap(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
        expectedDeliveryDate: map['expectedDeliveryDate'] != null
            ? DateTime.tryParse(map['expectedDeliveryDate'] as String)
            : null,
        notes: map['notes'] as String? ?? '',
      );

  PurchaseOrder copyWith({
    String? id,
    String? supplierId,
    String? supplierName,
    String? warehouseId,
    PurchaseOrderStatus? status,
    List<PurchaseOrderLine>? lines,
    DateTime? createdAt,
    DateTime? expectedDeliveryDate,
    String? notes,
  }) =>
      PurchaseOrder(
        id: id ?? this.id,
        supplierId: supplierId ?? this.supplierId,
        supplierName: supplierName ?? this.supplierName,
        warehouseId: warehouseId ?? this.warehouseId,
        status: status ?? this.status,
        lines: lines ?? this.lines,
        createdAt: createdAt ?? this.createdAt,
        expectedDeliveryDate: expectedDeliveryDate ?? this.expectedDeliveryDate,
        notes: notes ?? this.notes,
      );
}
