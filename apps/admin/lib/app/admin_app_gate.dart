import 'package:flutter/material.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

import '../features/admin_auth/presentation/admin_auth_gate.dart';

class AdminAppGate extends StatelessWidget {
  const AdminAppGate({super.key, this.auth, this.access, this.reviews});

  final AuthRepository? auth;
  final AdminAccessRepository? access;
  final AdminReviewRepository? reviews;

  @override
  Widget build(BuildContext context) => AdminAuthGate(
        auth: auth ?? FirebaseGoogleAuthRepository.forDefaultApp(),
        access: access ?? FirebaseAdminAccessRepository.forDefaultApp(),
        reviews: reviews ?? MerchantApplicationFunctions.forDefaultApp(),
      );
}
