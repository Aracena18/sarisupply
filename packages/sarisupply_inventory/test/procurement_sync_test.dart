import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

RestockProposal proposal(String id) => RestockProposal(
        id: id,
        branchId: 'b',
        warehouseId: 'wh',
        requestedAt: DateTime.utc(2026, 10, 5),
        status: RestockProposalStatus.pendingApproval,
        lines: const [
          RestockProposalLine(
              productId: 'p',
              productName: 'Rice',
              sku: 'RICE',
              currentStock: 0,
              suggestedQuantity: 5)
        ]);
void main() {
  sqfliteFfiInit();
  late Directory directory;
  late InventoryStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('purchasing-sync-');
    store = await InventoryStore.open(
        databaseFactoryFfi, '${directory.path}/db',
        merchantId: 'm', branchId: 'b');
  });
  tearDown(() async {
    await store.close();
    await directory.delete(recursive: true);
  });
  test(
      'queue failure rolls back proposal; partial ACK and reopen retain stable remaining command',
      () async {
    await store.db.execute(
        "CREATE TRIGGER fail_queue BEFORE INSERT ON procurement_outbox BEGIN SELECT RAISE(ABORT,'queue failure'); END");
    await expectLater(
        store.submitRestockProposal(proposal('first')), throwsA(anything));
    expect(await store.listRestockProposals(), isEmpty);
    await store.db.execute('DROP TRIGGER fail_queue');
    await store.submitRestockProposal(proposal('first'));
    await store.submitRestockProposal(proposal('second'));
    final original = await store.pendingProcurement();
    var count = 0;
    await expectLater(store.synchronizeProcurement((command, payload) async {
      if (++count == 2) throw StateError('network lost');
      return {'operationId': payload['queueId'], 'status': 'accepted'};
    }), throwsStateError);
    await store.close();
    store = await InventoryStore.open(
        databaseFactoryFfi, '${directory.path}/db',
        merchantId: 'm', branchId: 'b');
    expect((await store.pendingProcurement()).single['id'], original[1]['id']);
    await expectLater(
        store.synchronizeProcurement((command, payload) async =>
            {'operationId': 'wrong', 'status': 'accepted'}),
        throwsFormatException);
    expect(await store.pendingProcurement(), hasLength(1));
    expect(
        await store.synchronizeProcurement((command, payload) async =>
            {'operationId': payload['queueId'], 'status': 'accepted'}),
        0);
  });
  test(
      'recovery copy preserves occupied workspace and durable queue across reopen',
      () async {
    await store.submitRestockProposal(proposal('original'));
    final archive =
        await store.exportBackupArchive(password: 'archive-password');
    await expectLater(
        store.restoreRecoveryWorkspace(
            archive: archive, password: 'wrong-password'),
        throwsA(anything));
    final recovery = await store.restoreRecoveryWorkspace(
        archive: archive, password: 'archive-password');
    final path = recovery.store.db.path;
    expect(path, isNot(store.db.path));
    expect((await store.listRestockProposals()).single.id, 'original');
    expect((await recovery.store.pendingProcurement()).single['id'],
        (await store.pendingProcurement()).single['id']);
    await recovery.store.close();
    final reopened = await InventoryStore.open(databaseFactoryFfi, path,
        merchantId: 'm', branchId: 'b');
    expect((await reopened.listRestockProposals()).single.id, 'original');
    expect(await reopened.pendingProcurement(), hasLength(1));
    await reopened.close();
    expect(await store.pendingProcurement(), hasLength(1));
  });
  test(
      'full archive restores pending purchasing and refuses an occupied workspace',
      () async {
    await store.submitRestockProposal(proposal('pending'));
    final archive =
        await store.exportBackupArchive(password: 'archive-password');
    final recovered = await InventoryStore.open(
        databaseFactoryFfi, '${directory.path}/recovered',
        merchantId: 'm', branchId: 'b');
    addTearDown(recovered.close);
    await recovered.restoreBackup(
        archive: archive, password: 'archive-password');
    expect((await recovered.pendingProcurement()).single['id'],
        (await store.pendingProcurement()).single['id']);
    await expectLater(
        recovered.restoreBackup(archive: archive, password: 'archive-password'),
        throwsStateError);
    expect((await recovered.listRestockProposals()).single.id, 'pending');
  });
}
