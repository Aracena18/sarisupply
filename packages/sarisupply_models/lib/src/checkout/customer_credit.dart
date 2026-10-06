final class CustomerAccount {
  CustomerAccount({
    required this.id,
    required this.name,
    required this.phone,
    required this.creditLimitCentavos,
    this.balanceCentavos = 0,
    this.active = true,
  }) {
    if (id.trim().isEmpty || id.length > 128 || id.contains('/')) {
      throw ArgumentError('Invalid customer ID');
    }
    if (name.trim().isEmpty || name.length > 120) {
      throw ArgumentError('Invalid customer name');
    }
    if (creditLimitCentavos < 0 || creditLimitCentavos > 1000000000) {
      throw ArgumentError('Invalid credit limit');
    }
    if (balanceCentavos < 0 || balanceCentavos > 1000000000) {
      throw ArgumentError('Invalid balance');
    }
  }

  final String id;
  final String name;
  final String phone;
  final int creditLimitCentavos;
  final int balanceCentavos;
  final bool active;

  int get availableCreditCentavos => active
      ? (creditLimitCentavos - balanceCentavos).clamp(0, creditLimitCentavos)
      : 0;

  bool canCharge(int amountCentavos) =>
      active &&
      amountCentavos > 0 &&
      balanceCentavos + amountCentavos <= creditLimitCentavos;

  CustomerAccount withBalance(int newBalance) => CustomerAccount(
        id: id,
        name: name,
        phone: phone,
        creditLimitCentavos: creditLimitCentavos,
        balanceCentavos: newBalance,
        active: active,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'creditLimitCentavos': creditLimitCentavos,
        'balanceCentavos': balanceCentavos,
        'active': active,
      };

  factory CustomerAccount.fromMap(Map<String, Object?> map) => CustomerAccount(
        id: map['id'] as String,
        name: map['name'] as String,
        phone: map['phone'] as String? ?? '',
        creditLimitCentavos: map['creditLimitCentavos'] as int,
        balanceCentavos: map['balanceCentavos'] as int? ?? 0,
        active: map['active'] as bool? ?? true,
      );
}

final class CreditAllowanceGrant {
  CreditAllowanceGrant({
    required this.id,
    required this.customerId,
    required this.deviceId,
    required this.allowedCreditCentavos,
    this.usedCreditCentavos = 0,
    required this.expiresAt,
  }) {
    if (id.trim().isEmpty || id.length > 128) {
      throw ArgumentError('Invalid grant ID');
    }
    if (allowedCreditCentavos <= 0) {
      throw ArgumentError('Allowance must be positive');
    }
    if (usedCreditCentavos < 0 || usedCreditCentavos > allowedCreditCentavos) {
      throw ArgumentError('Used credit exceeds allowed credit');
    }
  }

  final String id;
  final String customerId;
  final String deviceId;
  final int allowedCreditCentavos;
  final int usedCreditCentavos;
  final DateTime expiresAt;

  int get remainingAllowanceCentavos =>
      allowedCreditCentavos - usedCreditCentavos;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  bool canChargeOffline(int amountCentavos, DateTime now) =>
      !isExpiredAt(now) &&
      amountCentavos > 0 &&
      usedCreditCentavos + amountCentavos <= allowedCreditCentavos;

  CreditAllowanceGrant withUsed(int additionalCentavos) => CreditAllowanceGrant(
        id: id,
        customerId: customerId,
        deviceId: deviceId,
        allowedCreditCentavos: allowedCreditCentavos,
        usedCreditCentavos: usedCreditCentavos + additionalCentavos,
        expiresAt: expiresAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'customerId': customerId,
        'deviceId': deviceId,
        'allowedCreditCentavos': allowedCreditCentavos,
        'usedCreditCentavos': usedCreditCentavos,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      };

  factory CreditAllowanceGrant.fromMap(Map<String, Object?> map) =>
      CreditAllowanceGrant(
        id: map['id'] as String,
        customerId: map['customerId'] as String,
        deviceId: map['deviceId'] as String,
        allowedCreditCentavos: map['allowedCreditCentavos'] as int,
        usedCreditCentavos: map['usedCreditCentavos'] as int? ?? 0,
        expiresAt: DateTime.parse(map['expiresAt'] as String),
      );
}

final class DebtRepayment {
  DebtRepayment({
    required this.id,
    required this.customerId,
    required this.amountCentavos,
    required this.tenderKind,
    required this.occurredAt,
    this.shiftId = '',
    this.cashierId = '',
    this.reference = '',
    this.notes = '',
  }) {
    if (id.trim().isEmpty || id.length > 128) {
      throw ArgumentError('Invalid repayment ID');
    }
    if (customerId.trim().isEmpty) {
      throw ArgumentError('Customer ID required');
    }
    if (amountCentavos <= 0 || amountCentavos > 1000000000) {
      throw ArgumentError('Invalid repayment amount');
    }
    if (!const {'cash', 'qr'}.contains(tenderKind)) {
      throw ArgumentError('Repayment tender must be cash or qr');
    }
  }

  final String id;
  final String customerId;
  final int amountCentavos;
  final String tenderKind;
  final DateTime occurredAt;
  final String shiftId;
  final String cashierId;
  final String reference;
  final String notes;

  Map<String, Object?> toMap() => {
        'id': id,
        'customerId': customerId,
        'amountCentavos': amountCentavos,
        'tenderKind': tenderKind,
        'occurredAt': occurredAt.toUtc().toIso8601String(),
        'shiftId': shiftId,
        'cashierId': cashierId,
        'reference': reference,
        'notes': notes,
      };

  factory DebtRepayment.fromMap(Map<String, Object?> map) => DebtRepayment(
        id: map['id'] as String,
        customerId: map['customerId'] as String,
        amountCentavos: map['amountCentavos'] as int,
        tenderKind: map['tenderKind'] as String,
        occurredAt: DateTime.parse(map['occurredAt'] as String),
        shiftId: map['shiftId'] as String? ?? '',
        cashierId: map['cashierId'] as String? ?? '',
        reference: map['reference'] as String? ?? '',
        notes: map['notes'] as String? ?? '',
      );
}
