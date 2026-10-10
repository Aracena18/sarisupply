import 'delivery_proof.dart';
import 'delivery_stop_item.dart';

enum DeliveryStopStatus {
  pending,
  arrived,
  delivered,
  partiallyDelivered,
  failed,
  cancelled;

  String get label {
    switch (this) {
      case DeliveryStopStatus.pending:
        return 'Pending';
      case DeliveryStopStatus.arrived:
        return 'Arrived';
      case DeliveryStopStatus.delivered:
        return 'Delivered';
      case DeliveryStopStatus.partiallyDelivered:
        return 'Partially Delivered';
      case DeliveryStopStatus.failed:
        return 'Failed';
      case DeliveryStopStatus.cancelled:
        return 'Cancelled';
    }
  }

  static DeliveryStopStatus fromString(String val) {
    for (final s in DeliveryStopStatus.values) {
      if (s.name == val) return s;
    }
    return DeliveryStopStatus.pending;
  }
}

class DeliveryStop {
  const DeliveryStop({
    required this.id,
    required this.deliveryRunId,
    required this.sequence,
    required this.destinationId,
    required this.destinationName,
    required this.destinationAddress,
    this.latitude,
    this.longitude,
    this.contactPerson = '',
    this.contactPhone = '',
    this.packageManifestId,
    this.paymentMethod = 'cashOnDelivery',
    this.amountDueCentavos,
    this.status = DeliveryStopStatus.pending,
    this.items = const [],
    this.proof,
    this.failureReason,
    this.notes = '',
  });

  final String id;
  final String deliveryRunId;
  final int sequence;
  final String destinationId;
  final String destinationName;
  final String destinationAddress;
  final double? latitude;
  final double? longitude;
  final String contactPerson;
  final String contactPhone;
  final String? packageManifestId;
  final String paymentMethod;
  final int? amountDueCentavos;
  final DeliveryStopStatus status;
  final List<DeliveryStopItem> items;
  final DeliveryProof? proof;
  final String? failureReason;
  final String notes;

  int get totalOrderedUnits =>
      items.fold(0, (sum, item) => sum + item.quantityOrdered);

  int get totalDeliveredUnits =>
      items.fold(0, (sum, item) => sum + item.quantityDelivered);

  int get totalReturnedUnits =>
      items.fold(0, (sum, item) => sum + item.quantityReturned);

  bool get isCompleted =>
      status == DeliveryStopStatus.delivered ||
      status == DeliveryStopStatus.partiallyDelivered ||
      status == DeliveryStopStatus.failed ||
      status == DeliveryStopStatus.cancelled;

  bool get hasCoordinates => latitude != null && longitude != null;

  DeliveryStop copyWith({
    String? id,
    String? deliveryRunId,
    int? sequence,
    String? destinationId,
    String? destinationName,
    String? destinationAddress,
    double? latitude,
    double? longitude,
    String? contactPerson,
    String? contactPhone,
    String? packageManifestId,
    String? paymentMethod,
    int? amountDueCentavos,
    DeliveryStopStatus? status,
    List<DeliveryStopItem>? items,
    DeliveryProof? proof,
    String? failureReason,
    String? notes,
  }) =>
      DeliveryStop(
        id: id ?? this.id,
        deliveryRunId: deliveryRunId ?? this.deliveryRunId,
        sequence: sequence ?? this.sequence,
        destinationId: destinationId ?? this.destinationId,
        destinationName: destinationName ?? this.destinationName,
        destinationAddress: destinationAddress ?? this.destinationAddress,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        contactPerson: contactPerson ?? this.contactPerson,
        contactPhone: contactPhone ?? this.contactPhone,
        packageManifestId: packageManifestId ?? this.packageManifestId,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        amountDueCentavos: amountDueCentavos ?? this.amountDueCentavos,
        status: status ?? this.status,
        items: items ?? this.items,
        proof: proof ?? this.proof,
        failureReason: failureReason ?? this.failureReason,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'deliveryRunId': deliveryRunId,
        'sequence': sequence,
        'destinationId': destinationId,
        'destinationName': destinationName,
        'destinationAddress': destinationAddress,
        'latitude': latitude,
        'longitude': longitude,
        'contactPerson': contactPerson,
        'contactPhone': contactPhone,
        'packageManifestId': packageManifestId,
        'paymentMethod': paymentMethod,
        'amountDueCentavos': amountDueCentavos,
        'status': status.name,
        'items': items.map((i) => i.toMap()).toList(),
        'proof': proof?.toMap(),
        'failureReason': failureReason,
        'notes': notes,
      };

  factory DeliveryStop.fromMap(Map<String, dynamic> map) => DeliveryStop(
        id: map['id'] as String? ?? '',
        deliveryRunId: map['deliveryRunId'] as String? ?? '',
        sequence: (map['sequence'] as num?)?.toInt() ?? 1,
        destinationId: map['destinationId'] as String? ?? '',
        destinationName: map['destinationName'] as String? ?? '',
        destinationAddress: map['destinationAddress'] as String? ?? '',
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        contactPerson: map['contactPerson'] as String? ?? '',
        contactPhone: map['contactPhone'] as String? ?? '',
        packageManifestId: map['packageManifestId'] as String?,
        paymentMethod: map['paymentMethod'] as String? ?? 'cashOnDelivery',
        amountDueCentavos: (map['amountDueCentavos'] as num?)?.toInt(),
        status: DeliveryStopStatus.fromString(map['status'] as String? ?? ''),
        items: (map['items'] as List<dynamic>? ?? [])
            .map((i) =>
                DeliveryStopItem.fromMap(Map<String, dynamic>.from(i as Map)))
            .toList(),
        proof: map['proof'] != null
            ? DeliveryProof.fromMap(
                Map<String, dynamic>.from(map['proof'] as Map))
            : null,
        failureReason: map['failureReason'] as String?,
        notes: map['notes'] as String? ?? '',
      );
}
