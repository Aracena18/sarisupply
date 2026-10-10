import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  test(
      'Company proof replay, pending evidence and same-boot authority survive reopen',
      () async {
    sqfliteFfiInit();
    final dir = await Directory.systemTemp.createTemp('company-work-');
    Future<CompanyWorkStore> open() =>
        CompanyWorkStore.open(databaseFactoryFfi, '${dir.path}/db',
            companyId: 'company', uid: 'rider', role: 'rider');
    var store = await open();
    try {
      const payload = {
        'runId': 'run',
        'stopId': 'stop',
        'expectedRevision': 2,
        'cashCollectedCentavos': 100
      };
      await store.verifyAuthority({'bootCount': 1, 'elapsedRealtimeMs': 100});
      expect(
          await store
              .offlineAllowed({'bootCount': 1, 'elapsedRealtimeMs': 101}),
          true);
      expect(
          await store
              .offlineAllowed({'bootCount': 2, 'elapsedRealtimeMs': 101}),
          false);
      expect(
          await store.offlineAllowed({
            'bootCount': 1,
            'elapsedRealtimeMs': 100 + const Duration(days: 7).inMilliseconds
          }),
          false);
      await store
          .queueProof('operation', payload, {'id': 'run', 'revision': 3});
      await store
          .queueProof('operation', payload, {'id': 'run', 'revision': 3});
      expect((await store.pending()).length, 1);
      await expectLater(
          store.queueProof('operation',
              {...payload, 'cashCollectedCentavos': 200}, {'id': 'run'}),
          throwsStateError);
      await store.block('operation', 'Access removed');
      await store.close();
      store = await open();
      expect((await store.pending()).single['id'], 'operation');
      expect((await store.pending()).single['status'], 'blocked');
      expect((await store.document('run:run'))!['revision'], 3);
      await store.invalidateAuthority();
      expect(
          await store
              .offlineAllowed({'bootCount': 1, 'elapsedRealtimeMs': 101}),
          false);
      expect((await store.pending()).length, 1);
    } finally {
      await store.close();
      await dir.delete(recursive: true);
    }
  });
}
