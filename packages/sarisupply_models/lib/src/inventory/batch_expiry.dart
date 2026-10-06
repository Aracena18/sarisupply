final class BatchExpiryRecord {
  BatchExpiryRecord({
    required this.productId,
    required this.batchNumber,
    required this.expiryDate,
    required this.quantity,
  }) {
    if (productId.trim().isEmpty ||
        productId.length > 128 ||
        productId.contains('/') ||
        batchNumber.trim().isEmpty ||
        batchNumber.length > 64 ||
        !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(expiryDate) ||
        quantity <= 0 ||
        quantity > 1000000000) {
      throw ArgumentError('Invalid batch expiry record');
    }
  }

  final String productId;
  final String batchNumber;
  final String expiryDate;
  final int quantity;

  Map<String, Object?> toMap() => {
        'productId': productId,
        'batchNumber': batchNumber,
        'expiryDate': expiryDate,
        'quantity': quantity,
      };

  factory BatchExpiryRecord.fromMap(Map<String, Object?> map) =>
      BatchExpiryRecord(
        productId: map['productId'] as String,
        batchNumber: map['batchNumber'] as String,
        expiryDate: map['expiryDate'] as String,
        quantity: map['quantity'] as int,
      );
}
