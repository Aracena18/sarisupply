import 'package:sarisupply_firebase/sarisupply_firebase.dart';
import 'package:sarisupply_inventory/sarisupply_inventory.dart';

/// Uses the signed-in human identity; device credentials cannot approve purchasing.
Future<Map<String, Object?>> refreshProcurementWorkspace(
    InventoryStore store, String kind,
    {String? warehouseId}) async {
  final gateway = ProcurementFunctions.forHuman();
  final pending = await store.synchronizeProcurement(gateway.pushQueued);
  final page = await gateway.workspace(store.merchantId, store.branchId, kind,
      warehouseId: warehouseId);
  final records = (page['records'] as List)
      .map((record) => Map<String, dynamic>.from(record as Map))
      .toList();
  await store.applyProcurementWorkspace(kind, records,
      warehouseId: warehouseId);
  return {...page, 'pendingCount': pending};
}
