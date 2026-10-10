import 'package:flutter/material.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

import '../features/admin_auth/presentation/admin_auth_gate.dart';

class AdminAppGate extends StatelessWidget {
  const AdminAppGate({
    super.key,
    this.auth,
    this.access,
    this.reviews,
    this.procurement,
    this.authorization,
  });

  final AuthRepository? auth;
  final AdminAccessRepository? access;
  final AdminReviewRepository? reviews;
  final ProcurementGateway? procurement;
  final AuthorizationWorkspaceFunctions? authorization;

  @override
  Widget build(BuildContext context) {
    try {
      return AdminAuthGate(
        auth: auth ?? FirebaseGoogleAuthRepository.forDefaultApp(),
        access: access ?? FirebaseAdminAccessRepository.forDefaultApp(),
        reviews: reviews ?? MerchantApplicationFunctions.forDefaultApp(),
        procurement: procurement,
        authorization:
            authorization ?? AuthorizationWorkspaceFunctions.forDefaultApp(),
      );
    } catch (_) {
      return const Scaffold(
          body: SariSupplyEntry(
              role: 'Admin',
              child: SariSupplyStatus(
                  message:
                      'Admin setup is incomplete. Contact your administrator.',
                  error: true)));
    }
  }
}
