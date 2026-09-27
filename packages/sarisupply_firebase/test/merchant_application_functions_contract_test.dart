import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

class _Gateway implements MerchantCallableGateway {
  String? name;
  Map<String, Object?>? payload;

  @override
  Future<Map<String, Object?>> call(
    String name,
    Map<String, Object?> payload,
  ) async {
    this.name = name;
    this.payload = payload;
    return {
      'applicationId': 'application-1',
      'status': 'approved',
      'merchantId': 'merchant-1',
      'branchId': 'branch-1',
    };
  }
}

void main() {
  final gateway = _Gateway();
  final repository = MerchantApplicationFunctions(
    auth: FakeFirebaseAuth(),
    firestore: FakeFirestore(),
    gateway: gateway,
  );

  test('sends draft ownership data to the protected callable', () async {
    final applicationId = await repository.saveDraft(
      businessProfile: const {'name': 'Sample Store'},
      firstBranchDraft: const {'name': 'Main'},
    );
    expect(applicationId, 'application-1');
    expect(gateway.name, 'saveMerchantApplicationDraft');
    expect(gateway.payload, {
      'businessProfile': {'name': 'Sample Store'},
      'firstBranchDraft': {'name': 'Main'},
    });
  });

  test('submits a previously created application by ID', () async {
    await repository.submit('application-1');
    expect(gateway.name, 'submitMerchantApplication');
    expect(gateway.payload, {'applicationId': 'application-1'});
  });

  test('sends a stable review operation ID to the Admin callable', () async {
    final result = await repository.review(
      applicationId: 'application-1',
      decision: 'approve',
      operationId: 'review-1',
    );
    expect(gateway.name, 'reviewMerchantApplication');
    expect(gateway.payload, {
      'applicationId': 'application-1',
      'decision': 'approve',
      'operationId': 'review-1',
    });
    expect(result.merchantId, 'merchant-1');
  });
}

class FakeFirebaseAuth extends Fake implements FirebaseAuth {}

class FakeFirestore extends Fake implements FirebaseFirestore {}
