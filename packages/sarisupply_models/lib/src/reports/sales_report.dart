class TenderBreakdown {
  const TenderBreakdown({
    this.cashCentavos = 0,
    this.qrCentavos = 0,
    this.creditCentavos = 0,
    this.otherCentavos = 0,
  });

  final int cashCentavos;
  final int qrCentavos;
  final int creditCentavos;
  final int otherCentavos;

  int get totalCentavos =>
      cashCentavos + qrCentavos + creditCentavos + otherCentavos;

  Map<String, dynamic> toMap() => {
        'cashCentavos': cashCentavos,
        'qrCentavos': qrCentavos,
        'creditCentavos': creditCentavos,
        'otherCentavos': otherCentavos,
        'totalCentavos': totalCentavos,
      };

  factory TenderBreakdown.fromMap(Map<String, dynamic> map) => TenderBreakdown(
        cashCentavos: (map['cashCentavos'] as num?)?.toInt() ?? 0,
        qrCentavos: (map['qrCentavos'] as num?)?.toInt() ?? 0,
        creditCentavos: (map['creditCentavos'] as num?)?.toInt() ?? 0,
        otherCentavos: (map['otherCentavos'] as num?)?.toInt() ?? 0,
      );
}

class DailySalesSummary {
  const DailySalesSummary({
    required this.date,
    required this.branchId,
    this.grossSalesCentavos = 0,
    this.discountsCentavos = 0,
    this.refundsCentavos = 0,
    this.voidsCentavos = 0,
    this.cashRefundsCentavos = 0,
    this.cashVoidsCentavos = 0,
    this.transactionCount = 0,
    this.tenders = const TenderBreakdown(),
    this.cashInCentavos = 0,
    this.cashOutCentavos = 0,
    this.openingFloatCentavos = 0,
    this.actualCountedCashCentavos,
  });

  final String date;
  final String branchId;
  final int grossSalesCentavos;
  final int discountsCentavos;
  final int refundsCentavos;
  final int voidsCentavos;
  final int cashRefundsCentavos, cashVoidsCentavos;
  final int transactionCount;
  final TenderBreakdown tenders;
  final int cashInCentavos;
  final int cashOutCentavos;
  final int openingFloatCentavos;
  final int? actualCountedCashCentavos;

  int get netSalesCentavos =>
      grossSalesCentavos - discountsCentavos - refundsCentavos - voidsCentavos;

  int get expectedCashCentavos =>
      openingFloatCentavos +
      tenders.cashCentavos +
      cashInCentavos -
      cashOutCentavos -
      cashRefundsCentavos -
      cashVoidsCentavos;

  int? get varianceCentavos => actualCountedCashCentavos != null
      ? actualCountedCashCentavos! - expectedCashCentavos
      : null;

  Map<String, dynamic> toMap() => {
        'date': date,
        'branchId': branchId,
        'grossSalesCentavos': grossSalesCentavos,
        'discountsCentavos': discountsCentavos,
        'refundsCentavos': refundsCentavos,
        'voidsCentavos': voidsCentavos,
        'cashRefundsCentavos': cashRefundsCentavos,
        'cashVoidsCentavos': cashVoidsCentavos,
        'netSalesCentavos': netSalesCentavos,
        'transactionCount': transactionCount,
        'tenders': tenders.toMap(),
        'cashInCentavos': cashInCentavos,
        'cashOutCentavos': cashOutCentavos,
        'openingFloatCentavos': openingFloatCentavos,
        'expectedCashCentavos': expectedCashCentavos,
        'actualCountedCashCentavos': actualCountedCashCentavos,
        'varianceCentavos': varianceCentavos,
      };

  factory DailySalesSummary.fromMap(Map<String, dynamic> map) =>
      DailySalesSummary(
        date: map['date'] as String? ?? '',
        branchId: map['branchId'] as String? ?? '',
        grossSalesCentavos: (map['grossSalesCentavos'] as num?)?.toInt() ?? 0,
        discountsCentavos: (map['discountsCentavos'] as num?)?.toInt() ?? 0,
        refundsCentavos: (map['refundsCentavos'] as num?)?.toInt() ?? 0,
        voidsCentavos: (map['voidsCentavos'] as num?)?.toInt() ?? 0,
        cashRefundsCentavos: (map['cashRefundsCentavos'] as num?)?.toInt() ?? 0,
        cashVoidsCentavos: (map['cashVoidsCentavos'] as num?)?.toInt() ?? 0,
        transactionCount: (map['transactionCount'] as num?)?.toInt() ?? 0,
        tenders: map['tenders'] != null
            ? TenderBreakdown.fromMap(
                Map<String, dynamic>.from(map['tenders'] as Map))
            : const TenderBreakdown(),
        cashInCentavos: (map['cashInCentavos'] as num?)?.toInt() ?? 0,
        cashOutCentavos: (map['cashOutCentavos'] as num?)?.toInt() ?? 0,
        openingFloatCentavos:
            (map['openingFloatCentavos'] as num?)?.toInt() ?? 0,
        actualCountedCashCentavos:
            (map['actualCountedCashCentavos'] as num?)?.toInt(),
      );
}

class ZReading {
  const ZReading({
    required this.id,
    required this.readingNumber,
    required this.shiftId,
    required this.branchId,
    required this.deviceId,
    required this.cashierId,
    required this.cashierName,
    required this.openedAt,
    required this.closedAt,
    required this.openingFloatCentavos,
    required this.grossSalesCentavos,
    required this.netSalesCentavos,
    required this.refundsCentavos,
    required this.voidsCentavos,
    required this.tenders,
    required this.cashInCentavos,
    required this.cashOutCentavos,
    required this.expectedCashCentavos,
    required this.countedCashCentavos,
    required this.varianceCentavos,
    this.cashierNotes = '',
    required this.transactionCount,
  });

  final String id;
  final int readingNumber;
  final String shiftId;
  final String branchId;
  final String deviceId;
  final String cashierId;
  final String cashierName;
  final DateTime openedAt;
  final DateTime closedAt;
  final int openingFloatCentavos;
  final int grossSalesCentavos;
  final int netSalesCentavos;
  final int refundsCentavos;
  final int voidsCentavos;
  final TenderBreakdown tenders;
  final int cashInCentavos;
  final int cashOutCentavos;
  final int expectedCashCentavos;
  final int countedCashCentavos;
  final int varianceCentavos;
  final String cashierNotes;
  final int transactionCount;

  bool get isBalanced => varianceCentavos == 0;
  bool get isShort => varianceCentavos < 0;
  bool get isOver => varianceCentavos > 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'readingNumber': readingNumber,
        'shiftId': shiftId,
        'branchId': branchId,
        'deviceId': deviceId,
        'cashierId': cashierId,
        'cashierName': cashierName,
        'openedAt': openedAt.toIso8601String(),
        'closedAt': closedAt.toIso8601String(),
        'openingFloatCentavos': openingFloatCentavos,
        'grossSalesCentavos': grossSalesCentavos,
        'netSalesCentavos': netSalesCentavos,
        'refundsCentavos': refundsCentavos,
        'voidsCentavos': voidsCentavos,
        'tenders': tenders.toMap(),
        'cashInCentavos': cashInCentavos,
        'cashOutCentavos': cashOutCentavos,
        'expectedCashCentavos': expectedCashCentavos,
        'countedCashCentavos': countedCashCentavos,
        'varianceCentavos': varianceCentavos,
        'cashierNotes': cashierNotes,
        'transactionCount': transactionCount,
      };

  factory ZReading.fromMap(Map<String, dynamic> map) => ZReading(
        id: map['id'] as String? ?? '',
        readingNumber: (map['readingNumber'] as num?)?.toInt() ?? 1,
        shiftId: map['shiftId'] as String? ?? '',
        branchId: map['branchId'] as String? ?? '',
        deviceId: map['deviceId'] as String? ?? '',
        cashierId: map['cashierId'] as String? ?? '',
        cashierName: map['cashierName'] as String? ?? '',
        openedAt: DateTime.tryParse(map['openedAt'] as String? ?? '') ??
            DateTime.now(),
        closedAt: DateTime.tryParse(map['closedAt'] as String? ?? '') ??
            DateTime.now(),
        openingFloatCentavos:
            (map['openingFloatCentavos'] as num?)?.toInt() ?? 0,
        grossSalesCentavos: (map['grossSalesCentavos'] as num?)?.toInt() ?? 0,
        netSalesCentavos: (map['netSalesCentavos'] as num?)?.toInt() ?? 0,
        refundsCentavos: (map['refundsCentavos'] as num?)?.toInt() ?? 0,
        voidsCentavos: (map['voidsCentavos'] as num?)?.toInt() ?? 0,
        tenders: map['tenders'] != null
            ? TenderBreakdown.fromMap(
                Map<String, dynamic>.from(map['tenders'] as Map))
            : const TenderBreakdown(),
        cashInCentavos: (map['cashInCentavos'] as num?)?.toInt() ?? 0,
        cashOutCentavos: (map['cashOutCentavos'] as num?)?.toInt() ?? 0,
        expectedCashCentavos:
            (map['expectedCashCentavos'] as num?)?.toInt() ?? 0,
        countedCashCentavos: (map['countedCashCentavos'] as num?)?.toInt() ?? 0,
        varianceCentavos: (map['varianceCentavos'] as num?)?.toInt() ?? 0,
        cashierNotes: map['cashierNotes'] as String? ?? '',
        transactionCount: (map['transactionCount'] as num?)?.toInt() ?? 0,
      );
}
