import 'package:sarisupply_models/sarisupply_models.dart';

abstract interface class MerchantApplicationRepository {
  Stream<List<MerchantApplication>> watchMyApplications();
  Future<MerchantApplication?> getApplication(String applicationId);

  Future<String> saveDraft({
    String? applicationId,
    required Map<String, Object?> businessProfile,
    required Map<String, Object?> firstBranchDraft,
  });

  Future<void> submit(String applicationId);
}

final class MerchantReviewResult {
  const MerchantReviewResult({
    required this.applicationId,
    required this.status,
    this.merchantId,
    this.branchId,
  });

  final String applicationId;
  final String status;
  final String? merchantId;
  final String? branchId;
}
