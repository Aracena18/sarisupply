import { createHash } from 'node:crypto';
import { FieldPath, FieldValue, Firestore, Transaction } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { AuthorizationService, AuthRequest, requireHuman } from '../common/authz';
import { requireDocumentId } from '../common/ids';
import { ProductImage } from '../media/cloudinary';
import { commitImageChange, externalImageUrl, imageChangeInput, resolveImageChange } from '../media/product-image-service';

type Input = Record<string, unknown>;
type Unit = { name: string; factor: number; priceCentavos: number; barcode: string };
type Product = { id: string; sku: string; name: string; baseUnit: string; active: boolean; units: Unit[]; revision: number; imageUrl?: string; image?: ProductImage };
function text(value: unknown, max: number): string {
  if (typeof value !== 'string' || !value.trim() || value.length > max) throw new HttpsError('invalid-argument', 'Invalid text');
  return value.trim();
}
function integer(value: unknown, min = 0, max = 1000000000): number {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < min || value > max) throw new HttpsError('invalid-argument', 'Invalid quantity/revision');
  return value;
}
function productInput(value: unknown): Product {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new HttpsError('invalid-argument', 'Invalid product');
  const p = value as Input;
  const id = requireDocumentId(p.id, 'product ID');
  const sku = text(p.sku, 40);
  if (!/^[A-Z0-9_-]{1,40}$/.test(sku) || typeof p.active !== 'boolean' || !Array.isArray(p.units) || !p.units.length || p.units.length > 12) throw new HttpsError('invalid-argument', 'Invalid product');
  const baseUnit = text(p.baseUnit, 30);
  const units = p.units.map((raw): Unit => {
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw new HttpsError('invalid-argument', 'Invalid unit');
    const u = raw as Input;
    const barcode = u.barcode ?? '';
    if (typeof barcode !== 'string' || !/^[A-Za-z0-9._-]{0,64}$/.test(barcode)) throw new HttpsError('invalid-argument', 'Invalid barcode');
    return { name: text(u.name, 30), factor: integer(u.factor, 1, 1000000), priceCentavos: integer(u.priceCentavos), barcode };
  });
  if (units[0].name !== baseUnit || units[0].factor !== 1 || new Set(units.map(u => u.name.toLowerCase())).size !== units.length || new Set(units.filter(u => u.barcode).map(u => u.barcode)).size !== units.filter(u => u.barcode).length) throw new HttpsError('invalid-argument', 'Invalid unit conversion/barcode');
  return { id, sku, name: text(p.name, 120), baseUnit, active: p.active, units, revision: 0,
    ...(p.imageUrl ? { imageUrl: externalImageUrl(p.imageUrl) } : {}) };
}
function authz(db: Firestore, tx: Transaction) {
  return new AuthorizationService(async (path) => (await tx.get(db.doc(path))).data() ?? null);
}
const fingerprint = (payload: unknown) => createHash('sha256').update(JSON.stringify(payload)).digest('hex');
const key = (sequence: number) => String(sequence).padStart(10, '0');
const barcodeKey = (barcode: string) => Buffer.from(barcode).toString('base64url');

export async function saveCatalogProduct(db: Firestore, request: AuthRequest, input: Input): Promise<Product> {
  const uid = requireHuman(request);
  const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
  const operationId = requireDocumentId(input.operationId, 'operation ID');
  const expected = integer(input.expectedRevision);
  const p = productInput(input.product);
  const imageChange = imageChangeInput(input);
  const root = `merchants/${merchantId}`;
  const receipt = db.doc(`${root}/catalogOperations/${operationId}`);
  const hash = fingerprint({ uid, expected, p, ...(input.imageChange === undefined ? {} : { imageChange }) });
  const legacyProduct = { ...p };
  delete legacyProduct.imageUrl;
  const legacyHash = fingerprint({ uid, expected, p: legacyProduct });
  return db.runTransaction(async tx => {
    await authz(db, tx).requireOwner(uid, merchantId);
    const replay = await tx.get(receipt);
    if (replay.exists) {
      const legacyReplay = input.imageChange === undefined && replay.get('imageContractVersion') === undefined &&
        replay.get('fingerprint') === legacyHash;
      if (replay.get('fingerprint') !== hash && !legacyReplay) throw new HttpsError('already-exists', 'Operation ID has another payload');
      return replay.get('product') as Product;
    }
    const ref = db.doc(`${root}/products/${p.id}`);
    const current = await tx.get(ref);
    const existing = current.data() as Product | undefined;
    const photo = await resolveImageChange(db, tx, merchantId, p.id, uid, imageChange, existing, p.imageUrl);
    if ((existing?.revision ?? 0) !== expected) throw new HttpsError('failed-precondition', 'Product changed; refresh before editing');
    if (existing && (existing.sku !== p.sku || existing.baseUnit !== p.baseUnit)) throw new HttpsError('failed-precondition', 'SKU and base unit are immutable');
    const metaRef = db.doc(`${root}/inventoryMeta/catalog`);
    const meta = await tx.get(metaRef);
    const total = integer(meta.get('total') ?? 0, 0, 3000);
    if (!existing && total === 3000) throw new HttpsError('resource-exhausted', 'Catalog limit reached');
    const sequence = integer(meta.get('sequence') ?? 0) + 1;
    const skuRef = db.doc(`${root}/skuRegistry/${p.sku}`);
    const sku = await tx.get(skuRef);
    if (sku.exists && sku.get('productId') !== p.id) throw new HttpsError('already-exists', 'SKU belongs to another product');
    const oldCodes = existing?.units.map(u => u.barcode).filter(Boolean) ?? [];
    const codes = p.units.map(u => u.barcode).filter(Boolean);
    const allCodes = [...new Set([...oldCodes, ...codes])];
    for (const code of allCodes) {
      const reservation = await tx.get(db.doc(`${root}/barcodeRegistry/${barcodeKey(code)}`));
      if (codes.includes(code) && reservation.exists && reservation.get('productId') !== p.id) throw new HttpsError('already-exists', 'Barcode belongs to another product');
    }
    const saved: Product = { ...p, revision: expected + 1 };
    delete saved.imageUrl;
    if (photo.imageUrl) saved.imageUrl = photo.imageUrl;
    if (photo.image) saved.image = photo.image;
    commitImageChange(db, tx, merchantId, p.id, imageChange, existing?.image, saved.image);
    tx.set(ref, saved);
    tx.set(skuRef, { productId: p.id });
    for (const code of oldCodes) if (!codes.includes(code)) tx.delete(db.doc(`${root}/barcodeRegistry/${barcodeKey(code)}`));
    for (const code of codes) tx.set(db.doc(`${root}/barcodeRegistry/${barcodeKey(code)}`), { productId: p.id });
    tx.set(metaRef, { sequence, total: existing ? total : total + 1 });
    tx.create(db.doc(`${root}/catalogChanges/${key(sequence)}`), { sequence, product: saved });
    tx.create(receipt, { fingerprint: hash, imageContractVersion: 1, product: saved, actor: uid, recordedAt: FieldValue.serverTimestamp() });
    return saved;
  });
}

export async function recordStockCount(db: Firestore, request: AuthRequest, input: Input) {
  const uid = requireHuman(request);
  const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
  const branchId = requireDocumentId(input.branchId, 'branch ID');
  const operationId = requireDocumentId(input.operationId, 'operation ID');
  const productId = requireDocumentId(input.productId, 'product ID');
  const expectedRevision = integer(input.expectedRevision);
  const quantity = integer(input.quantity);
  const reason = text(input.reason, 160);
  const kind = input.kind;
  if (kind !== 'opening' && kind !== 'count') throw new HttpsError('invalid-argument', 'Invalid stock operation');
  const hash = fingerprint({ productId, expectedRevision, quantity, kind, reason });
  const root = `merchants/${merchantId}/branches/${branchId}`;
  return db.runTransaction(async tx => {
    await authz(db, tx).requireBranchAccess(uid, merchantId, branchId);
    const receipt = db.doc(`${root}/stockOperations/${operationId}`);
    const replay = await tx.get(receipt);
    if (replay.exists) {
      if (replay.get('fingerprint') !== hash) return { operationId, status: 'blocked', message: 'Operation ID has another payload' };
      const result = replay.get('result');
      return { ...result, status: result.status === 'accepted' ? 'duplicate' : result.status };
    }
    const product = await tx.get(db.doc(`merchants/${merchantId}/products/${productId}`));
    const ref = db.doc(`${root}/stock/${productId}`);
    const stock = await tx.get(ref);
    const metaRef = db.doc(`${root}/inventoryMeta/stock`);
    const meta = await tx.get(metaRef);
    const previous = integer(stock.get('quantity') ?? 0, -1000000000);
    const revision = integer(stock.get('revision') ?? 0);
    const sequence = integer(meta.get('sequence') ?? 0) + 1;
    let result: { operationId: string; status: string; sequence?: number; message?: string };
    if (!product.exists || product.get('active') !== true) {
      result = { operationId, status: 'blocked', message: 'Product is unavailable' };
    } else if ((kind === 'opening' && stock.exists) || revision !== expectedRevision) {
      result = { operationId, status: 'conflict', message: 'Stock changed; refresh and record a new count' };
    } else {
      result = { operationId, status: 'accepted', sequence };
      tx.set(ref, { quantity, revision: revision + 1 });
      tx.set(metaRef, { sequence });
      tx.create(db.doc(`${root}/stockChanges/${key(sequence)}`), { sequence, productId, quantity, revision: revision + 1, operationId });
    }
    // One immutable record is both audit ledger and durable idempotency receipt.
    tx.create(receipt, { fingerprint: hash, productId, quantity, delta: quantity - previous, expectedRevision, kind, reason, actor: uid, result, recordedAt: FieldValue.serverTimestamp() });
    return result;
  });
}

export async function pullInventory(db: Firestore, request: AuthRequest, input: Input) {
  const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
  const branchId = requireDocumentId(input.branchId, 'branch ID');
  const cursor = integer(input.cursor);
  const feed = input.feed;
  if (feed !== 'catalog' && feed !== 'stock') throw new HttpsError('invalid-argument', 'Invalid feed');
  return db.runTransaction(async tx => {
    const authorization = authz(db, tx);
    if (request.auth?.token.principalType === 'device') {
      const device = await authorization.requireActiveDevice(request);
      if (device.merchantId !== merchantId || device.branchId !== branchId) throw new HttpsError('permission-denied', 'Device scope mismatch');
    } else {
      await authorization.requireBranchAccess(requireHuman(request), merchantId, branchId);
    }
    const root = feed === 'catalog' ? `merchants/${merchantId}` : `merchants/${merchantId}/branches/${branchId}`;
    const meta = await tx.get(db.doc(`${root}/inventoryMeta/${feed}`));
    const head = integer(meta.get('sequence') ?? 0);
    if (cursor > head) throw new HttpsError('failed-precondition', 'Cursor exceeds feed');
    const page = await tx.get(db.collection(`${root}/${feed}Changes`).orderBy(FieldPath.documentId()).startAfter(key(cursor)).endAt(key(head)).limit(50));
    const changes = page.docs.map(d => d.data());
    const next = changes.length ? changes[changes.length - 1].sequence as number : cursor;
    if (next !== cursor + changes.length) throw new HttpsError('data-loss', 'Inventory feed is incomplete');
    return { cursor: next, hasMore: next < head, changes };
  });
}
