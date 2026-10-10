import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'https_merchant_gateway.dart';

abstract interface class MerchantCallableGateway {
  Future<Map<String, Object?>> call(
    String name,
    Map<String, Object?> payload,
  );
}

final class FirebaseMerchantCallableGateway implements MerchantCallableGateway {
  FirebaseMerchantCallableGateway(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<Map<String, Object?>> call(
    String name,
    Map<String, Object?> payload,
  ) async {
    final response = await _functions.httpsCallable(name).call(payload);
    if (response.data is! Map) {
      throw StateError('$name returned an invalid response');
    }
    return Map<String, Object?>.from(response.data as Map);
  }
}

final class MerchantApplicationFunctions
    implements MerchantApplicationRepository, AdminReviewRepository {
  MerchantApplicationFunctions({
    required FirebaseAuth auth,
    required FirebaseFirestore firestore,
    required MerchantCallableGateway gateway,
  })  : _auth = auth,
        _firestore = firestore,
        _gateway = gateway;

  factory MerchantApplicationFunctions.forDefaultApp() {
    final app = Firebase.app();
    return MerchantApplicationFunctions(
      auth: FirebaseAuth.instanceFor(app: app),
      firestore: FirebaseFirestore.instanceFor(app: app),
      gateway: HttpsMerchantGateway.forApp(app),
    );
  }

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final MerchantCallableGateway _gateway;

  @override
  Stream<List<MerchantApplication>> watchMyApplications() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.error(StateError('Sign in before reading applications'));
    }
    return _firestore
        .collection('merchantApplications')
        .where('applicantUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_applicationFromDoc).toList());
  }

  @override
  Future<MerchantApplication?> getApplication(String applicationId) async {
    final snapshot = await _firestore
        .doc('merchantApplications/$applicationId')
        .get(const GetOptions(source: Source.server));
    if (!snapshot.exists) return null;
    final data = Map<String, Object?>.from(snapshot.data()!);
    data['id'] = snapshot.id;
    for (final field in ['submittedAt', 'reviewedAt']) {
      final value = data[field];
      if (value is Timestamp) {
        data[field] = value.toDate();
      }
    }
    return MerchantApplication.fromMap(data);
  }

  @override
  Stream<List<MerchantApplication>> watchPending() => _firestore
      .collection('merchantApplications')
      .where('status', isEqualTo: 'pending_review')
      .snapshots()
      .map((snapshot) => snapshot.docs.map(_applicationFromDoc).toList());

  static MerchantApplication _applicationFromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    return _applicationFromMap({...snapshot.data(), 'id': snapshot.id});
  }

  @override
  Future<String> saveDraft({
    String? applicationId,
    required Map<String, Object?> businessProfile,
    required Map<String, Object?> firstBranchDraft,
  }) async {
    final result = await _gateway.call('saveMerchantApplicationDraft', {
      if (applicationId != null) 'applicationId': applicationId,
      'businessProfile': businessProfile,
      'firstBranchDraft': firstBranchDraft,
    });
    final id = result['applicationId'];
    if (id is! String || id.isEmpty) {
      throw StateError('Save draft returned no application ID');
    }
    return id;
  }

  @override
  Future<void> submit(String applicationId) async {
    await _gateway.call('submitMerchantApplication', {
      'applicationId': applicationId,
    });
  }

  @override
  Future<MerchantReviewResult> review({
    required String applicationId,
    required String decision,
    required String operationId,
    String? reviewNotes,
  }) async {
    final result = await _gateway.call('reviewMerchantApplication', {
      'applicationId': applicationId,
      'decision': decision,
      'operationId': operationId,
      if (reviewNotes != null) 'reviewNotes': reviewNotes,
    });
    final resultId = result['applicationId'];
    final status = result['status'];
    if (resultId is! String || status is! String) {
      throw StateError('Review returned an invalid response');
    }
    return MerchantReviewResult(
      applicationId: resultId,
      status: status,
      merchantId: result['merchantId'] as String?,
      branchId: result['branchId'] as String?,
    );
  }
}

final class CompanyMerchantApplicationFunctions
    implements AdminReviewRepository {
  CompanyMerchantApplicationFunctions({
    required this.companyId,
    required MerchantCallableGateway gateway,
  }) : _gateway = gateway;

  factory CompanyMerchantApplicationFunctions.forCompany(String companyId) {
    final app = Firebase.app();
    return CompanyMerchantApplicationFunctions(
      companyId: companyId,
      gateway: HttpsMerchantGateway.forApp(app),
    );
  }

  final String companyId;
  final MerchantCallableGateway _gateway;

  @override
  Stream<List<MerchantApplication>> watchPending() =>
      Stream.fromFuture(_loadPending());

  Future<List<MerchantApplication>> _loadPending() async {
    final result = await _gateway.call('listPendingMerchantApplications', {
      'companyId': companyId,
    });
    final rawApplications = result['applications'];
    if (rawApplications is! List) {
      throw StateError('Application list returned an invalid response');
    }
    return rawApplications.map((item) {
      if (item is! Map) {
        throw StateError('Application list contains an invalid record');
      }
      return _applicationFromMap(item);
    }).toList(growable: false);
  }

  @override
  Future<MerchantReviewResult> review({
    required String applicationId,
    required String decision,
    required String operationId,
    String? reviewNotes,
  }) async {
    final result = await _gateway.call('reviewMerchantApplication', {
      'applicationId': applicationId,
      'companyId': companyId,
      'decision': decision,
      'operationId': operationId,
      if (reviewNotes != null) 'reviewNotes': reviewNotes,
    });
    final resultId = result['applicationId'];
    final status = result['status'];
    if (resultId is! String || status is! String) {
      throw StateError('Review returned an invalid response');
    }
    return MerchantReviewResult(
      applicationId: resultId,
      status: status,
      merchantId: result['merchantId'] as String?,
      branchId: result['branchId'] as String?,
    );
  }
}

MerchantApplication _applicationFromMap(Map<Object?, Object?> source) {
  final data = Map<String, Object?>.from(source);
  for (final field in ['submittedAt', 'reviewedAt']) {
    final value = data[field];
    if (value is Timestamp) {
      data[field] = value.toDate();
    } else if (value is String) {
      data[field] = DateTime.tryParse(value);
    }
  }
  return MerchantApplication.fromMap(data);
}
