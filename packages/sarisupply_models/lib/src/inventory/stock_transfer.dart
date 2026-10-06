enum StockTransferStatus {
  draft,
  dispatched,
  received,
  cancelled,
}

final class StockTransferItem {
  StockTransferItem({
    required this.productId,
    required this.quantity,
  }) {
    if (productId.trim().isEmpty ||
        productId.length > 128 ||
        productId.contains('/') ||
        quantity <= 0 ||
        quantity > 1000000000) {
      throw ArgumentError('Invalid stock transfer item');
    }
  }

  final String productId;
  final int quantity;

  Map<String, Object?> toMap() => {
        'productId': productId,
        'quantity': quantity,
      };

  factory StockTransferItem.fromMap(Map<String, Object?> map) =>
      StockTransferItem(
        productId: map['productId'] as String,
        quantity: map['quantity'] as int,
      );
}

final class StockTransferIntent {
  StockTransferIntent({
    required this.id,
    required this.sourceBranchId,
    required this.destinationBranchId,
    required List<StockTransferItem> items,
    required this.occurredAt,
    this.status = StockTransferStatus.draft,
    this.notes = '',
  }) : items = List.unmodifiable(items) {
    if (id.trim().isEmpty ||
        id.length > 128 ||
        id.contains('/') ||
        sourceBranchId.trim().isEmpty ||
        destinationBranchId.trim().isEmpty ||
        sourceBranchId == destinationBranchId ||
        items.isEmpty ||
        items.length > 50 ||
        items.map((i) => i.productId).toSet().length != items.length) {
      throw ArgumentError('Invalid stock transfer intent');
    }
  }

  final String id;
  final String sourceBranchId;
  final String destinationBranchId;
  final List<StockTransferItem> items;
  final DateTime occurredAt;
  final StockTransferStatus status;
  final String notes;

  Map<String, Object?> toMap() => {
        'id': id,
        'sourceBranchId': sourceBranchId,
        'destinationBranchId': destinationBranchId,
        'items': items.map((i) => i.toMap()).toList(),
        'occurredAt': occurredAt.toIso8601String(),
        'status': status.name,
        if (notes.isNotEmpty) 'notes': notes,
      };

  StockTransferIntent copyWith({
    String? id,
    String? sourceBranchId,
    String? destinationBranchId,
    List<StockTransferItem>? items,
    DateTime? occurredAt,
    StockTransferStatus? status,
    String? notes,
  }) =>
      StockTransferIntent(
        id: id ?? this.id,
        sourceBranchId: sourceBranchId ?? this.sourceBranchId,
        destinationBranchId: destinationBranchId ?? this.destinationBranchId,
        items: items ?? this.items,
        occurredAt: occurredAt ?? this.occurredAt,
        status: status ?? this.status,
        notes: notes ?? this.notes,
      );

  factory StockTransferIntent.fromMap(Map<String, Object?> map) =>
      StockTransferIntent(
        id: map['id'] as String,
        sourceBranchId: map['sourceBranchId'] as String,
        destinationBranchId: map['destinationBranchId'] as String,
        items: (map['items'] as List)
            .map((item) => StockTransferItem.fromMap(
                Map<String, Object?>.from(item as Map)))
            .toList(),
        occurredAt: DateTime.parse(map['occurredAt'] as String),
        status: StockTransferStatus.values.byName(map['status'] as String),
        notes: (map['notes'] as String?) ?? '',
      );
}
