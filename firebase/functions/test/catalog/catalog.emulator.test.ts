import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { beforeAll, afterAll, describe, expect, it } from 'vitest';
import { saveCatalogProduct, recordStockCount, pullInventory } from '../../src/catalog/catalog-service';
const app = initializeApp({ projectId: 'demo-sarisupply-rules' }, 'catalog-tests');
const db = getFirestore(app);
const owner = { auth: { uid: 'catalog-owner', token: {} } };
const manager = { auth: { uid: 'catalog-manager', token: {} } };
const device = { auth: { uid: 'device:catalog-d', token: { principalType: 'device', merchantId: 'catalog-m', deviceId: 'catalog-d' } } };
const product = { id: 'p', sku: 'MILK', name: 'Milk', baseUnit: 'piece', active: true,
  units: [{ name: 'piece', factor: 1, priceCentavos: 1250, barcode: '00123' }, { name: 'pack', factor: 6, priceCentavos: 7000, barcode: '00124' }] };
const save = (extra = {}) => saveCatalogProduct(db, owner, { merchantId: 'catalog-m', operationId: 'create-p', expectedRevision: 0, product, ...extra });
const count = (id: string, kind: string, quantity: number, expectedRevision: number) => recordStockCount(db, owner, { merchantId: 'catalog-m', branchId: 'b', operationId: id, productId: 'p', kind, quantity, expectedRevision, reason: 'Physical count' });
beforeAll(async () => {
  if (!process.env.FIRESTORE_EMULATOR_HOST) throw Error('Emulator required');
  await db.doc('merchants/catalog-m').set({ status: 'active' });
  await db.doc('merchants/catalog-m/memberships/catalog-owner').set({ userId: 'catalog-owner', merchantId: 'catalog-m', role: 'owner', allBranches: true, branchIds: [], status: 'active' });
  await db.doc('merchants/catalog-m/memberships/catalog-manager').set({ userId: 'catalog-manager', merchantId: 'catalog-m', role: 'manager', allBranches: false, branchIds: ['b'], status: 'active' });
  for (const b of ['b', 'other']) await db.doc(`merchants/catalog-m/branches/${b}`).set({ merchantId: 'catalog-m', status: 'active' });
  await db.doc('merchants/catalog-m/devices/catalog-d').set({ authUid: 'device:catalog-d', merchantId: 'catalog-m', branchId: 'b', status: 'active' });
});
afterAll(() => deleteApp(app));
describe('catalog and stock', () => {
  it('saves once, rejects payload reuse, concurrent edits and barcode collisions', async () => {
    expect((await save()).revision).toBe(1);
    expect((await save()).revision).toBe(1);
    await expect(save({ product: { ...product, name: 'Changed' } })).rejects.toMatchObject({ code: 'already-exists' });
    await expect(save({ operationId: 'foreign-barcode', product: { ...product, id: 'p2', sku: 'OTHER' } })).rejects.toMatchObject({ code: 'already-exists' });
    await expect(save({ operationId: 'stale-edit', expectedRevision: 0 })).rejects.toMatchObject({ code: 'failed-precondition' });
  });
  it('opening retries are duplicate, another opening conflicts, counts use revision', async () => {
    const a = await count('open', 'opening', 12, 0); expect(a.status).toBe('accepted');
    expect((await count('open', 'opening', 12, 0)).status).toBe('duplicate');
    expect((await count('open2', 'opening', 20, 0)).status).toBe('conflict');
    expect((await count('stale', 'count', 8, 0)).status).toBe('conflict');
    expect((await count('count', 'count', 8, 1)).status).toBe('accepted');
    const page = await pullInventory(db, device, { merchantId: 'catalog-m', branchId: 'b', feed: 'stock', cursor: 0 });
    expect(page.changes.map((r: any) => r.quantity)).toEqual([12, 8]);
  });
  it('concurrent opening accepts one movement and preserves replay payload identity', async () => {
    await db.doc('merchants/catalog-m/branches/concurrent').set({ merchantId:'catalog-m',status:'active' });
    const base={merchantId:'catalog-m',branchId:'concurrent',productId:'p',kind:'opening',quantity:10,expectedRevision:0,reason:'Opening'};
    const results=await Promise.all(['a','b'].map(operationId=>recordStockCount(db,owner,{...base,operationId})));
    expect(results.map(r=>r.status).sort()).toEqual(['accepted','conflict']);
    const accepted=results.find(r=>r.status==='accepted')!;
    expect((await recordStockCount(db,owner,{...base,operationId:accepted.operationId,quantity:20})).status).toBe('blocked');
    expect((await db.doc('merchants/catalog-m/branches/concurrent/stock/p').get()).get('quantity')).toBe(10);
  }, 15000);
  it('reconciles a negative cloud balance with an immutable count delta', async () => {
    await db.doc('merchants/catalog-m/branches/short').set({merchantId:'catalog-m',status:'active'});
    await db.doc('merchants/catalog-m/branches/short/stock/p').set({quantity:-3,revision:1});
    const result=await recordStockCount(db,owner,{merchantId:'catalog-m',branchId:'short',operationId:'short-count',productId:'p',kind:'count',quantity:2,expectedRevision:1,reason:'Count after stock shortage'});
    expect(result.status).toBe('accepted');
    expect((await db.doc('merchants/catalog-m/branches/short/stockOperations/short-count').get()).get('delta')).toBe(5);
  });
  it('pages more than 50 catalog deltas and validates cursors', async () => {
    await db.doc('merchants/paged').set({status:'active'});
    await db.doc('merchants/paged/branches/b').set({merchantId:'paged',status:'active'});
    await db.doc('merchants/paged/memberships/catalog-owner').set({userId:'catalog-owner',merchantId:'paged',role:'owner',allBranches:true,branchIds:[],status:'active'});
    const batch=db.batch();
    for(let i=1;i<=51;i++)batch.set(db.doc(`merchants/paged/catalogChanges/${String(i).padStart(10,'0')}`),{sequence:i,product:{...product,id:`p${i}`,sku:`P${i}`,revision:1}});
    batch.set(db.doc('merchants/paged/inventoryMeta/catalog'),{sequence:51,total:51});await batch.commit();
    const first=await pullInventory(db,owner,{merchantId:'paged',branchId:'b',feed:'catalog',cursor:0});
    expect(first.changes).toHaveLength(50);expect(first.hasMore).toBe(true);expect(first.cursor).toBe(50);
    const last=await pullInventory(db,owner,{merchantId:'paged',branchId:'b',feed:'catalog',cursor:50});expect(last.changes).toHaveLength(1);expect(last.hasMore).toBe(false);
    await expect(pullInventory(db,owner,{merchantId:'paged',branchId:'b',feed:'catalog',cursor:52})).rejects.toMatchObject({code:'failed-precondition'});
  });
  it('rejects malformed quantities/unit conversions and revoked human membership', async () => {
    await expect(save({operationId:'bad',product:{...product,units:[{name:'piece',factor:1.5,priceCentavos:100}]}})).rejects.toMatchObject({code:'invalid-argument'});
    await expect(count('bad-count','count',1.5,2)).rejects.toMatchObject({code:'invalid-argument'});
    await db.doc('merchants/catalog-m/memberships/catalog-manager').update({status:'removed'});
    await expect(recordStockCount(db,manager,{merchantId:'catalog-m',branchId:'b',operationId:'removed',productId:'p',kind:'count',quantity:1,expectedRevision:2,reason:'Count'})).rejects.toMatchObject({code:'permission-denied'});
    await db.doc('merchants/catalog-m/memberships/catalog-manager').update({status:'active'});
  });
  it('derives device scope; denies scoped manager edits, foreign branch and revoked device', async () => {
    await expect(saveCatalogProduct(db, manager, { merchantId: 'catalog-m', operationId: 'manager-edit', expectedRevision: 1, product })).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(pullInventory(db, device, { merchantId: 'catalog-m', branchId: 'other', feed: 'stock', cursor: 0 })).rejects.toMatchObject({ code: 'permission-denied' });
    await expect(pullInventory(db, manager, { merchantId: 'catalog-m', branchId: 'other', feed: 'catalog', cursor: 0 })).rejects.toMatchObject({ code: 'permission-denied' });
    await db.doc('merchants/catalog-m/devices/catalog-d').update({ status: 'revoked' });
    await expect(pullInventory(db, device, { merchantId: 'catalog-m', branchId: 'b', feed: 'catalog', cursor: 0 })).rejects.toMatchObject({ code: 'permission-denied' });
  });
});
