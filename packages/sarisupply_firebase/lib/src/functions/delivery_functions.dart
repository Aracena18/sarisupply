import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'https_merchant_gateway.dart';
import 'merchant_application_functions.dart';

abstract interface class DeliveryGateway {
  Future<void> createRun(String merchantId, DeliveryRun run);
  Future<void> dispatchRun(String merchantId, String runId);
  Future<void> submitStopProof({
    required String merchantId,
    required String runId,
    required String stopId,
    required DeliveryProof proof,
    required List<DeliveryStopItem> items,
  });
  Future<List<DeliveryRun>> listRuns(
    String merchantId, {
    String? driverId,
    DeliveryRunStatus? status,
  });
}

final class DeliveryFunctions implements DeliveryGateway {
  DeliveryFunctions({required MerchantCallableGateway gateway})
      : _gateway = gateway;

  factory DeliveryFunctions.forHuman() =>
      DeliveryFunctions(gateway: HttpsMerchantGateway.forApp(Firebase.app()));

  final MerchantCallableGateway _gateway;
  Future<List<Map<String, Object?>>> workspaces() async {
    final result = await _gateway.call('getDriverWorkspaces', {});
    return (result['workspaces'] as List)
        .map((r) => Map<String, Object?>.from(r as Map))
        .toList();
  }

  Future<void> updateStatus(Map<String, Object?> operation) async {
    final r = await _gateway
        .call('manageDeliveries', {'action': 'updateStopStatus', ...operation});
    if (r['operationId'] != operation['operationId'] ||
        !['accepted', 'duplicate'].contains(r['status'])) {
      throw const FormatException('Invalid delivery acknowledgement');
    }
  }

  Future<Map<String, Object?>> dispatchWorkspace(
      String merchantId, String warehouseId) async {
    final page = await _gateway.call('manageDeliveries', {
      'action': 'readDispatchWorkspace',
      'merchantId': merchantId,
      'warehouseId': warehouseId,
    });
    if (page['hasMore'] is! bool ||
        [
          'drivers',
          'manifests',
          'runs',
          'returns'
        ].any((key) => page[key] is! List || (page[key] as List).length > 50)) {
      throw const FormatException('Invalid dispatch workspace');
    }
    return page;
  }

  Future<void> receiveReturns(String merchantId, String returnId,
      String operationId, String disposition) async {
    final result = await _gateway.call('manageDeliveries', {
      'action': 'receiveReturns',
      'merchantId': merchantId,
      'returnId': returnId,
      'operationId': operationId,
      'disposition': disposition,
    });
    if (result['returnId'] != returnId ||
        result['operationId'] != operationId ||
        !['received', 'duplicate'].contains(result['status'])) {
      throw const FormatException('Invalid warehouse return acknowledgement');
    }
  }

  Future<void> assignDriver(
      String merchantId, String driverId, String name, String warehouseId,
      {bool active = true}) async {
    final result = await _gateway.call('manageDeliveries', {
      'action': 'assignDriver',
      'merchantId': merchantId,
      'driverId': driverId,
      'driverName': name,
      'warehouseId': warehouseId,
      'active': active
    });
    if (result['status'] != (active ? 'active' : 'removed')) {
      throw const FormatException('Invalid driver assignment acknowledgement');
    }
  }

  @override
  Future<void> createRun(String merchantId, DeliveryRun run) async {
    final result = await _gateway.call('manageDeliveries', {
      'merchantId': merchantId,
      'action': 'createRun',
      'run': run.toMap(),
    });
    if (result['runId'] != run.id ||
        !['created', 'duplicate'].contains(result['status'])) {
      throw const FormatException('Invalid route creation acknowledgement');
    }
  }

  @override
  Future<void> dispatchRun(String merchantId, String runId) async {
    final result = await _gateway.call('manageDeliveries', {
      'merchantId': merchantId,
      'action': 'dispatchRun',
      'runId': runId,
    });
    if (result['runId'] != runId || result['status'] != 'dispatched') {
      throw const FormatException('Invalid dispatch acknowledgement');
    }
  }

  @override
  Future<void> submitStopProof({
    required String merchantId,
    required String runId,
    required String stopId,
    required DeliveryProof proof,
    required List<DeliveryStopItem> items,
  }) async {
    final r = await _gateway.call('manageDeliveries', {
      'merchantId': merchantId,
      'action': 'submitStopProof',
      'runId': runId,
      'stopId': stopId,
      'proof': proof.toMap(),
      'items': items.map((i) => i.toMap()).toList(),
    });
    if (r['runId'] != runId ||
        r['stopId'] != stopId ||
        !['proofRecorded', 'duplicate'].contains(r['status'])) {
      throw const FormatException('Invalid proof acknowledgement');
    }
  }

  @override
  Future<List<DeliveryRun>> listRuns(
    String merchantId, {
    String? driverId,
    DeliveryRunStatus? status,
  }) async {
    final res = await _gateway.call('manageDeliveries', {
      'merchantId': merchantId,
      'action': 'listRuns',
      if (driverId != null) 'driverId': driverId,
      if (status != null) 'status': status.name,
    });
    final list = (res['runs'] as List<dynamic>? ?? []);
    return list
        .map((r) => DeliveryRun.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }
}
