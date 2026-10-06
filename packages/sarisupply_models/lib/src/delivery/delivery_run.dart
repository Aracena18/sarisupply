import 'delivery_stop.dart';

enum DeliveryRunStatus {
  draft,
  dispatched,
  inTransit,
  completed,
  cancelled;

  String get label {
    switch (this) {
      case DeliveryRunStatus.draft:
        return 'Draft';
      case DeliveryRunStatus.dispatched:
        return 'Dispatched';
      case DeliveryRunStatus.inTransit:
        return 'In Transit';
      case DeliveryRunStatus.completed:
        return 'Completed';
      case DeliveryRunStatus.cancelled:
        return 'Cancelled';
    }
  }

  static DeliveryRunStatus fromString(String val) {
    for (final s in DeliveryRunStatus.values) {
      if (s.name == val) return s;
    }
    return DeliveryRunStatus.draft;
  }
}

class DeliveryRun {
  const DeliveryRun({
    required this.id,
    required this.driverId,
    required this.driverName,
    required this.vehicleInfo,
    required this.warehouseId,
    required this.createdAt,
    this.status = DeliveryRunStatus.draft,
    this.stops = const [],
    this.startedAt,
    this.completedAt,
    this.notes = '',
  });

  final String id;
  final String driverId;
  final String driverName;
  final String vehicleInfo;
  final String warehouseId;
  final DeliveryRunStatus status;
  final List<DeliveryStop> stops;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String notes;

  int get totalStops => stops.length;

  int get completedStops => stops.where((s) => s.isCompleted).length;

  int get pendingStops => stops.where((s) => !s.isCompleted).length;

  int get totalDeliveredUnits =>
      stops.fold(0, (sum, s) => sum + s.totalDeliveredUnits);

  int get totalReturnedUnits =>
      stops.fold(0, (sum, s) => sum + s.totalReturnedUnits);

  bool get isAllStopsCompleted =>
      stops.isNotEmpty && stops.every((s) => s.isCompleted);

  DeliveryRun copyWith({
    String? id,
    String? driverId,
    String? driverName,
    String? vehicleInfo,
    String? warehouseId,
    DeliveryRunStatus? status,
    List<DeliveryStop>? stops,
    DateTime? createdAt,
    DateTime? startedAt,
    DateTime? completedAt,
    String? notes,
  }) =>
      DeliveryRun(
        id: id ?? this.id,
        driverId: driverId ?? this.driverId,
        driverName: driverName ?? this.driverName,
        vehicleInfo: vehicleInfo ?? this.vehicleInfo,
        warehouseId: warehouseId ?? this.warehouseId,
        status: status ?? this.status,
        stops: stops ?? this.stops,
        createdAt: createdAt ?? this.createdAt,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'driverId': driverId,
        'driverName': driverName,
        'vehicleInfo': vehicleInfo,
        'warehouseId': warehouseId,
        'status': status.name,
        'stops': stops.map((s) => s.toMap()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'notes': notes,
      };

  factory DeliveryRun.fromMap(Map<String, dynamic> map) => DeliveryRun(
        id: map['id'] as String? ?? '',
        driverId: map['driverId'] as String? ?? '',
        driverName: map['driverName'] as String? ?? '',
        vehicleInfo: map['vehicleInfo'] as String? ?? '',
        warehouseId: map['warehouseId'] as String? ?? '',
        status: DeliveryRunStatus.fromString(map['status'] as String? ?? ''),
        stops: (map['stops'] as List<dynamic>? ?? [])
            .map((s) =>
                DeliveryStop.fromMap(Map<String, dynamic>.from(s as Map)))
            .toList(),
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
        startedAt: map['startedAt'] != null
            ? DateTime.tryParse(map['startedAt'] as String)
            : null,
        completedAt: map['completedAt'] != null
            ? DateTime.tryParse(map['completedAt'] as String)
            : null,
        notes: map['notes'] as String? ?? '',
      );
}
