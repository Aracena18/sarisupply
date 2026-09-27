import 'package:sarisupply_models/sarisupply_models.dart';

import 'merchant_application_repository.dart';

abstract interface class AdminAccessRepository {
  Future<bool> isActiveAdmin();
}

abstract interface class AdminReviewRepository {
  Stream<List<MerchantApplication>> watchPending();
  Future<MerchantReviewResult> review({
    required String applicationId,
    required String decision,
    required String operationId,
    String? reviewNotes,
  });
}
