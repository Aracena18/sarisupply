import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sarisupply_admin/features/admin_auth/presentation/admin_auth_gate.dart';
import 'package:sarisupply_admin/features/merchant_review/presentation/merchant_review_list_screen.dart';
import 'package:sarisupply_admin/features/merchant_review/presentation/merchant_review_detail_screen.dart';

final application = MerchantApplication(
    id: 'app',
    applicantUid: 'owner',
    status: MerchantApplicationStatus.pendingReview,
    businessProfile: const {'name': 'Aling Nena’s Sari-Sari Store'},
    firstBranchDraft: const {
      'name': 'Main branch',
      'code': 'MAIN',
      'address': 'Barangay Matina, Davao City'
    },
    submittedAt: DateTime.utc(2026, 10, 4),
    reviewedAt: null,
    reviewedBy: null,
    reviewNotes: null,
    approvedMerchantId: null);
const user =
    AuthUser(uid: 'admin', email: 'admin@example.com', emailVerified: true);

class Reviews extends Fake implements AdminReviewRepository {
  Reviews({this.empty = false, this.fail = false});
  final bool empty, fail;
  @override
  Stream<List<MerchantApplication>> watchPending() => fail
      ? Stream.error(StateError('private detail'))
      : Stream.value(empty ? [] : [application]);
}

class Auth extends Fake implements AuthRepository {
  Auth(this.user, {this.fail = false});
  final AuthUser? user;
  final bool fail;
  final signIn = Completer<AuthUser>();
  int calls = 0;
  @override
  Stream<AuthUser?> authStateChanges() =>
      fail ? Stream.error(StateError('private detail')) : Stream.value(user);
  @override
  Future<AuthUser> signInWithGoogle() {
    calls++;
    return signIn.future;
  }
}

class Access extends Fake implements AdminAccessRepository {
  Access(this.allowed, {this.fail = false});
  final bool allowed, fail;
  @override
  Future<bool> isActiveAdmin() async {
    if (fail) throw StateError('private detail');
    return allowed;
  }
}

Widget app(Widget screen, double scale) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: SariSupplyTheme.light(),
    builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!),
    home: screen);
void main() {
  setUpAll(() async {
    final loader = FontLoader('packages/sarisupply_design_system/NunitoSans');
    for (final w in [400, 600, 700]) {
      loader.addFont(rootBundle.load(
          'packages/sarisupply_design_system/assets/fonts/NunitoSans-$w.ttf'));
    }
    await loader.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  for (final width in [320.0, 390.0, 600.0, 1024.0, 1280.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Admin states and detail at $width / $scale', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final screen in <Widget>[
          AdminAuthGate(
              auth: Auth(null), access: Access(true), reviews: Reviews()),
          AdminAuthGate(
              auth: Auth(null, fail: true),
              access: Access(true),
              reviews: Reviews()),
          AdminAuthGate(
              auth: Auth(user), access: Access(false), reviews: Reviews()),
          AdminAuthGate(
              auth: Auth(user),
              access: Access(false, fail: true),
              reviews: Reviews()),
          MerchantReviewListScreen(reviews: Reviews(), onSignOut: () async {}),
          MerchantReviewListScreen(
              reviews: Reviews(empty: true), onSignOut: () async {}),
          MerchantReviewListScreen(
              reviews: Reviews(fail: true), onSignOut: () async {}),
          MerchantReviewDetailScreen(
              application: application, reviews: Reviews()),
        ]) {
          await tester.pumpWidget(app(screen, scale));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull,
              reason: '${screen.runtimeType}');
        }
        await tester.ensureVisible(find.text('Approve'));
        await tester.tap(find.text('Approve'));
        await tester.pumpAndSettle();
        expect(find.text('Approve store'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      });
    }
  }
  testWidgets('sign-in submission is guarded and keyboard can reach it',
      (tester) async {
    final auth = Auth(null);
    await tester.pumpWidget(app(
        AdminAuthGate(auth: auth, access: Access(true), reviews: Reviews()),
        1));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(auth.calls, 1);
    await tester.tap(find.text('Signing in…'));
    await tester.pump();
    expect(auth.calls, 1);
    auth.signIn.complete(user);
    await tester.pumpAndSettle();
  });
  testWidgets('review representative golden', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(app(
        MerchantReviewDetailScreen(
            application: application, reviews: Reviews()),
        1));
    await tester.pumpAndSettle();
    await expectLater(find.byType(MaterialApp),
        matchesGoldenFile('../goldens/admin_review.png'));
  });
}
