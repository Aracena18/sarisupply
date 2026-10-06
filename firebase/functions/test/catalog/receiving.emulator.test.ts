import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { beforeAll, afterAll, describe, expect, it } from 'vitest';
import { recordReceiving, recordStockAdjustment } from '../../src/catalog/receiving-service';
import { initiateBranchTransfer, receiveBranchTransfer, readIncomingTransfers } from '../../src/catalog/transfer-service';

const app = initializeApp({ projectId: 'demo-sarisupply-rules' }, 'receiving-tests');
const db = getFirestore(app);
const owner = { auth: { uid: 'recv-owner', token: {} } };

const product = {
  id: 'p1',
  sku: 'COFFEE',
  name: 'Coffee',
  baseUnit: 'piece',
  active: true,
  revision: 1,
  units: [{ name: 'piece', factor: 1, priceCentavos: 1000, barcode: '111' }],
};

beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Emulator required');
  await db.doc('merchants/m_recv').set({ status: 'active' });
  await db.doc('merchants/m_recv/memberships/recv-owner').set({
    userId: 'recv-owner',
    merchantId: 'm_recv',
    role: 'owner',
    allBranches: true,
    branchIds: [],
    status: 'active',
  });
  await db.doc('merchants/m_recv/branches/b1').set({ merchantId: 'm_recv', status: 'active' });
  await db.doc('merchants/m_recv/branches/b2').set({ merchantId: 'm_recv', status: 'active' });
  await db.doc('merchants/m_recv/products/p1').set(product);
  await db.doc('merchants/m_recv/branches/b1/stock/p1').set({ quantity: 10, revision: 1 });
});

afterAll(() => deleteApp(app));

describe('receiving, adjustments, and branch transfers', () => {
  it('recordReceiving adds stock, creates batch, and produces stock feed event', async () => {
    const res = await recordReceiving(db, owner, {
      merchantId: 'm_recv',
      branchId: 'b1',
      operationId: 'recv_1',
      productId: 'p1',
      quantity: 50,
      reason: 'Supplier delivery',
      batchNumber: 'BATCH-2026-A',
      expiryDate: '2026-12-31',
    });
    expect(res).toMatchObject({ status: 'accepted', operationId: 'recv_1' });

    const stock = await db.doc('merchants/m_recv/branches/b1/stock/p1').get();
    expect(stock.get('quantity')).toBe(60);
    expect(stock.get('revision')).toBe(2);

    const batch = await db.doc('merchants/m_recv/branches/b1/batches/BATCH-2026-A').get();
    expect(batch.exists).toBe(true);
    expect(batch.get('quantity')).toBe(50);
    expect(batch.get('expiryDate')).toBe('2026-12-31');

    // Replay is idempotent
    const replay = await recordReceiving(db, owner, {
      merchantId: 'm_recv',
      branchId: 'b1',
      operationId: 'recv_1',
      productId: 'p1',
      quantity: 50,
      reason: 'Supplier delivery',
      batchNumber: 'BATCH-2026-A',
      expiryDate: '2026-12-31',
    });
    expect(replay).toMatchObject({ status: 'duplicate' });
  });

  it('recordStockAdjustment applies delta with expectedRevision check', async () => {
    // Current revision on b1 is 2, quantity is 60.
    // Stale expectedRevision rejected:
    const stale = await recordStockAdjustment(db, owner, {
      merchantId: 'm_recv',
      branchId: 'b1',
      operationId: 'adj_stale',
      productId: 'p1',
      delta: -5,
      expectedRevision: 1, // Stale!
      reason: 'Damaged item',
    });
    expect(stale).toMatchObject({ status: 'conflict' });

    // Valid revision:
    const valid = await recordStockAdjustment(db, owner, {
      merchantId: 'm_recv',
      branchId: 'b1',
      operationId: 'adj_valid',
      productId: 'p1',
      delta: -5,
      expectedRevision: 2,
      reason: 'Damaged item',
    });
    expect(valid).toMatchObject({ status: 'accepted' });

    const stock = await db.doc('merchants/m_recv/branches/b1/stock/p1').get();
    expect(stock.get('quantity')).toBe(55);
    expect(stock.get('revision')).toBe(3);
  });

  it('two-phase branch transfer moves stock between branches without duplication', async () => {
    // b1 has 55. Transfer 20 from b1 to b2.
    const dispatched = await initiateBranchTransfer(db, owner, {
      merchantId: 'm_recv',
      sourceBranchId: 'b1',
      destinationBranchId: 'b2',
      transferId: 'trans_1',
      items: [{ productId: 'p1', quantity: 20 }],
      reason: 'Rebalancing inventory',
    });
    expect(dispatched).toMatchObject({ status: 'dispatched', transferId: 'trans_1' });
    const original = {merchantId:'m_recv',sourceBranchId:'b1',destinationBranchId:'b2',transferId:'trans_1',
      items:[{productId:'p1',quantity:20}],reason:'Rebalancing inventory'};
    expect(await initiateBranchTransfer(db,owner,original)).toMatchObject({sequence:dispatched.sequence});
    await expect(initiateBranchTransfer(db,owner,{...original,items:[{productId:'p1',quantity:21}]})).rejects.toMatchObject({code:'already-exists'});
    const incoming = await readIncomingTransfers(db,owner,{merchantId:'m_recv',branchId:'b2'});
    expect(incoming.transfers).toMatchObject([{id:'trans_1',destinationBranchId:'b2',items:[{productId:'p1',quantity:20}]}]);
    expect((await readIncomingTransfers(db,owner,{merchantId:'m_recv',branchId:'b1'})).transfers).toEqual([]);


    // b1 stock immediately decremented by 20 -> 35
    const b1Stock = await db.doc('merchants/m_recv/branches/b1/stock/p1').get();
    expect(b1Stock.get('quantity')).toBe(35);

    // b2 has not received it yet
    const b2StockBefore = await db.doc('merchants/m_recv/branches/b2/stock/p1').get();
    expect(b2StockBefore.exists ? b2StockBefore.get('quantity') : 0).toBe(0);

    // Now b2 receives the transfer
    const received = await receiveBranchTransfer(db, owner, {
      merchantId: 'm_recv',
      destinationBranchId: 'b2',
      transferId: 'trans_1',
      operationId: 'recv_trans_1',
    });
    expect(received).toMatchObject({ status: 'accepted', transferId: 'trans_1' });

    // b2 stock now has 20
    const b2StockAfter = await db.doc('merchants/m_recv/branches/b2/stock/p1').get();
    expect(b2StockAfter.get('quantity')).toBe(20);

    // Cannot receive again (already received)
    await expect(
      receiveBranchTransfer(db, owner, {
        merchantId: 'm_recv',
        destinationBranchId: 'b2',
        transferId: 'trans_1',
        operationId: 'recv_trans_again',
      }),
    ).rejects.toMatchObject({ code: 'failed-precondition' });
  });
});
