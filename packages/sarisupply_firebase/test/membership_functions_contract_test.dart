import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

class _Gateway implements MerchantCallableGateway {
  String? name;
  Map<String, Object?>? payload;

  @override
  Future<Map<String, Object?>> call(
      String name, Map<String, Object?> payload) async {
    this.name = name;
    this.payload = payload;
    return {
      'inviteId': 'invite-1',
      'branchId': 'branch-1',
      'invitations': [
        {
          'inviteId': 'invite-1',
          'merchantId': 'merchant-1',
          'email': 'manager@example.com',
          'allBranches': false,
          'branchIds': ['branch-1'],
          'expiresAt': '2026-10-04T00:00:00.000Z',
        }
      ],
    };
  }
}

void main() {
  final gateway = _Gateway();
  final repository = MembershipFunctions(
    auth: _FakeAuth(),
    firestore: _FakeFirestore(),
    gateway: gateway,
  );

  test('lists only backend-filtered invitations', () async {
    final invitations = await repository.listMyInvitations();
    expect(gateway.name, 'listMyInvitations');
    expect(gateway.payload, isEmpty);
    expect(invitations.single.branchIds, ['branch-1']);
  });

  test('passes invitation scope to the protected callable', () async {
    expect(
        await repository.createManagerInvitation(
          merchantId: 'merchant-1',
          email: 'manager@example.com',
          allBranches: false,
          branchIds: ['branch-1'],
          operationId: 'op-1',
        ),
        'invite-1');
    expect(gateway.name, 'createManagerInvitation');
    expect(gateway.payload, {
      'merchantId': 'merchant-1',
      'email': 'manager@example.com',
      'allBranches': false,
      'branchIds': ['branch-1'],
      'operationId': 'op-1',
    });
  });

  test('passes branch creation through callable', () async {
    expect(
        await repository.createBranch(
          merchantId: 'merchant-1',
          name: 'Main',
          code: 'MAIN',
          address: 'Davao City',
          operationId: 'branch-op-1',
        ),
        'branch-1');
    expect(gateway.name, 'createBranch');
    expect(gateway.payload?['operationId'], 'branch-op-1');
  });
}

class _FakeAuth extends Fake implements FirebaseAuth {}

class _FakeFirestore extends Fake implements FirebaseFirestore {}
