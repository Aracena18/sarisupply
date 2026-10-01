import 'package:sarisupply_models/sarisupply_models.dart';

final class MerchantContext {
  const MerchantContext({
    required this.membership,
    required this.branchId,
  });

  final MerchantMembership membership;
  final String branchId;
}
