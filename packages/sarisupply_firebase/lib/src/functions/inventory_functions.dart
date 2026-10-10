import 'package:firebase_core/firebase_core.dart';
import 'package:sarisupply_models/sarisupply_models.dart';
import '../bootstrap/firebase_bootstrap.dart';
import 'https_merchant_gateway.dart';
import 'merchant_application_functions.dart';
import 'product_image_functions.dart';

final class InventoryFunctions
    implements InventoryGateway, ProductImageGateway {
  InventoryFunctions({required MerchantCallableGateway gateway})
      : _gateway = gateway;
  factory InventoryFunctions.forHuman() =>
      InventoryFunctions(gateway: HttpsMerchantGateway.forApp(Firebase.app()));
  factory InventoryFunctions.forDevice() => InventoryFunctions(
      gateway: HttpsMerchantGateway.forApp(
          Firebase.app(FirebaseBootstrap.deviceAppName)));
  final MerchantCallableGateway _gateway;
  Map<String, Object?> _map(Object? raw) =>
      Map<String, Object?>.from(raw as Map);
  Future<Map<String, Object?>> _pull(
      String merchant, String branch, String feed, int cursor) async {
    final result = await _gateway.call('pullInventory', {
      'merchantId': merchant,
      'branchId': branch,
      'feed': feed,
      'cursor': cursor
    });
    if (result['cursor'] is! int ||
        result['hasMore'] is! bool ||
        result['changes'] is! List ||
        (result['changes'] as List).length > 50) {
      throw const FormatException('Invalid inventory page');
    }
    return result;
  }

  @override
  Future<DeltaPage<CatalogChange>> pullCatalog(
      String merchantId, String branchId, int cursor) async {
    final r = await _pull(merchantId, branchId, 'catalog', cursor);
    return DeltaPage(
        cursor: r['cursor'] as int,
        hasMore: r['hasMore'] as bool,
        changes: (r['changes'] as List).map((raw) {
          final c = _map(raw);
          return CatalogChange(
              c['sequence'] as int, CatalogProduct.fromMap(_map(c['product'])));
        }).toList());
  }

  @override
  Future<DeltaPage<StockEvent>> pullStock(
      String merchantId, String branchId, int cursor) async {
    final r = await _pull(merchantId, branchId, 'stock', cursor);
    return DeltaPage(
        cursor: r['cursor'] as int,
        hasMore: r['hasMore'] as bool,
        changes: (r['changes'] as List).map((raw) {
          final c = _map(raw);
          if (c['kind'] == null) {
            return StockEvent.legacy(StockChange(
                c['sequence'] as int,
                c['productId'] as String,
                c['quantity'] as int,
                c['revision'] as int,
                c['operationId'] as String));
          }
          return StockEvent(
              sequence: c['sequence'] as int,
              operationId: c['operationId'] as String,
              kind: c['kind'] as String,
              positions: (c['positions'] as List).map((raw) {
                final p = _map(raw);
                return StockPosition(p['productId'] as String,
                    p['quantity'] as int, p['revision'] as int,
                    delta: p['delta'] as int?);
              }).toList());
        }).toList());
  }

  Future<
          ({
            List<StockTransferIntent> transfers,
            bool hasMore,
            String? nextCursor
          })>
      incomingTransfers(String merchantId, String branchId,
          {String? cursor}) async {
    final result = await _gateway.call('readIncomingTransfers', {
      'merchantId': merchantId,
      'branchId': branchId,
      if (cursor != null) 'cursor': cursor,
    });
    if (result['transfers'] is! List ||
        result['hasMore'] is! bool ||
        (result['transfers'] as List).length > 50 ||
        (result['hasMore'] == true && result['nextCursor'] is! String)) {
      throw const FormatException('Invalid incoming transfer page');
    }
    final transfers = (result['transfers'] as List)
        .map((raw) => StockTransferIntent.fromMap(_map(raw)))
        .toList();
    if (transfers.any((t) =>
        t.destinationBranchId != branchId ||
        t.status != StockTransferStatus.dispatched)) {
      throw const FormatException('Incoming transfer scope changed');
    }
    return (
      transfers: transfers,
      hasMore: result['hasMore'] as bool,
      nextCursor: result['nextCursor'] as String?
    );
  }

  @override
  Future<StockAck> push(
      String merchantId, String branchId, StockOperation operation) async {
    final data = {
      'merchantId': merchantId,
      'branchId': branchId,
      ...operation.toMap()
    };
    final command = switch (operation.kind) {
      'opening' || 'count' => 'recordStockCount',
      'receiving' => 'recordReceiving',
      'adjustment' => 'recordStockAdjustment',
      'transferOut' => 'initiateBranchTransfer',
      'transferIn' => 'receiveBranchTransfer',
      _ => throw const FormatException('Unsupported stock operation'),
    };
    if (operation.kind == 'receiving') {
      data['quantity'] = operation.details['delta'];
    }
    if (['receiving', 'adjustment'].contains(operation.kind) &&
        operation.details['delta'] is! int) {
      throw const FormatException('Stock operation needs review');
    }
    Map<String, Object?> r;
    try {
      r = await _gateway.call(command, data);
    } on FirebaseException catch (e) {
      // Permanent rejections can never succeed on retry. Record them as
      // blocked so the operation surfaces Needs review with Withdraw instead
      // of failing every sync forever. Transient and auth errors rethrow.
      if (const {'invalid-argument', 'failed-precondition', 'already-exists'}
          .contains(e.code)) {
        return StockAck(operation.id, 'blocked',
            message: e.message ?? 'Sync rejected this operation');
      }
      rethrow;
    }
    if (operation.kind.startsWith('transfer')) {
      if (r['transferId'] != operation.details['transferId']) {
        throw const FormatException('Invalid transfer acknowledgement');
      }
      r['operationId'] = operation.id;
      if (r['status'] == 'dispatched' || r['status'] == 'received') {
        r['status'] = 'accepted';
      }
    }
    final status = r['status'];
    final seq = r['sequence'];
    if (r['operationId'] != operation.id ||
        !['accepted', 'duplicate', 'conflict', 'blocked'].contains(status) ||
        (['accepted', 'duplicate'].contains(status) &&
            (seq is! int || seq < 1))) {
      throw const FormatException('Invalid inventory acknowledgement');
    }
    return StockAck(operation.id, status as String,
        sequence: seq as int?, message: r['message'] as String?);
  }

  @override
  Future<CatalogProduct> saveProduct(
      String merchantId, CatalogProduct product, String operationId) async {
    return _saveProduct(merchantId, product, operationId);
  }

  @override
  Future<ProductImageRef> uploadProductPhoto(String merchantId,
          String productId, String uploadId, List<int> bytes, String format) =>
      ProductImageFunctions(_gateway)
          .upload(merchantId, productId, uploadId, bytes, format);

  @override
  Future<CatalogProduct> saveProductWithImage(
          String merchantId,
          CatalogProduct product,
          String operationId,
          ProductImageChange imageChange) =>
      _saveProduct(merchantId, product, operationId, imageChange: imageChange);

  Future<CatalogProduct> _saveProduct(
      String merchantId, CatalogProduct product, String operationId,
      {ProductImageChange? imageChange}) async {
    final r = await _gateway.call('saveCatalogProduct', {
      'merchantId': merchantId,
      'operationId': operationId,
      'expectedRevision': product.revision,
      'product': product.toMap(),
      if (imageChange != null) 'imageChange': imageChange.toMap(),
    });
    final saved = CatalogProduct.fromMap(r);
    if (saved.id != product.id || saved.revision != product.revision + 1) {
      throw const FormatException('Invalid saved product');
    }
    return saved;
  }

  Future<StockAck> recordReceiving({
    required String merchantId,
    required String branchId,
    required String operationId,
    required String productId,
    required int quantity,
    required String reason,
    String? batchNumber,
    String? expiryDate,
  }) async {
    final r = await _gateway.call('recordReceiving', {
      'merchantId': merchantId,
      'branchId': branchId,
      'operationId': operationId,
      'productId': productId,
      'quantity': quantity,
      'reason': reason,
      if (batchNumber != null) 'batchNumber': batchNumber,
      if (expiryDate != null) 'expiryDate': expiryDate,
    });
    final status = r['status'] as String?;
    final seq = r['sequence'] as int?;
    if (r['operationId'] != operationId ||
        !['accepted', 'duplicate', 'conflict', 'blocked'].contains(status)) {
      throw const FormatException('Invalid receiving acknowledgement');
    }
    return StockAck(operationId, status!,
        sequence: seq, message: r['message'] as String?);
  }

  Future<StockAck> recordStockAdjustment({
    required String merchantId,
    required String branchId,
    required String operationId,
    required String productId,
    required int delta,
    required int expectedRevision,
    required String reason,
  }) async {
    final r = await _gateway.call('recordStockAdjustment', {
      'merchantId': merchantId,
      'branchId': branchId,
      'operationId': operationId,
      'productId': productId,
      'delta': delta,
      'expectedRevision': expectedRevision,
      'reason': reason,
    });
    final status = r['status'] as String?;
    final seq = r['sequence'] as int?;
    if (r['operationId'] != operationId ||
        !['accepted', 'duplicate', 'conflict', 'blocked'].contains(status)) {
      throw const FormatException('Invalid stock adjustment acknowledgement');
    }
    return StockAck(operationId, status!,
        sequence: seq, message: r['message'] as String?);
  }

  Future<StockAck> initiateBranchTransfer({
    required String merchantId,
    required String sourceBranchId,
    required String destinationBranchId,
    required String transferId,
    required List<StockTransferItem> items,
    required String reason,
  }) async {
    final r = await _gateway.call('initiateBranchTransfer', {
      'merchantId': merchantId,
      'sourceBranchId': sourceBranchId,
      'destinationBranchId': destinationBranchId,
      'transferId': transferId,
      'items': items.map((it) => it.toMap()).toList(),
      'reason': reason,
    });
    final status = r['status'] as String?;
    final seq = r['sequence'] as int?;
    return StockAck(transferId, status ?? 'unknown',
        sequence: seq, message: r['message'] as String?);
  }

  Future<StockAck> receiveBranchTransfer({
    required String merchantId,
    required String destinationBranchId,
    required String transferId,
    required String operationId,
  }) async {
    final r = await _gateway.call('receiveBranchTransfer', {
      'merchantId': merchantId,
      'destinationBranchId': destinationBranchId,
      'transferId': transferId,
      'operationId': operationId,
    });
    final status = r['status'] as String?;
    final seq = r['sequence'] as int?;
    return StockAck(transferId, status ?? 'unknown',
        sequence: seq, message: r['message'] as String?);
  }
}
