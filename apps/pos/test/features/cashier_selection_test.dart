import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_auth/sarisupply_auth.dart';
import 'package:sarisupply_pos/features/cashier_auth/presentation/cashier_login_screen.dart';
import 'package:sarisupply_pos/features/cashier_auth/domain/cashier_login_service.dart';

void main() {
  testWidgets('roster loading is distinct and manual entry is reversible',
      (tester) async {
    final roster = Completer<List<CashierCredentialProjection>>();
    await tester.pumpWidget(MaterialApp(
        home: CashierLoginScreen(
      loadCashiers: () => roster.future,
      onLogin: (_, __) async =>
          const CashierLoginResult(CashierLoginStatus.invalidPin),
      onResult: (_, __) {},
    )));
    await tester.pump();
    expect(find.text('Loading cashier names…'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Cashier ID'), findsNothing);
    await tester.tap(find.text('Use cashier ID'));
    await tester.pump();
    expect(find.widgetWithText(TextField, 'Cashier ID'), findsOneWidget);
    roster.complete([
      CashierCredentialProjection(
        cashierId: 'ana',
        displayName: 'Ana',
        employeeCode: '01',
        status: 'active',
        assignedBranchIds: ['main'],
        mustChangePin: false,
        credentialVersion: 1,
      )
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose cashier name'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
  });
  testWidgets('selects a cashier name and submits the actual ID with PIN',
      (tester) async {
    String? signedIn;
    await tester.pumpWidget(MaterialApp(
        home: CashierLoginScreen(
      loadCashiers: () async => [
        CashierCredentialProjection(
            cashierId: 'id-ana',
            displayName: 'Ana',
            employeeCode: 'EMP1',
            status: 'active',
            assignedBranchIds: ['main'],
            mustChangePin: false,
            credentialVersion: 1)
      ],
      onLogin: (id, pin) async {
        signedIn = id;
        expect(pin, '483920');
        return const CashierLoginResult(CashierLoginStatus.invalidPin);
      },
      onResult: (_, __) {},
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana · EMP1').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '483920');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(signedIn, 'id-ana');
    expect(find.text('Incorrect PIN'), findsOneWidget);
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'PIN'))
            .controller!
            .text,
        isEmpty);
  });
  testWidgets('switching names and IDs retains the manual ID and selected name',
      (tester) async {
    final submitted = <String>[];
    await tester.pumpWidget(MaterialApp(
        home: CashierLoginScreen(
      loadCashiers: () async => [
        CashierCredentialProjection(
            cashierId: 'ana',
            displayName: 'Ana',
            employeeCode: '01',
            status: 'active',
            assignedBranchIds: ['main'],
            mustChangePin: false,
            credentialVersion: 1)
      ],
      onLogin: (id, _) async {
        submitted.add(id);
        return const CashierLoginResult(CashierLoginStatus.invalidPin);
      },
      onResult: (_, __) {},
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana · 01').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use cashier ID'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Cashier ID'), 'ben');
    await tester.tap(find.text('Choose cashier name'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '123456');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use cashier ID'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Cashier ID'))
            .controller!
            .text,
        'ben');
    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '123456');
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(submitted, ['ana', 'ben']);
  });
  testWidgets('roster outage preserves ID entry without leaking errors',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: CashierLoginScreen(
      loadCashiers: () async => throw StateError('private-token'),
      onLogin: (_, __) async =>
          const CashierLoginResult(CashierLoginStatus.invalidPin),
      onResult: (_, __) {},
    )));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Cashier ID'), findsOneWidget);
    expect(find.textContaining('private-token'), findsNothing);
  });
}
