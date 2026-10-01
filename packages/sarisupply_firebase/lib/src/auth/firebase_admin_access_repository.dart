import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';

final class FirebaseAdminAccessRepository implements AdminAccessRepository {
  FirebaseAdminAccessRepository({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
  })  : _auth = auth,
        _firestore = firestore;

  factory FirebaseAdminAccessRepository.forDefaultApp() {
    final app = Firebase.app();
    return FirebaseAdminAccessRepository(
      auth: FirebaseAuth.instanceFor(app: app),
      firestore: FirebaseFirestore.instanceFor(app: app),
    );
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  @override
  Future<bool> isActiveAdmin() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    final token = await user.getIdTokenResult(true);
    if (token.claims?['sarisupplyAdmin'] != true) return false;
    try {
      final record = await _firestore.doc('platformAdmins/${user.uid}').get();
      return record.data()?['status'] == 'active';
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') return false;
      rethrow;
    }
  }
}
