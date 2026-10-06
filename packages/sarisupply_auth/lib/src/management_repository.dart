enum ManagementKind { branches, cashiers, devices, managers, invitations }

final class ManagementRecord {
  ManagementRecord(
      {required this.id,
      required this.name,
      required this.code,
      required this.status,
      required List<String> branchIds,
      required this.allBranches})
      : branchIds = List.unmodifiable(branchIds);
  final String id;
  final String name;
  final String code;
  final String status;
  final List<String> branchIds;
  final bool allBranches;
}

final class ManagementPage {
  ManagementPage({required List<ManagementRecord> records, this.nextCursor})
      : records = List.unmodifiable(records);
  final List<ManagementRecord> records;
  final String? nextCursor;
}

abstract interface class ManagementRepository {
  Future<ManagementPage> list(String merchantId, ManagementKind kind,
      {String? cursor});
}
