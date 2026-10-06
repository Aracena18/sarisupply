import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_models/sarisupply_models.dart';

import 'package:sarisupply_admin/features/admin_auth/presentation/admin_auth_gate.dart';

class _Auth implements AuthRepository {
  _Auth(this.user);
  final AuthUser? user;
  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(user);
  @override
  Future<AuthUser> signInWithGoogle() async => user!;
  @override
  Future<void> signOut() async {}
}

class _Access implements AdminAccessRepository {
  _Access(this.allowed);
  final bool allowed;
  @override
  Future<bool> isActiveAdmin() async => allowed;
}

class _Reviews implements AdminReviewRepository {
  bool failOnce = false;
  final operationIds = <String>[];
  int count = 0;
  String? lastDecision;
  String? lastNotes;
  @override
  Stream<List<MerchantApplication>> watchPending() => Stream.value([
        MerchantApplication(
          id: 'application-1',
          applicantUid: 'owner-1',
          status: MerchantApplicationStatus.pendingReview,
          businessProfile: const {'name': 'Sari Store'},
          firstBranchDraft: const {
            'name': 'Main',
            'code': 'MAIN',
            'address': 'Davao'
          },
          submittedAt: DateTime.utc(2026, 9, 27),
          reviewedAt: null,
          reviewedBy: null,
          reviewNotes: null,
          approvedMerchantId: null,
        ),
      ]);
  @override
  Future<MerchantReviewResult> review({
    required String applicationId,
    required String decision,
    required String operationId,
    String? reviewNotes,
  }) async {
    count++;
    operationIds.add(operationId);
    if (failOnce) {
      failOnce = false;
      throw StateError('private-token');
    }
    lastDecision = decision;
    lastNotes = reviewNotes;
    return MerchantReviewResult(applicationId: applicationId, status: decision);
  }
}

const _user =
    AuthUser(uid: 'admin-1', email: 'admin@example.com', emailVerified: true);

void main() {
  testWidgets('review retry keeps operation ID and search filters the queue',
      (tester) async {
    final reviews = _Reviews()..failOnce = true;
    await tester.pumpWidget(MaterialApp(
        home: AdminAuthGate(
            auth: _Auth(_user), access: _Access(true), reviews: reviews)));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Search applications'), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('Sari Store'), findsNothing);
    await tester.enterText(
        find.widgetWithText(TextField, 'Search applications'), 'davao');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sari Store'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve store'));
    await tester.pumpAndSettle();
    expect(find.textContaining('private-token'), findsNothing);
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve store'));
    await tester.pumpAndSettle();
    expect(reviews.operationIds.length, 2);
    expect(reviews.operationIds[0], reviews.operationIds[1]);
  });
  testWidgets('a signed in non-admin sees access denied', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: AdminAuthGate(
      auth: _Auth(_user),
      access: _Access(false),
      reviews: _Reviews(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Access denied'), findsOneWidget);
    expect(find.text('Pending applications'), findsNothing);
  });

  testWidgets('an active admin approves exactly once', (tester) async {
    final reviews = _Reviews();
    await tester.pumpWidget(MaterialApp(
        home: AdminAuthGate(
      auth: _Auth(_user),
      access: _Access(true),
      reviews: reviews,
    )));
    await tester.pumpAndSettle();
    expect(find.text('Pending applications'), findsOneWidget);
    await tester.tap(find.text('Sari Store'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Approve store'));
    await tester.pumpAndSettle();
    expect(reviews.count, 1);
    expect(reviews.lastDecision, 'approve');
  });

  testWidgets('rejection requires review notes', (tester) async {
    final reviews = _Reviews();
    await tester.pumpWidget(MaterialApp(
        home: AdminAuthGate(
      auth: _Auth(_user),
      access: _Access(true),
      reviews: reviews,
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sari Store'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(reviews.count, 0);
    await tester.enterText(find.byType(TextField), 'Please confirm address');
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    expect(reviews.count, 0);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Please confirm address');
    await tester.tap(find.text('Reject'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reject application'));
    await tester.pumpAndSettle();
    expect(reviews.count, 1);
    expect(reviews.lastNotes, 'Please confirm address');
  });
}
