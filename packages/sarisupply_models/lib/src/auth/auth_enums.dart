enum MerchantApplicationStatus {
  draft('draft'),
  submitted('submitted'),
  resubmitted('resubmitted'),
  pendingReview('pending_review'),
  approved('approved'),
  rejected('rejected');

  const MerchantApplicationStatus(this.wireValue);
  final String wireValue;

  static MerchantApplicationStatus fromWireValue(String value) =>
      values.firstWhere(
        (status) => status.wireValue == value,
        orElse: () => throw ArgumentError.value(value, 'status'),
      );
}

enum MerchantRole {
  owner('owner'),
  manager('manager');

  const MerchantRole(this.wireValue);
  final String wireValue;

  static MerchantRole fromWireValue(String value) => values.firstWhere(
        (role) => role.wireValue == value,
        orElse: () => throw ArgumentError.value(value, 'role'),
      );
}

enum MembershipStatus {
  active('active'),
  suspended('suspended'),
  removed('removed');

  const MembershipStatus(this.wireValue);
  final String wireValue;

  static MembershipStatus fromWireValue(String value) => values.firstWhere(
        (status) => status.wireValue == value,
        orElse: () => throw ArgumentError.value(value, 'status'),
      );
}

enum BranchStatus {
  active('active'),
  inactive('inactive');

  const BranchStatus(this.wireValue);
  final String wireValue;

  static BranchStatus fromWireValue(String value) => values.firstWhere(
        (status) => status.wireValue == value,
        orElse: () => throw ArgumentError.value(value, 'status'),
      );
}

enum CashierStatus {
  active('active'),
  suspended('suspended');

  const CashierStatus(this.wireValue);
  final String wireValue;

  static CashierStatus fromWireValue(String value) => values.firstWhere(
        (status) => status.wireValue == value,
        orElse: () => throw ArgumentError.value(value, 'status'),
      );
}

enum PosDeviceStatus {
  active('active'),
  revoked('revoked');

  const PosDeviceStatus(this.wireValue);
  final String wireValue;

  static PosDeviceStatus fromWireValue(String value) => values.firstWhere(
        (status) => status.wireValue == value,
        orElse: () => throw ArgumentError.value(value, 'status'),
      );
}
