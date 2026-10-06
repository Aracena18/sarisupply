enum RestockProposalStatus {
  draft,
  pendingApproval,
  approved,
  rejected,
  picking,
  picked,
  packing,
  packed,
  dispatched,
  received,
  cancelled;

  String get label {
    switch (this) {
      case RestockProposalStatus.draft:
        return 'Draft';
      case RestockProposalStatus.pendingApproval:
        return 'Pending Approval';
      case RestockProposalStatus.approved:
        return 'Approved';
      case RestockProposalStatus.rejected:
        return 'Rejected';
      case RestockProposalStatus.picking:
        return 'Picking in Warehouse';
      case RestockProposalStatus.picked:
        return 'Picked';
      case RestockProposalStatus.packing:
        return 'Packing';
      case RestockProposalStatus.packed:
        return 'Packed & Sealed';
      case RestockProposalStatus.dispatched:
        return 'Dispatched';
      case RestockProposalStatus.received:
        return 'Received at Branch';
      case RestockProposalStatus.cancelled:
        return 'Cancelled';
    }
  }

  static RestockProposalStatus fromString(String val) {
    for (final s in RestockProposalStatus.values) {
      if (s.name == val) return s;
    }
    return RestockProposalStatus.draft;
  }
}

class RestockProposalLine {
  const RestockProposalLine({
    required this.productId,
    required this.productName,
    required this.sku,
    required this.currentStock,
    required this.suggestedQuantity,
    this.approvedQuantity = 0,
    this.pickedQuantity = 0,
  });

  final String productId;
  final String productName;
  final String sku;
  final int currentStock;
  final int suggestedQuantity;
  final int approvedQuantity;
  final int pickedQuantity;

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'sku': sku,
        'currentStock': currentStock,
        'suggestedQuantity': suggestedQuantity,
        'approvedQuantity': approvedQuantity,
        'pickedQuantity': pickedQuantity,
      };

  factory RestockProposalLine.fromMap(Map<String, dynamic> map) =>
      RestockProposalLine(
        productId: map['productId'] as String,
        productName: map['productName'] as String? ?? '',
        sku: map['sku'] as String? ?? '',
        currentStock: (map['currentStock'] as num?)?.toInt() ?? 0,
        suggestedQuantity: (map['suggestedQuantity'] as num?)?.toInt() ?? 0,
        approvedQuantity: (map['approvedQuantity'] as num?)?.toInt() ?? 0,
        pickedQuantity: (map['pickedQuantity'] as num?)?.toInt() ?? 0,
      );

  RestockProposalLine copyWith({
    String? productId,
    String? productName,
    String? sku,
    int? currentStock,
    int? suggestedQuantity,
    int? approvedQuantity,
    int? pickedQuantity,
  }) =>
      RestockProposalLine(
        productId: productId ?? this.productId,
        productName: productName ?? this.productName,
        sku: sku ?? this.sku,
        currentStock: currentStock ?? this.currentStock,
        suggestedQuantity: suggestedQuantity ?? this.suggestedQuantity,
        approvedQuantity: approvedQuantity ?? this.approvedQuantity,
        pickedQuantity: pickedQuantity ?? this.pickedQuantity,
      );
}

class RestockProposal {
  const RestockProposal({
    required this.id,
    required this.branchId,
    required this.warehouseId,
    required this.status,
    required this.lines,
    required this.requestedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.rejectionReason,
    this.notes = '',
  });

  final String id;
  final String branchId;
  final String warehouseId;
  final RestockProposalStatus status;
  final List<RestockProposalLine> lines;
  final DateTime requestedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? rejectionReason;
  final String notes;

  int get totalSuggestedItems =>
      lines.fold(0, (sum, l) => sum + l.suggestedQuantity);

  int get totalApprovedItems =>
      lines.fold(0, (sum, l) => sum + l.approvedQuantity);

  Map<String, dynamic> toMap() => {
        'id': id,
        'branchId': branchId,
        'warehouseId': warehouseId,
        'status': status.name,
        'lines': lines.map((l) => l.toMap()).toList(),
        'requestedAt': requestedAt.toIso8601String(),
        'reviewedAt': reviewedAt?.toIso8601String(),
        'reviewedBy': reviewedBy,
        'rejectionReason': rejectionReason,
        'notes': notes,
      };

  factory RestockProposal.fromMap(Map<String, dynamic> map) => RestockProposal(
        id: map['id'] as String,
        branchId: map['branchId'] as String,
        warehouseId: map['warehouseId'] as String? ?? 'wh-main',
        status:
            RestockProposalStatus.fromString(map['status'] as String? ?? ''),
        lines: (map['lines'] as List<dynamic>? ?? [])
            .map((e) => RestockProposalLine.fromMap(e as Map<String, dynamic>))
            .toList(),
        requestedAt: DateTime.tryParse(map['requestedAt'] as String? ?? '') ??
            DateTime.now(),
        reviewedAt: map['reviewedAt'] != null
            ? DateTime.tryParse(map['reviewedAt'] as String)
            : null,
        reviewedBy: map['reviewedBy'] as String?,
        rejectionReason: map['rejectionReason'] as String?,
        notes: map['notes'] as String? ?? '',
      );

  RestockProposal copyWith({
    String? id,
    String? branchId,
    String? warehouseId,
    RestockProposalStatus? status,
    List<RestockProposalLine>? lines,
    DateTime? requestedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? rejectionReason,
    String? notes,
  }) =>
      RestockProposal(
        id: id ?? this.id,
        branchId: branchId ?? this.branchId,
        warehouseId: warehouseId ?? this.warehouseId,
        status: status ?? this.status,
        lines: lines ?? this.lines,
        requestedAt: requestedAt ?? this.requestedAt,
        reviewedAt: reviewedAt ?? this.reviewedAt,
        reviewedBy: reviewedBy ?? this.reviewedBy,
        rejectionReason: rejectionReason ?? this.rejectionReason,
        notes: notes ?? this.notes,
      );
}

class PickList {
  const PickList({
    required this.id,
    required this.restockOrderId,
    required this.warehouseId,
    this.pickerId,
    this.completed = false,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String restockOrderId;
  final String warehouseId;
  final String? pickerId;
  final bool completed;
  final DateTime createdAt;
  final DateTime? completedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'restockOrderId': restockOrderId,
        'warehouseId': warehouseId,
        'pickerId': pickerId,
        'completed': completed,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory PickList.fromMap(Map<String, dynamic> map) => PickList(
        id: map['id'] as String,
        restockOrderId: map['restockOrderId'] as String,
        warehouseId: map['warehouseId'] as String? ?? 'wh-main',
        pickerId: map['pickerId'] as String?,
        completed: (map['completed'] as bool?) ?? false,
        createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
            DateTime.now(),
        completedAt: map['completedAt'] != null
            ? DateTime.tryParse(map['completedAt'] as String)
            : null,
      );

  PickList copyWith({
    String? id,
    String? restockOrderId,
    String? warehouseId,
    String? pickerId,
    bool? completed,
    DateTime? createdAt,
    DateTime? completedAt,
  }) =>
      PickList(
        id: id ?? this.id,
        restockOrderId: restockOrderId ?? this.restockOrderId,
        warehouseId: warehouseId ?? this.warehouseId,
        pickerId: pickerId ?? this.pickerId,
        completed: completed ?? this.completed,
        createdAt: createdAt ?? this.createdAt,
        completedAt: completedAt ?? this.completedAt,
      );
}

class PackageManifest {
  const PackageManifest({
    required this.id,
    required this.restockOrderId,
    required this.packageCode,
    required this.totalItems,
    this.sealNotes = '',
    required this.packedAt,
  });

  final String id;
  final String restockOrderId;
  final String packageCode;
  final int totalItems;
  final String sealNotes;
  final DateTime packedAt;

  Map<String, dynamic> toMap() => {
        'id': id,
        'restockOrderId': restockOrderId,
        'packageCode': packageCode,
        'totalItems': totalItems,
        'sealNotes': sealNotes,
        'packedAt': packedAt.toIso8601String(),
      };

  factory PackageManifest.fromMap(Map<String, dynamic> map) => PackageManifest(
        id: map['id'] as String,
        restockOrderId: map['restockOrderId'] as String,
        packageCode: map['packageCode'] as String? ?? '',
        totalItems: (map['totalItems'] as num?)?.toInt() ?? 0,
        sealNotes: map['sealNotes'] as String? ?? '',
        packedAt: DateTime.tryParse(map['packedAt'] as String? ?? '') ??
            DateTime.now(),
      );

  PackageManifest copyWith({
    String? id,
    String? restockOrderId,
    String? packageCode,
    int? totalItems,
    String? sealNotes,
    DateTime? packedAt,
  }) =>
      PackageManifest(
        id: id ?? this.id,
        restockOrderId: restockOrderId ?? this.restockOrderId,
        packageCode: packageCode ?? this.packageCode,
        totalItems: totalItems ?? this.totalItems,
        sealNotes: sealNotes ?? this.sealNotes,
        packedAt: packedAt ?? this.packedAt,
      );
}
