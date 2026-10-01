final class IssuedCashierPin {
  const IssuedCashierPin({
    required this.cashierId,
    required this.temporaryPin,
    required this.credentialVersion,
  });

  final String cashierId;
  final String temporaryPin;
  final int credentialVersion;
}

final class CashierPinVerification {
  const CashierPinVerification({
    required this.cashierId,
    required this.credentialVersion,
    required this.mustChangePin,
  });

  final String cashierId;
  final int credentialVersion;
  final bool mustChangePin;
}

final class CashierCredentialProjection {
  CashierCredentialProjection({
    required this.cashierId,
    required this.displayName,
    required this.employeeCode,
    required this.status,
    required List<String> assignedBranchIds,
    required this.mustChangePin,
    required this.credentialVersion,
  }) : assignedBranchIds = List.unmodifiable(assignedBranchIds);

  final String cashierId;
  final String displayName;
  final String employeeCode;
  final String status;
  final List<String> assignedBranchIds;
  final bool mustChangePin;
  final int credentialVersion;
}

final class CashierCredentialBundle {
  CashierCredentialBundle({
    required this.merchantId,
    required this.branchId,
    required this.issuedAt,
    required this.expiresAt,
    required List<CashierCredentialProjection> cashiers,
  }) : cashiers = List.unmodifiable(cashiers);

  final String merchantId;
  final String branchId;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final List<CashierCredentialProjection> cashiers;
}

abstract interface class CashierRepository {
  Future<IssuedCashierPin> createCashier({
    required String merchantId,
    required String displayName,
    required String employeeCode,
    required List<String> assignedBranchIds,
  });
  Future<void> setCashierStatus(
      String merchantId, String cashierId, String status);
  Future<CashierPinVerification> verifyPin(String cashierId, String pin);
  Future<int> changePin(String cashierId, String currentPin, String newPin);
  Future<IssuedCashierPin> resetPin(String merchantId, String cashierId);
  Future<CashierCredentialBundle> refreshCredentialBundle();
}
