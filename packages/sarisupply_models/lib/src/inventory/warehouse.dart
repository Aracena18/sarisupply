class Warehouse {
  const Warehouse({
    required this.id,
    required this.name,
    required this.code,
    required this.address,
    this.active = true,
  });

  final String id;
  final String name;
  final String code;
  final String address;
  final bool active;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'code': code,
        'address': address,
        'active': active,
      };

  factory Warehouse.fromMap(Map<String, dynamic> map) => Warehouse(
        id: map['id'] as String,
        name: map['name'] as String,
        code: map['code'] as String? ?? '',
        address: map['address'] as String? ?? '',
        active: (map['active'] as bool?) ?? true,
      );

  Warehouse copyWith({
    String? id,
    String? name,
    String? code,
    String? address,
    bool? active,
  }) =>
      Warehouse(
        id: id ?? this.id,
        name: name ?? this.name,
        code: code ?? this.code,
        address: address ?? this.address,
        active: active ?? this.active,
      );
}

class WarehouseStock {
  const WarehouseStock({
    required this.warehouseId,
    required this.productId,
    required this.physicalQuantity,
    this.reservedQuantity = 0,
  });

  final String warehouseId;
  final String productId;
  final int physicalQuantity;
  final int reservedQuantity;

  int get availableQuantity =>
      (physicalQuantity - reservedQuantity).clamp(0, physicalQuantity);

  Map<String, dynamic> toMap() => {
        'warehouseId': warehouseId,
        'productId': productId,
        'physicalQuantity': physicalQuantity,
        'reservedQuantity': reservedQuantity,
      };

  factory WarehouseStock.fromMap(Map<String, dynamic> map) => WarehouseStock(
        warehouseId: map['warehouseId'] as String,
        productId: map['productId'] as String,
        physicalQuantity: (map['physicalQuantity'] as num?)?.toInt() ?? 0,
        reservedQuantity: (map['reservedQuantity'] as num?)?.toInt() ?? 0,
      );

  WarehouseStock copyWith({
    String? warehouseId,
    String? productId,
    int? physicalQuantity,
    int? reservedQuantity,
  }) =>
      WarehouseStock(
        warehouseId: warehouseId ?? this.warehouseId,
        productId: productId ?? this.productId,
        physicalQuantity: physicalQuantity ?? this.physicalQuantity,
        reservedQuantity: reservedQuantity ?? this.reservedQuantity,
      );
}
