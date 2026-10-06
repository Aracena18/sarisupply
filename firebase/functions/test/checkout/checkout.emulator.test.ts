import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { beforeEach, afterAll, expect, it } from 'vitest';
import { hashGrantSecret } from '../../src/checkout/cashier-grants';
import { manageCustomers } from '../../src/checkout/customer-service';
import { recordCheckoutOperation, resolveCatalogQuotes } from '../../src/checkout/checkout-service';
const app = initializeApp({ projectId: 'demo-sarisupply-rules' }, 'checkout-operations');
const db = getFirestore(app), root = 'merchants/m/branches/b';
const device = { auth: { uid: 'device:d', token: { principalType: 'device', merchantId: 'm', deviceId: 'd' } } };
const scope = { merchantId: 'm', branchId: 'b', deviceId: 'd', cashierId: 'c', grantId: 'g', credentialVersion: 1 };
const secret = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
let time: string;
const line = (n = 1) => ({ productId: `p${n}`, sku: `SKU${n}`, name: `Product ${n}`, unit: 'pack', factor: 6, priceCentavos: 500, quantity: 1, catalogSequence: n, catalogRevision: 1 });
function intent(id: string, kind: string, ordinal: number, payload: Record<string, unknown>, binding = scope, shiftId = 'shift') {
  return { id, kind, ordinal, payload, scope: binding, shiftId, occurredAt: time };
}
const opening = () => intent('shift', 'openShift', 1, { floatCentavos: 1000 });
const sale = (id = 'sale', ordinal = 2, lines = [1,2,3,4,5].map(line)) => intent(id, 'sale', ordinal, {
  merchantName: 'Store', branchName: 'Main', lines, tender: { kind: 'cash', receivedCentavos: 3000, reference: '', confirmed: false },
});
const send = (op: ReturnType<typeof intent>, key = secret, request = device) => recordCheckoutOperation(db, request, { intent: op, grantSecret: key });
beforeEach(async () => {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-sarisupply-rules/databases/(default)/documents`, { method: 'DELETE' });
  time = new Date().toISOString();
  await db.doc('merchants/m').set({ status: 'active' });
  await db.doc(`${root}`).set({ merchantId: 'm', status: 'active' });
  await db.doc('merchants/m/devices/d').set({ merchantId: 'm', branchId: 'b', authUid: 'device:d', status: 'active' });
  await db.doc('merchants/m/cashiers/c').set({ merchantId: 'm', status: 'active', assignedBranchIds: ['b'], mustChangePin: false });
  await db.doc('merchants/m/cashierCredentials/c').set({ credentialVersion: 1 });
  await db.doc('merchants/m/cashierGrants/g').set({ scope, secretHash: hashGrantSecret(secret), issuedAt: time, expiresAt: new Date(Date.parse(time) + 7*86400000).toISOString() });
  for (let n = 1; n <= 5; n++) {
    const product = { id: `p${n}`, sku: `SKU${n}`, name: `Product ${n}`, baseUnit: 'piece', active: true, revision: 1,
      units: [{ name: 'piece', factor: 1, priceCentavos: 100, barcode: '' }, { name: 'pack', factor: 6, priceCentavos: 500, barcode: `00${n}` }] };
    await db.doc(`merchants/m/products/p${n}`).set(product);
    await db.doc(`merchants/m/catalogChanges/${String(n).padStart(10,'0')}`).set({ sequence: n, product });
  }
});
afterAll(() => deleteApp(app));
it('atomically accepts five products with one event; exact replay has no effects', async () => {
  expect(await send(opening())).toMatchObject({ status: 'accepted', operationId: 'shift' });
  expect(await send(sale())).toMatchObject({ status: 'accepted', sequence: 1 });
  expect(await send(sale())).toMatchObject({ status: 'duplicate', sequence: 1 });
  const event = (await db.doc(`${root}/stockChanges/0000000001`).get()).data()!;
  expect(event.kind).toBe('sale'); expect(event.positions).toHaveLength(5);
  expect(event.positions[0]).toMatchObject({ productId: 'p1', delta: -6, quantity: -6, revision: 1 });
  expect((await db.doc(`${root}/stock/p5`).get()).data()).toEqual({ quantity: -6, revision: 1 });
  expect((await db.doc(`${root}/checkoutShifts/shift`).get()).get('expectedCashCentavos')).toBe(3500);
  expect((await db.collection(`${root}/checkoutOperations`).get()).size).toBe(2);
  const date = new Date(Date.parse(time)+8*3600000).toISOString().slice(0,10);
  const report = (await db.doc(`${root}/dailyReports/${date}`).get()).data()!;
  expect(report).toMatchObject({grossSalesCentavos:2500, transactionCount:1,
    openingFloatCentavos:1000, tenders:{cashCentavos:2500}});
  const changed = sale(); changed.payload = { ...changed.payload, merchantName: 'Another' };
  expect(await send(changed)).toMatchObject({ status: 'blocked' });
  expect((await db.doc(`${root}/inventoryMeta/stock`).get()).get('sequence')).toBe(1);
});
it('QR leaves cash unchanged; cash movements and discrepancy close enforce ordinal', async () => {
  await send(opening());
  const qr = sale(); qr.payload.tender = { kind: 'qr', receivedCentavos: 0, reference: 'bank-ref', confirmed: true };
  await send(qr);
  await send(intent('in', 'cashIn', 3, { amountCentavos: 200, reason: 'Added float' }));
  await send(intent('out', 'cashOut', 4, { amountCentavos: 100, reason: 'Supplier' }));
  const bad = await send(intent('bad-close', 'closeShift', 5, { countedCentavos: 1000, reason: '' }));
  expect(bad.status).toBe('blocked');
  expect(await send(intent('close', 'closeShift', 5, { countedCentavos: 1000, reason: 'Short' }))).toMatchObject({ status: 'accepted' });
  const shift = (await db.doc(`${root}/checkoutShifts/shift`).get()).data()!;
  expect(shift).toMatchObject({ open: false, expectedCashCentavos: 1100, countedCentavos: 1000, varianceCentavos: -100 });
  expect(await send(sale('late', 6))).toMatchObject({ status: 'blocked' });
});
it('historical valid prices accepted while spoofed quotes have no stock effects', async () => {
  await send(opening());
  await db.doc('merchants/m/products/p1').update({ active: false, revision: 2 });
  expect(await send(sale())).toMatchObject({ status: 'accepted' });
  const changed = sale('spoof', 3); changed.payload.lines = [{ ...line(), priceCentavos: 1 }];
  expect(await send(changed)).toMatchObject({ status: 'blocked' });
  expect((await db.doc(`${root}/stock/p1`).get()).get('quantity')).toBe(-6);
});
it('replay still denies revoked/version-changed/foreign authority and forged secret', async () => {
  await send(opening()); await send(sale());
  await expect(send(sale(), 'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB')).rejects.toMatchObject({ code: 'permission-denied' });
  for (const key of ['merchantId','branchId','deviceId','cashierId','grantId']) {
    const op = sale(); op.scope = { ...scope, [key]: 'foreign' };
    await expect(send(op)).rejects.toMatchObject({ code: 'permission-denied' });
  }
  await db.doc('merchants/m/cashierCredentials/c').update({ credentialVersion: 2 });
  await expect(send(sale())).rejects.toMatchObject({ code: 'permission-denied' });
  await db.doc('merchants/m/cashierCredentials/c').update({ credentialVersion: 1 });
  await db.doc('merchants/m/devices/d').update({ status: 'revoked' });
  await expect(send(sale())).rejects.toMatchObject({ code: 'permission-denied' });
});
it('two devices sell concurrently without lost stock updates', async () => {
  await send(opening());
  const binding = { ...scope, deviceId: 'd2', grantId: 'g2' };
  const request = { auth: { uid: 'device:d2', token: { ...device.auth.token, deviceId: 'd2' } } };
  await db.doc('merchants/m/devices/d2').set({ merchantId: 'm', branchId: 'b', authUid: 'device:d2', status: 'active' });
  await db.doc('merchants/m/cashierGrants/g2').set({ ...(await db.doc('merchants/m/cashierGrants/g').get()).data(), scope: binding });
  await send(intent('s2','openShift',1,{floatCentavos:0},binding,'s2'),secret,request);
  const other = sale('sale2'); other.scope = binding; other.shiftId = 's2';
  const results = await Promise.all([send(sale()), send(other,secret,request)]);
  expect(results.map(r => r.status)).toEqual(['accepted','accepted']);
  expect((await db.doc(`${root}/stock/p1`).get()).data()).toEqual({ quantity: -12, revision: 2 });
  expect((await db.collection(`${root}/stockChanges`).get()).size).toBe(2);
});
it('expired grant reconciles only intents created inside original window', async () => {
  const issuedAt = new Date(Date.now() - 9*86400000).toISOString();
  const expiresAt = new Date(Date.now() - 2*86400000).toISOString();
  await db.doc('merchants/m/cashierGrants/g').update({ issuedAt, expiresAt });
  time = issuedAt; expect(await send(opening())).toMatchObject({ status: 'accepted' });
  time = new Date().toISOString(); await expect(send(sale())).rejects.toMatchObject({ code: 'permission-denied' });
  time = issuedAt; expect(await send(sale())).toMatchObject({ status: 'accepted' });
});
it('resolves exact indexed quotes, denies missing/duplicate or oversized requests', async () => {
  const request = { merchantId: 'm', branchId: 'b', products: [{ productId: 'p1', revision: 1 }] };
  const result = await resolveCatalogQuotes(db, device, request);
  expect(result.changes).toHaveLength(1); expect(result.changes[0].sequence).toBe(1);
  await expect(resolveCatalogQuotes(db, device, { ...request, branchId: 'foreign' })).rejects.toMatchObject({ code: 'permission-denied' });
  await expect(resolveCatalogQuotes(db, device, { ...request, products: [{ productId: 'p1', revision: 9 }] })).rejects.toMatchObject({ code: 'failed-precondition' });
  await expect(resolveCatalogQuotes(db, device, { ...request, products: Array(21).fill(request.products[0]) })).rejects.toMatchObject({ code: 'invalid-argument' });
  await db.doc('merchants/m/catalogChanges/0000000006').set((await db.doc('merchants/m/catalogChanges/0000000001').get()).data()!);
  await expect(resolveCatalogQuotes(db, device, request)).rejects.toMatchObject({ code: 'failed-precondition' });
});

it('rejects unknown payload fields before recording even a blocked operation', async () => {
  await send(opening());
  const malformed=intent('malformed','cashIn',99,{amountCentavos:1,reason:'Float',secret});
  await expect(send(malformed)).rejects.toMatchObject({code:'invalid-argument'});
  expect((await db.doc(`${root}/checkoutOperations/malformed`).get()).exists).toBe(false);
});

it('measures transactional reads and writes for the five-product fixture', async () => {
  const counts={attempts:0,reads:0,writes:0};
  const measured=new Proxy(db,{get(target,prop) {
    if(prop==='runTransaction') return (callback:any)=>target.runTransaction(async tx=> {
      counts.attempts++;
      const metered=new Proxy(tx,{get(transaction,method) {
        const value=Reflect.get(transaction,method);
        if(method==='get') return async (...args:any[])=> {
          const snapshot=await (value as Function).apply(transaction,args);
          counts.reads+=snapshot.docs?Math.max(1,snapshot.size):1;return snapshot;
        };
        if(['set','create','update','delete'].includes(String(method))) return (...args:any[])=> {
          counts.writes++;return (value as Function).apply(transaction,args);
        };
        return typeof value==='function'?value.bind(transaction):value;
      }});
      return callback(metered);
    });
    const value=Reflect.get(target,prop);return typeof value==='function'?value.bind(target):value;
  }});
  const run=async (op:ReturnType<typeof intent>)=> {
    counts.attempts=counts.reads=counts.writes=0;
    await recordCheckoutOperation(measured,device,{intent:op,grantSecret:secret});return {...counts};
  };
  const openingCost=await run(opening()),saleCost=await run(sale()),replayCost=await run(sale());
  expect(openingCost).toEqual({attempts:1,reads:10,writes:4});
  expect(saleCost).toEqual({attempts:1,reads:21,writes:10});
  expect(replayCost).toEqual({attempts:1,reads:7,writes:0});
  const cashInCost=await run(intent('in','cashIn',3,{amountCentavos:100,reason:'Float'}));
  const cashOutCost=await run(intent('out','cashOut',4,{amountCentavos:100,reason:'Supplier'}));
  const closeCost=await run(intent('close','closeShift',5,{countedCentavos:3500,reason:''}));
  expect(cashInCost).toEqual({attempts:1,reads:10,writes:3});
  expect(cashOutCost).toEqual({attempts:1,reads:10,writes:3});
  expect(closeCost).toEqual({attempts:1,reads:10,writes:4});
  counts.attempts=counts.reads=counts.writes=0;
  await resolveCatalogQuotes(measured,device,{merchantId:'m',branchId:'b',products:[1,2,3,4,5].map(n=>({productId:`p${n}`,revision:1}))});
  const quoteCost={...counts};
  expect(quoteCost).toEqual({attempts:1,reads:8,writes:0});
  const envelope=(await db.doc(`${root}/checkoutOperations/sale`).get()).data();
  const event=(await db.doc(`${root}/stockChanges/0000000001`).get()).data();
  console.log(JSON.stringify({fixture:'five-product-checkout',openingCost,saleCost,replayCost,cashInCost,cashOutCost,closeCost,quoteCost,
    envelopeJsonBytes:Buffer.byteLength(JSON.stringify(envelope)),eventJsonBytes:Buffer.byteLength(JSON.stringify(event))}));
});

it('server allowance settles credit once and repayment preserves the next ordinal', async () => {
  await send(opening());
  await db.doc('merchants/m/customers/customer').set({active:true,balanceCentavos:1000,creditLimitCentavos:5000,reservedCentavos:500});
  await db.doc('merchants/m/creditAllowances/credit-sale').set({customerId:'customer',deviceId:'d',branchId:'b',issuedAt:time,
    expiresAt:new Date(Date.parse(time)+86400000).toISOString(),allowedCreditCentavos:500,usedCreditCentavos:0});
  const credit = sale('credit-sale',2,[line()]);
  credit.payload.tender = {kind:'credit',receivedCentavos:0,reference:'customer',confirmed:true,creditGrantId:'credit-sale'};
  expect(await send(credit)).toMatchObject({status:'accepted'});
  expect(await send(credit)).toMatchObject({status:'duplicate'});
  expect((await db.doc('merchants/m/customers/customer').get()).data()).toMatchObject({balanceCentavos:1500,reservedCentavos:0});
  const repayment = intent('repayment','debtRepayment',3,{customerId:'customer',amountCentavos:300,tenderKind:'cash',reference:'',notes:''});
  expect(await send(repayment)).toMatchObject({status:'accepted'});
  expect(await send(repayment)).toMatchObject({status:'duplicate'});
  expect((await db.doc('merchants/m/customers/customer').get()).get('balanceCentavos')).toBe(1200);
  expect(await send(sale('after-repayment',4,[line()]))).toMatchObject({status:'accepted'});
  expect((await db.doc(`${root}/checkoutShifts/shift`).get()).get('expectedCashCentavos')).toBe(1800);
});

it('lost reservation response retries once; cancellation releases once and blocks delayed reserve', async () => {
  await db.doc('merchants/m/customers/customer').set({active:true,name:'Rosa',balanceCentavos:0,creditLimitCentavos:1000,reservedCentavos:0});
  const request = {merchantId:'m',action:'reserve',scope,grantSecret:secret,customerId:'customer',amountCentavos:500,operationId:'reserve'};
  expect(await manageCustomers(db,device,request)).toMatchObject({grant:{allowedCreditCentavos:500}});
  await manageCustomers(db,device,request);
  expect((await db.doc('merchants/m/customers/customer').get()).get('reservedCentavos')).toBe(500);
  const cancel = {...request,action:'cancelReservation'};
  await manageCustomers(db,device,cancel);
  await manageCustomers(db,device,cancel);
  expect((await db.doc('merchants/m/customers/customer').get()).get('reservedCentavos')).toBe(0);
  await expect(manageCustomers(db,device,request)).rejects.toMatchObject({code:'failed-precondition'});
  await manageCustomers(db,device,{...cancel,operationId:'before-reserve'});
  await expect(manageCustomers(db,device,{...request,operationId:'before-reserve'})).rejects.toMatchObject({code:'failed-precondition'});
});
