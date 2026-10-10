final class CatalogUnit {
  CatalogUnit(
      {required this.name,
      required this.factor,
      required this.priceCentavos,
      this.barcode = ''}) {
    if (name.trim().isEmpty ||
        name.length > 30 ||
        factor < 1 ||
        factor > 1000000 ||
        priceCentavos < 0 ||
        priceCentavos > 1000000000 ||
        !RegExp(r'^[A-Za-z0-9._-]{0,64}$').hasMatch(barcode)) {
      throw ArgumentError('Invalid sale unit');
    }
  }
  final String name;
  final int factor;
  final int priceCentavos;
  final String barcode;
  Map<String, Object?> toMap() => {
        'name': name,
        'factor': factor,
        'priceCentavos': priceCentavos,
        'barcode': barcode
      };
  factory CatalogUnit.fromMap(Map<String, Object?> m) => CatalogUnit(
      name: m['name'] as String,
      factor: m['factor'] as int,
      priceCentavos: m['priceCentavos'] as int,
      barcode: m['barcode'] as String);
}

final class ProductImageRef {
  const ProductImageRef(
      {required this.assetId,
      required this.publicId,
      required this.version,
      required this.secureUrl,
      required this.thumbnailUrl});
  final String assetId, publicId, secureUrl, thumbnailUrl;
  final int version;
  Map<String, Object?> toMap() => {
        'assetId': assetId,
        'publicId': publicId,
        'version': version,
        'secureUrl': secureUrl,
        'thumbnailUrl': thumbnailUrl
      };
  factory ProductImageRef.fromMap(Map<String, Object?> map) => ProductImageRef(
      assetId: map['assetId'] as String,
      publicId: map['publicId'] as String,
      version: map['version'] as int,
      secureUrl: map['secureUrl'] as String,
      thumbnailUrl: map['thumbnailUrl'] as String);
}

final class ProductImageChange {
  const ProductImageChange.keep()
      : action = 'keep',
        uploadId = null,
        url = null;
  const ProductImageChange.remove()
      : action = 'remove',
        uploadId = null,
        url = null;
  const ProductImageChange.upload(this.uploadId)
      : action = 'set',
        url = null;
  const ProductImageChange.url(this.url)
      : action = 'url',
        uploadId = null;
  final String action;
  final String? uploadId, url;
  Map<String, Object?> toMap() => {
        'action': action,
        if (uploadId != null) 'uploadId': uploadId,
        if (url != null) 'url': url
      };
}

abstract interface class ProductImageGateway {
  Future<ProductImageRef> uploadProductPhoto(String merchantId,
      String productId, String uploadId, List<int> bytes, String format);
  Future<CatalogProduct> saveProductWithImage(
      String merchantId,
      CatalogProduct product,
      String operationId,
      ProductImageChange imageChange);
}

final class CatalogProduct {
  CatalogProduct(
      {required this.id,
      required this.sku,
      required this.name,
      required this.baseUnit,
      required this.revision,
      required this.active,
      required List<CatalogUnit> units,
      this.imageUrl,
      this.image})
      : units = List.unmodifiable(units) {
    if (id.isEmpty ||
        id.length > 128 ||
        id.contains('/') ||
        !RegExp(r'^[A-Z0-9_-]{1,40}$').hasMatch(sku) ||
        name.trim().isEmpty ||
        name.length > 120 ||
        baseUnit.trim().isEmpty ||
        baseUnit.length > 30 ||
        revision < 0 ||
        units.isEmpty ||
        units.length > 12 ||
        units.first.factor != 1 ||
        units.first.name != baseUnit ||
        units.map((u) => u.name.toLowerCase()).toSet().length != units.length ||
        units
                .where((u) => u.barcode.isNotEmpty)
                .map((u) => u.barcode)
                .toSet()
                .length !=
            units.where((u) => u.barcode.isNotEmpty).length) {
      throw ArgumentError('Invalid product');
    }
  }
  final String id, sku, name, baseUnit;
  final int revision;
  final bool active;
  final List<CatalogUnit> units;
  final String? imageUrl;
  final ProductImageRef? image;
  String? get thumbnailUrl => image?.thumbnailUrl ?? imageUrl;
  Map<String, Object?> toMap() => {
        'id': id,
        'sku': sku,
        'name': name,
        'baseUnit': baseUnit,
        'revision': revision,
        'active': active,
        'units': units.map((u) => u.toMap()).toList(),
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (image != null) 'image': image!.toMap(),
      };
  factory CatalogProduct.fromMap(Map<String, Object?> m) => CatalogProduct(
      id: m['id'] as String,
      sku: m['sku'] as String,
      name: m['name'] as String,
      baseUnit: m['baseUnit'] as String,
      revision: m['revision'] as int,
      active: m['active'] as bool,
      imageUrl: m['imageUrl'] as String?,
      image: m['image'] == null
          ? null
          : ProductImageRef.fromMap(
              Map<String, Object?>.from(m['image'] as Map)),
      units: (m['units'] as List)
          .map((u) => CatalogUnit.fromMap(Map<String, Object?>.from(u as Map)))
          .toList());

  CatalogProduct copyWith({
    String? id,
    String? sku,
    String? name,
    String? baseUnit,
    int? revision,
    bool? active,
    List<CatalogUnit>? units,
    String? imageUrl,
    ProductImageRef? image,
    bool clearImage = false,
  }) =>
      CatalogProduct(
        id: id ?? this.id,
        sku: sku ?? this.sku,
        name: name ?? this.name,
        baseUnit: baseUnit ?? this.baseUnit,
        revision: revision ?? this.revision,
        active: active ?? this.active,
        units: units ?? this.units,
        imageUrl: clearImage ? null : imageUrl ?? this.imageUrl,
        image: clearImage ? null : image ?? this.image,
      );
}

final class CatalogChange {
  const CatalogChange(this.sequence, this.product);
  final int sequence;
  final CatalogProduct product;
}

final class StockChange {
  const StockChange(this.sequence, this.productId, this.quantity, this.revision,
      this.operationId);
  final int sequence, quantity, revision;
  final String productId, operationId;
}

final class DeltaPage<T> {
  DeltaPage(
      {required this.cursor, required this.hasMore, required List<T> changes})
      : changes = List.unmodifiable(changes);
  final int cursor;
  final bool hasMore;
  final List<T> changes;
}

final class StockOperation {
  const StockOperation(
      {required this.id,
      required this.productId,
      required this.kind,
      required this.quantity,
      required this.expectedRevision,
      required this.reason,
      this.status = 'pending',
      this.productName = '',
      this.details = const {},
      this.message});
  final String id, productId, kind, reason, status, productName;
  final int quantity, expectedRevision;
  final String? message;
  final Map<String, Object?> details;
  Map<String, Object?> toMap() => {
        'operationId': id,
        'productId': productId,
        'kind': kind,
        'quantity': quantity,
        'expectedRevision': expectedRevision,
        'reason': reason,
        ...details,
      };
}

final class StockAck {
  const StockAck(this.operationId, this.status, {this.sequence, this.message});
  final String operationId, status;
  final int? sequence;
  final String? message;
}

abstract interface class InventoryGateway {
  Future<DeltaPage<CatalogChange>> pullCatalog(
      String merchantId, String branchId, int cursor);
  Future<DeltaPage<StockEvent>> pullStock(
      String merchantId, String branchId, int cursor);
  Future<StockAck> push(
      String merchantId, String branchId, StockOperation operation);
  Future<CatalogProduct> saveProduct(
      String merchantId, CatalogProduct product, String operationId);
}

final class StockPosition {
  StockPosition(this.productId, this.quantity, this.revision, {this.delta}) {
    if (productId.isEmpty ||
        productId.length > 128 ||
        productId.contains('/') ||
        quantity.abs() > 1000000000 ||
        revision < 1 ||
        (delta != null && delta!.abs() > 1000000000)) {
      throw ArgumentError('Invalid stock position');
    }
  }
  final String productId;
  final int quantity, revision;
  final int? delta;
  Map<String, Object?> toMap() => {
        'productId': productId,
        'quantity': quantity,
        'revision': revision,
        if (delta != null) 'delta': delta
      };
}

final class StockEvent {
  StockEvent(
      {required this.sequence,
      required this.operationId,
      required this.kind,
      required List<StockPosition> positions})
      : positions = List.unmodifiable(positions) {
    if (sequence < 1 ||
        operationId.isEmpty ||
        operationId.length > 128 ||
        operationId.contains('/') ||
        !const {
          'count',
          'sale',
          'receiving',
          'adjustment',
          'transferOut',
          'transferIn',
          'refund',
          'void'
        }.contains(kind) ||
        positions.isEmpty ||
        positions.length > 20 ||
        positions.map((p) => p.productId).toSet().length != positions.length ||
        (kind == 'count' && positions.length != 1) ||
        ((kind == 'sale' || kind == 'transferOut') &&
            positions.any((p) => p.delta == null || p.delta! >= 0)) ||
        ((kind == 'receiving' ||
                kind == 'transferIn' ||
                kind == 'refund' ||
                kind == 'void') &&
            positions.any((p) => p.delta == null || p.delta! <= 0)) ||
        (kind == 'adjustment' &&
            positions.any((p) => p.delta == null || p.delta! == 0))) {
      throw ArgumentError('Invalid stock event');
    }
  }
  factory StockEvent.legacy(StockChange c) => StockEvent(
      sequence: c.sequence,
      operationId: c.operationId,
      kind: 'count',
      positions: [StockPosition(c.productId, c.quantity, c.revision)]);
  final int sequence;
  final String operationId, kind;
  final List<StockPosition> positions;
}
