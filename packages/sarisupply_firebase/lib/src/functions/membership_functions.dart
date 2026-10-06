import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

import 'merchant_application_functions.dart';
import 'https_merchant_gateway.dart';

final class MembershipFunctions implements MembershipRepository {
  MembershipFunctions({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required MerchantCallableGateway gateway,
  })  : _auth = auth,
        _firestore = firestore,
        _gateway = gateway;

  factory MembershipFunctions.forDefaultApp() {
    final app = Firebase.app();
    return MembershipFunctions(
      auth: FirebaseAuth.instanceFor(app: app),
      firestore: FirebaseFirestore.instanceFor(app: app),
      gateway: HttpsMerchantGateway.forApp(app),
    );
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final MerchantCallableGateway _gateway;

  String get _uid =>
      _auth.currentUser?.uid ??
      (throw StateError('Sign in before reading memberships'));

  static Map<String, Object?> _dated(Map<String, dynamic> source) {
    final data = Map<String, Object?>.from(source);
    for (final field in ['createdAt', 'updatedAt']) {
      final value = data[field];
      if (value is Timestamp) data[field] = value.toDate();
    }
    return data;
  }

  @override
  Future<List<MerchantMembership>> listMyMemberships() async {
    final uid = _uid;
    final refs = await _firestore
        .collection('users/$uid/merchantRefs')
        .where('status', isEqualTo: 'active')
        .get();
    final memberships = <MerchantMembership>[];
    for (final ref in refs.docs) {
      try {
        final snapshot =
            await _firestore.doc('merchants/${ref.id}/memberships/$uid').get();
        if (snapshot.exists) {
          final merchant = await _firestore.doc('merchants/${ref.id}').get();
          final data = _dated(snapshot.data()!);
          final profile = merchant.data()?['businessProfile'];
          data['merchantName'] = profile is Map && profile['name'] is String
              ? profile['name']
              : 'Store';
          memberships.add(MerchantMembership.fromMap(data));
        }
      } on FirebaseException catch (error) {
        if (error.code != 'permission-denied') rethrow;
      }
    }
    return memberships;
  }

  @override
  Future<List<Branch>> listAccessibleBranches(
      MerchantMembership membership) async {
    if (membership.userId != _uid ||
        membership.status != MembershipStatus.active) {
      throw StateError('An active personal membership is required');
    }
    final branches =
        _firestore.collection('merchants/${membership.merchantId}/branches');
    final docs = <DocumentSnapshot<Map<String, dynamic>>>[];
    if (membership.role == MerchantRole.owner || membership.allBranches) {
      docs.addAll((await branches
              .where('status', isEqualTo: 'active')
              .where('merchantId', isEqualTo: membership.merchantId)
              .get())
          .docs);
    } else {
      for (final branchId in membership.branchIds) {
        try {
          docs.add(await branches.doc(branchId).get());
        } on FirebaseException catch (error) {
          if (error.code != 'permission-denied') rethrow;
        }
      }
    }
    return docs
        .where((doc) => doc.exists)
        .map((doc) {
          final data = _dated(doc.data()!);
          data['id'] = doc.id;
          return Branch.fromMap(data);
        })
        .where((branch) => branch.status == BranchStatus.active)
        .toList();
  }

  @override
  Future<List<ManagerInvitation>> listMyInvitations() async {
    final result = await _gateway.call('listMyInvitations', {});
    final invites = result['invitations'];
    if (invites is! List) throw StateError('Invalid invitations response');
    return invites.map((value) {
      if (value is! Map) throw StateError('Invalid invitation');
      final data = Map<String, Object?>.from(value);
      return ManagerInvitation(
        inviteId: data['inviteId'] as String,
        merchantId: data['merchantId'] as String,
        email: data['email'] as String,
        allBranches: data['allBranches'] as bool,
        branchIds: List<String>.from(data['branchIds'] as List),
        expiresAt: DateTime.parse(data['expiresAt'] as String),
      );
    }).toList();
  }

  @override
  Future<String> createManagerInvitation({
    required String merchantId,
    required String email,
    required bool allBranches,
    required List<String> branchIds,
    required String operationId,
  }) async {
    final result = await _gateway.call('createManagerInvitation', {
      'merchantId': merchantId,
      'email': email,
      'allBranches': allBranches,
      'branchIds': branchIds,
      'operationId': operationId,
    });
    return result['inviteId'] as String;
  }

  @override
  Future<void> acceptManagerInvitation(
      String merchantId, String inviteId) async {
    await _gateway.call('acceptManagerInvitation', {
      'merchantId': merchantId,
      'inviteId': inviteId,
    });
  }

  @override
  Future<void> revokeManagerInvitation(
      String merchantId, String inviteId) async {
    await _gateway.call('revokeManagerInvitation', {
      'merchantId': merchantId,
      'inviteId': inviteId,
    });
  }

  @override
  Future<void> updateManagerAccess({
    required String merchantId,
    required String managerUid,
    required bool allBranches,
    required List<String> branchIds,
  }) async {
    await _gateway.call('updateManagerAccess', {
      'merchantId': merchantId,
      'managerUid': managerUid,
      'allBranches': allBranches,
      'branchIds': branchIds,
    });
  }

  @override
  Future<void> removeManager(String merchantId, String managerUid) async {
    await _gateway.call('removeManager', {
      'merchantId': merchantId,
      'managerUid': managerUid,
    });
  }

  @override
  Future<String> createBranch({
    required String merchantId,
    required String name,
    required String code,
    required String address,
    required String operationId,
    Map<String, Object?> contactDetails = const {},
    Map<String, Object?> operatingHours = const {},
  }) async {
    final result = await _gateway.call('createBranch', {
      'merchantId': merchantId,
      'name': name,
      'code': code,
      'address': address,
      'contactDetails': contactDetails,
      'operatingHours': operatingHours,
      'operationId': operationId,
    });
    return result['branchId'] as String;
  }

  @override
  Future<void> deactivateBranch(String merchantId, String branchId) async {
    await _gateway.call('deactivateBranch', {
      'merchantId': merchantId,
      'branchId': branchId,
    });
  }
}
