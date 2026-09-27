import 'auth_enums.dart';

final class MerchantApplication {
  MerchantApplication({
    required this.id,
    required this.applicantUid,
    required this.status,
    required Map<String, Object?> businessProfile,
    required Map<String, Object?> firstBranchDraft,
    required this.submittedAt,
    required this.reviewedAt,
    required this.reviewedBy,
    required this.reviewNotes,
    required this.approvedMerchantId,
  })  : businessProfile = Map.unmodifiable(businessProfile),
        firstBranchDraft = Map.unmodifiable(firstBranchDraft);

  factory MerchantApplication.fromMap(Map<String, Object?> map) =>
      MerchantApplication(
        id: map['id'] as String,
        applicantUid: map['applicantUid'] as String,
        status:
            MerchantApplicationStatus.fromWireValue(map['status'] as String),
        businessProfile:
            Map<String, Object?>.from(map['businessProfile'] as Map),
        firstBranchDraft:
            Map<String, Object?>.from(map['firstBranchDraft'] as Map),
        submittedAt: map['submittedAt'] as DateTime?,
        reviewedAt: map['reviewedAt'] as DateTime?,
        reviewedBy: map['reviewedBy'] as String?,
        reviewNotes: map['reviewNotes'] as String?,
        approvedMerchantId: map['approvedMerchantId'] as String?,
      );

  final String id;
  final String applicantUid;
  final MerchantApplicationStatus status;
  final Map<String, Object?> businessProfile;
  final Map<String, Object?> firstBranchDraft;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewNotes;
  final String? approvedMerchantId;

  Map<String, Object?> toMap() => {
        'id': id,
        'applicantUid': applicantUid,
        'status': status.wireValue,
        'businessProfile': businessProfile,
        'firstBranchDraft': firstBranchDraft,
        'submittedAt': submittedAt,
        'reviewedAt': reviewedAt,
        'reviewedBy': reviewedBy,
        'reviewNotes': reviewNotes,
        'approvedMerchantId': approvedMerchantId,
      };
}
