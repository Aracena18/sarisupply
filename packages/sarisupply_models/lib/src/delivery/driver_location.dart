/// An ephemeral GPS fix, separate from durable delivery operations.
class DriverLocationFix {
  const DriverLocationFix(
      {required this.latitude,
      required this.longitude,
      required this.accuracyMeters,
      required this.capturedAt});
  final double latitude, longitude, accuracyMeters;
  final DateTime capturedAt;
  Map<String, Object?> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracyMeters': accuracyMeters,
        'capturedAt': capturedAt.toUtc().toIso8601String()
      };
  factory DriverLocationFix.fromMap(Map<String, dynamic> map) =>
      DriverLocationFix(
          latitude: (map['latitude'] as num).toDouble(),
          longitude: (map['longitude'] as num).toDouble(),
          accuracyMeters: (map['accuracyMeters'] as num).toDouble(),
          capturedAt: DateTime.parse(map['capturedAt'] as String));
}

class DriverLocationSnapshot {
  const DriverLocationSnapshot(
      {required this.runId,
      required this.driverId,
      required this.fix,
      required this.receivedAt,
      required this.sharing});
  final String runId, driverId;
  final DriverLocationFix fix;
  final DateTime receivedAt;
  final bool sharing;
  bool isFresh(DateTime now) =>
      sharing &&
      now.difference(receivedAt) <= const Duration(seconds: 90) &&
      now.difference(fix.capturedAt) <= const Duration(seconds: 90);
  factory DriverLocationSnapshot.fromMap(Map<String, dynamic> map) =>
      DriverLocationSnapshot(
          runId: map['runId'] as String,
          driverId: map['driverId'] as String,
          fix: DriverLocationFix.fromMap(map),
          receivedAt: DateTime.parse(map['receivedAt'] as String),
          sharing: map['sharing'] as bool);
}
