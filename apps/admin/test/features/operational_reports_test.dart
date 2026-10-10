import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_admin/features/reports/presentation/admin_reports_screen.dart';
import 'package:sarisupply_design_system/sarisupply_design_system.dart';
import 'package:sarisupply_firebase/sarisupply_firebase.dart';

class ReportGateway implements MerchantCallableGateway {
  @override
  Future<Map<String, Object?>> call(
      String name, Map<String, Object?> payload) async {
    if (payload['action'] == 'merchants') {
      return {
        'merchants': [
          {'id': 'real-store', 'name': 'Rosa Store'}
        ]
      };
    }
    return {
      'summaries': [
        {
          'date': payload['date'],
          'branchId': 'real-branch',
          'grossSalesCentavos': 1250,
          'transactionCount': 1,
          'tenders': {'cashCentavos': 1250}
        }
      ]
    };
  }
}

void main() {
  testWidgets(
      'real report data remains readable on a narrow phone at 200% text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: SariSupplyTheme.light,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!),
        home:
            AdminReportsScreen(gateway: OperationsFunctions(ReportGateway()))));
    await tester.pumpAndSettle();
    expect(find.text('Rosa Store'), findsOneWidget);
    expect(find.text('₱12.50'), findsWidgets);
    expect(find.text('Branch 01 - Poblacion'), findsNothing);
  });
}
