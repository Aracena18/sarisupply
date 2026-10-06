class DeliveryProof {
  const DeliveryProof({
    required this.id,
    required this.stopId,
    required this.recipientName,
    required this.recipientRole,
    required this.signatureSvg,
    required this.deliveredAt,
    this.cashCollectedCentavos = 0,
    this.driverNotes = '',
    this.offlineCreated = true,
  });

  final String id;
  final String stopId;
  final String recipientName;
  final String recipientRole;
  final String signatureSvg;
  final DateTime deliveredAt;
  final int cashCollectedCentavos;
  final String driverNotes;
  final bool offlineCreated;

  DeliveryProof copyWith({
    String? id,
    String? stopId,
    String? recipientName,
    String? recipientRole,
    String? signatureSvg,
    DateTime? deliveredAt,
    int? cashCollectedCentavos,
    String? driverNotes,
    bool? offlineCreated,
  }) =>
      DeliveryProof(
        id: id ?? this.id,
        stopId: stopId ?? this.stopId,
        recipientName: recipientName ?? this.recipientName,
        recipientRole: recipientRole ?? this.recipientRole,
        signatureSvg: signatureSvg ?? this.signatureSvg,
        deliveredAt: deliveredAt ?? this.deliveredAt,
        cashCollectedCentavos:
            cashCollectedCentavos ?? this.cashCollectedCentavos,
        driverNotes: driverNotes ?? this.driverNotes,
        offlineCreated: offlineCreated ?? this.offlineCreated,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'stopId': stopId,
        'recipientName': recipientName,
        'recipientRole': recipientRole,
        'signatureSvg': signatureSvg,
        'deliveredAt': deliveredAt.toIso8601String(),
        'cashCollectedCentavos': cashCollectedCentavos,
        'driverNotes': driverNotes,
        'offlineCreated': offlineCreated ? 1 : 0,
      };

  factory DeliveryProof.fromMap(Map<String, dynamic> map) => DeliveryProof(
        id: map['id'] as String? ?? '',
        stopId: map['stopId'] as String? ?? '',
        recipientName: map['recipientName'] as String? ?? '',
        recipientRole: map['recipientRole'] as String? ?? '',
        signatureSvg: map['signatureSvg'] as String? ?? '',
        deliveredAt: DateTime.tryParse(map['deliveredAt'] as String? ?? '') ??
            DateTime.now(),
        cashCollectedCentavos:
            (map['cashCollectedCentavos'] as num?)?.toInt() ?? 0,
        driverNotes: map['driverNotes'] as String? ?? '',
        offlineCreated: (map['offlineCreated'] as num?)?.toInt() == 1 ||
            map['offlineCreated'] == true,
      );
}
