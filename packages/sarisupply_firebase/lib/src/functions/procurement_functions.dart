import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import 'https_merchant_gateway.dart';
import 'merchant_application_functions.dart';

abstract interface class ProcurementGateway {
  Future<void> saveSupplier(String merchantId, Supplier supplier);
  Future<List<Supplier>> listSuppliers(String merchantId);
  Future<void> createPurchaseOrder(String merchantId, PurchaseOrder po);
  Future<void> recordSupplierReceiving(
      String merchantId, String poId, String productId, int quantityReceived,
      {required String operationId});
  Future<void> submitRestockProposal(
      String merchantId, RestockProposal proposal);
  Future<void> reviewRestockProposal(
      String merchantId, String proposalId, bool approved,
      {List<RestockProposalLine>? adjustedLines, String? rejectionReason});
  Future<void> fulfillRestockPickPack(
      String merchantId, String proposalId, String stage,
      {List<RestockProposalLine>? pickedLines,
      String? packageCode,
      String? sealNotes});
}

final class ProcurementFunctions implements ProcurementGateway {
  ProcurementFunctions({required MerchantCallableGateway gateway})
      : _gateway = gateway;

  factory ProcurementFunctions.forHuman() => ProcurementFunctions(
      gateway: HttpsMerchantGateway.forApp(Firebase.app()));

  final MerchantCallableGateway _gateway;

  Future<Map<String, Object?>> workspace(
          String merchantId, String branchId, String kind,
          {String? warehouseId}) =>
      _gateway.call('readProcurementWorkspace', {
        'merchantId': merchantId,
        'branchId': branchId,
        'kind': kind,
        if (warehouseId != null) 'warehouseId': warehouseId
      });

  Future<Map<String, Object?>> pushQueued(
      String command, Map<String, Object?> payload) async {
    final queueId = payload['queueId'];
    if (queueId is! String ||
        !['managePurchaseOrders', 'manageRestockProposals', 'manageWarehouses']
            .contains(command)) {
      throw const FormatException('Invalid purchasing command');
    }
    final body = {...payload}..remove('queueId');
    try {
      final result = await _gateway.call(command, body);
      final expected = command == 'manageWarehouses'
          ? body['warehouseId']
          : command == 'managePurchaseOrders'
              ? body['poId']
              : body['proposalId'] ?? (body['proposal'] as Map?)?['id'];
      final actual = command == 'manageWarehouses'
          ? result['warehouseId']
          : command == 'managePurchaseOrders'
              ? result['poId']
              : result['proposalId'];
      if (expected == null ||
          actual != expected ||
          ![
            'submitted',
            'approved',
            'rejected',
            'picked',
            'picking',
            'packed',
            'completed',
            'partiallyReceived',
            'duplicate',
            'adjusted'
          ].contains(result['status'])) {
        throw const FormatException('Invalid purchasing acknowledgement');
      }
      return {'operationId': queueId, 'status': 'accepted'};
    } on FirebaseFunctionsException catch (error) {
      if ([
        'permission-denied',
        'unauthenticated',
        'failed-precondition',
        'invalid-argument',
        'already-exists',
        'not-found'
      ].contains(error.code)) {
        return {
          'operationId': queueId,
          'status': 'blocked',
          'message':
              'Purchasing operation needs Owner review. Local work is retained.'
        };
      }
      rethrow;
    }
  }

  Future<void> saveWarehouse(String merchantId, Warehouse warehouse) async {
    final result = await _gateway.call('manageWarehouses', {
      'merchantId': merchantId,
      'warehouseId': warehouse.id,
      'action': 'save',
      'warehouse': warehouse.toMap()
    });
    if (result['warehouseId'] != warehouse.id || result['status'] != 'saved') {
      throw const FormatException('Invalid warehouse acknowledgement');
    }
  }

  @override
  Future<void> saveSupplier(String merchantId, Supplier supplier) async {
    await _gateway.call('manageSuppliers', {
      'merchantId': merchantId,
      'action': 'save',
      'supplier': supplier.toMap(),
    });
  }

  @override
  Future<List<Supplier>> listSuppliers(String merchantId) async {
    final res = await _gateway.call('manageSuppliers', {
      'merchantId': merchantId,
      'action': 'list',
    });
    final list = (res['suppliers'] as List<dynamic>? ?? []);
    return list
        .map((s) => Supplier.fromMap(Map<String, dynamic>.from(s as Map)))
        .toList();
  }

  @override
  Future<void> createPurchaseOrder(String merchantId, PurchaseOrder po) async {
    await _gateway.call('managePurchaseOrders', {
      'merchantId': merchantId,
      'action': 'create',
      'po': po.toMap(),
    });
  }

  @override
  Future<void> recordSupplierReceiving(
      String merchantId, String poId, String productId, int quantityReceived,
      {required String operationId}) async {
    await _gateway.call('managePurchaseOrders', {
      'merchantId': merchantId,
      'action': 'receive',
      'poId': poId,
      'productId': productId,
      'quantityReceived': quantityReceived,
      'operationId': operationId,
    });
  }

  @override
  Future<void> submitRestockProposal(
      String merchantId, RestockProposal proposal) async {
    await _gateway.call('manageRestockProposals', {
      'merchantId': merchantId,
      'action': 'submit',
      'proposal': proposal.toMap(),
    });
  }

  @override
  Future<void> reviewRestockProposal(
      String merchantId, String proposalId, bool approved,
      {List<RestockProposalLine>? adjustedLines,
      String? rejectionReason}) async {
    await _gateway.call('manageRestockProposals', {
      'merchantId': merchantId,
      'action': 'review',
      'proposalId': proposalId,
      'approved': approved,
      'adjustedLines': adjustedLines?.map((l) => l.toMap()).toList(),
      'rejectionReason': rejectionReason,
    });
  }

  @override
  Future<void> fulfillRestockPickPack(
      String merchantId, String proposalId, String stage,
      {List<RestockProposalLine>? pickedLines,
      String? packageCode,
      String? sealNotes}) async {
    await _gateway.call('manageRestockProposals', {
      'merchantId': merchantId,
      'action': 'fulfill',
      'proposalId': proposalId,
      'stage': stage,
      'pickedLines': pickedLines?.map((l) => l.toMap()).toList(),
      'packageCode': packageCode,
      'sealNotes': sealNotes,
    });
  }
}
