import { createHash } from 'node:crypto';
import { FieldValue, Firestore, Transaction } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { AuthorizationService, AuthRequest, requireHuman } from '../common/authz';
import { requireDocumentId } from '../common/ids';

type Input = Record<string, unknown>;

function text(value: unknown, max: number, allowEmpty = false): string {
  if (typeof value !== 'string' || (!allowEmpty && !value.trim()) || value.length > max) {
    throw new HttpsError('invalid-argument', 'Invalid text');
  }
  return value.trim();
}

function integer(value: unknown, min = 0, max = 1000000000): number {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < min || value > max) {
    throw new HttpsError('invalid-argument', 'Invalid quantity/revision');
  }
  return value;
}

function signedInteger(value: unknown, min = -1000000000, max = 1000000000): number {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < min || value > max) {
    throw new HttpsError('invalid-argument', 'Invalid integer delta');
  }
  return value;
}

function authz(db: Firestore, tx: Transaction) {
  return new AuthorizationService(async (path) => (await tx.get(db.doc(path))).data() ?? null);
}

const fingerprint = (payload: unknown) =>
  createHash('sha256').update(JSON.stringify(payload)).digest('hex');

const key = (sequence: number) => String(sequence).padStart(10, '0');

export async function recordReceiving(db: Firestore, request: AuthRequest, input: Input) {
  const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
  const branchId = requireDocumentId(input.branchId, 'branch ID');
  const operationId = requireDocumentId(input.operationId, 'operation ID');
  const productId = requireDocumentId(input.productId, 'product ID');
  const quantity = integer(input.quantity, 1);
  const reason = text(input.reason, 160);
  const batchNumber = input.batchNumber ? text(input.batchNumber, 64) : undefined;
  const expiryDate = input.expiryDate ? text(input.expiryDate, 32) : undefined;

  const hash = fingerprint({ productId, quantity, reason, batchNumber, expiryDate });
  const root = `merchants/${merchantId}/branches/${branchId}`;

  return db.runTransaction(async (tx) => {
    const authorization = authz(db, tx);
    if (request.auth?.token.principalType === 'device') {
      const device = await authorization.requireActiveDevice(request);
      if (device.merchantId !== merchantId || device.branchId !== branchId) {
        throw new HttpsError('permission-denied', 'Device scope mismatch');
      }
    } else {
      await authorization.requireBranchAccess(requireHuman(request), merchantId, branchId);
    }

    const receipt = db.doc(`${root}/stockOperations/${operationId}`);
    const replay = await tx.get(receipt);
    if (replay.exists) {
      if (replay.get('fingerprint') !== hash) {
        return { operationId, status: 'blocked', message: 'Operation ID has another payload' };
      }
      const result = replay.get('result');
      return { ...result, status: result.status === 'accepted' ? 'duplicate' : result.status };
    }

    const product = await tx.get(db.doc(`merchants/${merchantId}/products/${productId}`));
    if (!product.exists || product.get('active') !== true) {
      const result = { operationId, status: 'blocked', message: 'Product is unavailable' };
      tx.create(receipt, { fingerprint: hash, result, recordedAt: FieldValue.serverTimestamp() });
      return result;
    }

    const ref = db.doc(`${root}/stock/${productId}`);
    const stock = await tx.get(ref);
    const metaRef = db.doc(`${root}/inventoryMeta/stock`);
    const meta = await tx.get(metaRef);

    const previous = integer(stock.get('quantity') ?? 0, -1000000000);
    const revision = integer(stock.get('revision') ?? 0);
    const sequence = integer(meta.get('sequence') ?? 0) + 1;

    const newQuantity = previous + quantity;
    const newRevision = revision + 1;

    tx.set(ref, { quantity: newQuantity, revision: newRevision });
    tx.set(metaRef, { sequence });
    tx.create(db.doc(`${root}/stockChanges/${key(sequence)}`), {
      sequence,
      operationId,
      kind: 'receiving',
      positions: [{ productId, quantity: newQuantity, revision: newRevision, delta: quantity }],
    });

    if (batchNumber && expiryDate) {
      tx.set(db.doc(`${root}/batches/${batchNumber}`), {
        id: batchNumber,
        batchNumber,
        productId,
        quantity,
        expiryDate,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    const result = { operationId, status: 'accepted', sequence };
    tx.create(receipt, {
      fingerprint: hash,
      productId,
      quantity: newQuantity,
      delta: quantity,
      kind: 'receiving',
      reason,
      batchNumber,
      expiryDate,
      result,
      recordedAt: FieldValue.serverTimestamp(),
    });
    return result;
  });
}

export async function recordStockAdjustment(db: Firestore, request: AuthRequest, input: Input) {
  const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
  const branchId = requireDocumentId(input.branchId, 'branch ID');
  const operationId = requireDocumentId(input.operationId, 'operation ID');
  const productId = requireDocumentId(input.productId, 'product ID');
  const delta = signedInteger(input.delta);
  if (delta === 0) throw new HttpsError('invalid-argument', 'Adjustment delta cannot be zero');
  const expectedRevision = integer(input.expectedRevision);
  const reason = text(input.reason, 160);

  const hash = fingerprint({ productId, delta, expectedRevision, reason });
  const root = `merchants/${merchantId}/branches/${branchId}`;

  return db.runTransaction(async (tx) => {
    const authorization = authz(db, tx);
    if (request.auth?.token.principalType === 'device') {
      const device = await authorization.requireActiveDevice(request);
      if (device.merchantId !== merchantId || device.branchId !== branchId) {
        throw new HttpsError('permission-denied', 'Device scope mismatch');
      }
    } else {
      await authorization.requireBranchAccess(requireHuman(request), merchantId, branchId);
    }

    const receipt = db.doc(`${root}/stockOperations/${operationId}`);
    const replay = await tx.get(receipt);
    if (replay.exists) {
      if (replay.get('fingerprint') !== hash) {
        return { operationId, status: 'blocked', message: 'Operation ID has another payload' };
      }
      const result = replay.get('result');
      return { ...result, status: result.status === 'accepted' ? 'duplicate' : result.status };
    }

    const product = await tx.get(db.doc(`merchants/${merchantId}/products/${productId}`));
    if (!product.exists || product.get('active') !== true) {
      const result = { operationId, status: 'blocked', message: 'Product is unavailable' };
      tx.create(receipt, { fingerprint: hash, result, recordedAt: FieldValue.serverTimestamp() });
      return result;
    }

    const ref = db.doc(`${root}/stock/${productId}`);
    const stock = await tx.get(ref);
    const revision = integer(stock.get('revision') ?? 0);

    if (revision !== expectedRevision) {
      const result = {
        operationId,
        status: 'conflict',
        message: 'Stock changed; refresh before adjusting',
      };
      tx.create(receipt, { fingerprint: hash, result, recordedAt: FieldValue.serverTimestamp() });
      return result;
    }

    const metaRef = db.doc(`${root}/inventoryMeta/stock`);
    const meta = await tx.get(metaRef);
    const previous = integer(stock.get('quantity') ?? 0, -1000000000);
    const sequence = integer(meta.get('sequence') ?? 0) + 1;

    const newQuantity = previous + delta;
    const newRevision = revision + 1;

    tx.set(ref, { quantity: newQuantity, revision: newRevision });
    tx.set(metaRef, { sequence });
    tx.create(db.doc(`${root}/stockChanges/${key(sequence)}`), {
      sequence,
      operationId,
      kind: 'adjustment',
      positions: [{ productId, quantity: newQuantity, revision: newRevision, delta }],
    });

    const result = { operationId, status: 'accepted', sequence };
    tx.create(receipt, {
      fingerprint: hash,
      productId,
      quantity: newQuantity,
      delta,
      expectedRevision,
      kind: 'adjustment',
      reason,
      result,
      recordedAt: FieldValue.serverTimestamp(),
    });
    return result;
  });
}
