import { FieldValue, FieldPath, Firestore, Transaction } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { AuthorizationService, AuthRequest, requireHuman } from '../common/authz';
import { requireDocumentId } from '../common/ids';
import { canonical } from '../checkout/checkout-validation';

type Input = Record<string, unknown>;

function text(value: unknown, max: number): string {
  if (typeof value !== 'string' || !value.trim() || value.length > max) {
    throw new HttpsError('invalid-argument', 'Invalid text');
  }
  return value.trim();
}

function integer(value: unknown, min = 0, max = 1000000000): number {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < min || value > max) {
    throw new HttpsError('invalid-argument', 'Invalid quantity');
  }
  return value;
}

function authz(db: Firestore, tx: Transaction) {
  return new AuthorizationService(async (path) => (await tx.get(db.doc(path))).data() ?? null);
}

const key = (sequence: number) => String(sequence).padStart(10, '0');

export async function initiateBranchTransfer(db: Firestore, request: AuthRequest, input: Input) {
  const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
  const sourceBranchId = requireDocumentId(input.sourceBranchId, 'source branch ID');
  const destinationBranchId = requireDocumentId(input.destinationBranchId, 'destination branch ID');
  const transferId = requireDocumentId(input.transferId, 'transfer ID');
  const reason = text(input.reason, 160);

  if (sourceBranchId === destinationBranchId) {
    throw new HttpsError('invalid-argument', 'Source and destination branches must differ');
  }

  if (!Array.isArray(input.items) || !input.items.length || input.items.length > 20) {
    throw new HttpsError('invalid-argument', 'Transfer items required (max 20)');
  }

  const items = input.items.map((raw) => {
    if (!raw || typeof raw !== 'object') throw new HttpsError('invalid-argument', 'Invalid item');
    const it = raw as Input;
    return {
      productId: requireDocumentId(it.productId, 'product ID'),
      quantity: integer(it.quantity, 1),
    };
  });

  if (new Set(items.map(i => i.productId)).size !== items.length) {
    throw new HttpsError('invalid-argument','Select unique transfer products');
  }
  const fingerprint = canonical({sourceBranchId,destinationBranchId,reason,
    items:[...items].sort((a,b) => a.productId.localeCompare(b.productId))});

  const root = `merchants/${merchantId}/branches/${sourceBranchId}`;
  const transferRef = db.doc(`merchants/${merchantId}/transfers/${transferId}`);

  return db.runTransaction(async (tx) => {
    const authorization = authz(db, tx);
    if (request.auth?.token.principalType === 'device') {
      const device = await authorization.requireActiveDevice(request);
      if (device.merchantId !== merchantId || device.branchId !== sourceBranchId) {
        throw new HttpsError('permission-denied', 'Device scope mismatch');
      }
    } else {
      await authorization.requireBranchAccess(requireHuman(request), merchantId, sourceBranchId);
    }

    const existing = await tx.get(transferRef);
    if (existing.exists) {
      const saved = canonical({sourceBranchId:existing.get('sourceBranchId'),destinationBranchId:existing.get('destinationBranchId'),
        reason:existing.get('reason'),items:[...existing.get('items')].sort((a,b) => a.productId.localeCompare(b.productId))});
      if (saved === fingerprint) {
        return { transferId, status: existing.get('status'), sequence: existing.get('dispatchSequence') };
      }
      throw new HttpsError('already-exists', 'Transfer ID already exists with different parameters');
    }

    const destination = await tx.get(db.doc(`merchants/${merchantId}/branches/${destinationBranchId}`));
    if (destination.get('status') !== 'active' || destination.get('merchantId') !== merchantId) {
      throw new HttpsError('failed-precondition','Destination branch is unavailable');
    }
    const metaRef = db.doc(`${root}/inventoryMeta/stock`);
    const stockDocs = await Promise.all(items.map((it) => tx.get(db.doc(`${root}/stock/${it.productId}`))));
    const meta = await tx.get(metaRef);
    const sequence = integer(meta.get('sequence') ?? 0) + 1;

    const stockWrites: { productId: string; quantity: number; revision: number; delta: number }[] = [];
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const stockDoc = stockDocs[i];
      const prevQty = integer(stockDoc.get('quantity') ?? 0, -1000000000);
      const revision = integer(stockDoc.get('revision') ?? 0);

      const newQty = integer(prevQty - item.quantity, -1000000000);
      const newRev = revision + 1;
      stockWrites.push({
        productId: item.productId,
        quantity: newQty,
        revision: newRev,
        delta: -item.quantity,
      });
      tx.set(db.doc(`${root}/stock/${item.productId}`), { quantity: newQty, revision: newRev });
    }

    tx.set(metaRef, { sequence });
    tx.create(db.doc(`${root}/stockChanges/${key(sequence)}`), {
      sequence,
      operationId: transferId,
      kind: 'transferOut',
      positions: stockWrites,
    });

    const transferData = {
      id: transferId,
      fingerprint,
      merchantId,
      sourceBranchId,
      destinationBranchId,
      items,
      reason,
      status: 'dispatched',
      dispatchSequence: sequence,
      dispatchedAt: FieldValue.serverTimestamp(),
    };
    tx.create(transferRef, transferData);

    return { transferId, status: 'dispatched', sequence };
  });
}

export async function receiveBranchTransfer(db: Firestore, request: AuthRequest, input: Input) {
  const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
  const destinationBranchId = requireDocumentId(input.destinationBranchId, 'destination branch ID');
  const transferId = requireDocumentId(input.transferId, 'transfer ID');
  const operationId = requireDocumentId(input.operationId, 'operation ID');

  const root = `merchants/${merchantId}/branches/${destinationBranchId}`;
  const transferRef = db.doc(`merchants/${merchantId}/transfers/${transferId}`);

  return db.runTransaction(async (tx) => {
    const authorization = authz(db, tx);
    if (request.auth?.token.principalType === 'device') {
      const device = await authorization.requireActiveDevice(request);
      if (device.merchantId !== merchantId || device.branchId !== destinationBranchId) {
        throw new HttpsError('permission-denied', 'Device scope mismatch');
      }
    } else {
      await authorization.requireBranchAccess(requireHuman(request), merchantId, destinationBranchId);
    }

    const transferDoc = await tx.get(transferRef);
    if (!transferDoc.exists) {
      throw new HttpsError('not-found', 'Transfer not found');
    }

    if (transferDoc.get('destinationBranchId') !== destinationBranchId) {
      throw new HttpsError('permission-denied', 'Transfer is for a different branch');
    }

    const currentStatus = transferDoc.get('status');
    if (currentStatus === 'received') {
      if (transferDoc.get('receivedOperationId') === operationId) {
        return { transferId, status: 'duplicate', sequence: transferDoc.get('receiveSequence') };
      }
      throw new HttpsError('failed-precondition', 'Transfer has already been received');
    }

    if (currentStatus !== 'dispatched') {
      throw new HttpsError('failed-precondition', `Cannot receive transfer with status: ${currentStatus}`);
    }

    const items = transferDoc.get('items') as { productId: string; quantity: number }[];
    if (!items.length || items.length > 20 || new Set(items.map(i => i.productId)).size !== items.length) {
      throw new HttpsError('failed-precondition','Transfer manifest needs review');
    }
    const metaRef = db.doc(`${root}/inventoryMeta/stock`);
    const stockDocs = await Promise.all(items.map((it) => tx.get(db.doc(`${root}/stock/${it.productId}`))));
    const meta = await tx.get(metaRef);
    const sequence = integer(meta.get('sequence') ?? 0) + 1;

    const stockWrites: { productId: string; quantity: number; revision: number; delta: number }[] = [];
    for (let i = 0; i < items.length; i++) {
      const item = items[i];
      const stockDoc = stockDocs[i];
      const prevQty = integer(stockDoc.get('quantity') ?? 0, -1000000000);
      const revision = integer(stockDoc.get('revision') ?? 0);

      const newQty = integer(prevQty + item.quantity, -1000000000);
      const newRev = revision + 1;
      stockWrites.push({
        productId: item.productId,
        quantity: newQty,
        revision: newRev,
        delta: item.quantity,
      });
      tx.set(db.doc(`${root}/stock/${item.productId}`), { quantity: newQty, revision: newRev });
    }

    tx.set(metaRef, { sequence });
    tx.create(db.doc(`${root}/stockChanges/${key(sequence)}`), {
      sequence,
      operationId,
      kind: 'transferIn',
      positions: stockWrites,
    });

    tx.update(transferRef, {
      status: 'received',
      receivedOperationId: operationId,
      receiveSequence: sequence,
      receivedAt: FieldValue.serverTimestamp(),
    });

    return { transferId, status: 'accepted', sequence };
  });
}

export async function readIncomingTransfers(db: Firestore, request: AuthRequest, input: Input) {
  const merchantId = requireDocumentId(input.merchantId,'merchant ID');
  const branchId = requireDocumentId(input.branchId,'branch ID');
  const cursor = input.cursor == null ? null : requireDocumentId(input.cursor,'transfer cursor');
  return db.runTransaction(async tx => {
    const authorization = authz(db,tx);
    if (request.auth?.token.principalType === 'device') {
      const device = await authorization.requireActiveDevice(request);
      if (device.merchantId !== merchantId || device.branchId !== branchId) throw new HttpsError('permission-denied','Device scope mismatch');
    } else await authorization.requireBranchAccess(requireHuman(request),merchantId,branchId);
    let query = db.collection(`merchants/${merchantId}/transfers`)
      .where('destinationBranchId','==',branchId).where('status','==','dispatched')
      .orderBy(FieldPath.documentId()).limit(51);
    if (cursor) query = query.startAfter(cursor);
    const page = await tx.get(query), docs = page.docs.slice(0,50);
    return {transfers:docs.map(doc => { const data = doc.data(); return {
      id:doc.id,sourceBranchId:data.sourceBranchId,destinationBranchId:data.destinationBranchId,
      status:data.status,items:data.items,notes:data.reason ?? '',
      occurredAt:data.dispatchedAt.toDate().toISOString(),
    }; }),hasMore:page.size>50,nextCursor:page.size>50?docs.at(-1)!.id:null};
  });
}
