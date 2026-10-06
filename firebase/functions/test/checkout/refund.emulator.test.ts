import { initializeApp, deleteApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { beforeEach, afterAll, describe, expect, it } from 'vitest';
import { hashGrantSecret } from '../../src/checkout/cashier-grants';
import { recordCheckoutOperation, approveCheckoutReversal } from '../../src/checkout/checkout-service';

const app = initializeApp({ projectId: 'demo-sarisupply-rules' }, 'refund-operations');
const db = getFirestore(app);
const root = 'merchants/m_ref/branches/b_ref';
const device = { auth: { uid: 'device:d_ref', token: { principalType: 'device', merchantId: 'm_ref', deviceId: 'd_ref' } } };
const scope = { merchantId: 'm_ref', branchId: 'b_ref', deviceId: 'd_ref', cashierId: 'c_ref', grantId: 'g_ref', credentialVersion: 1 };
const secret = 'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
let time: string;

const productLine = {
  productId: 'p_ref',
  sku: 'TEA',
  name: 'Iced Tea',
  unit: 'piece',
  factor: 1,
  priceCentavos: 1000,
  quantity: 5,
  catalogSequence: 1,
  catalogRevision: 1,
};

function intent(id: string, kind: string, ordinal: number, payload: Record<string, unknown>, shiftId = 'shift_ref') {
  return { id, kind, ordinal, payload, scope, shiftId, occurredAt: time };
}

const owner = {auth:{uid:'refund-owner',token:{}}};
const send = async (op: ReturnType<typeof intent>) => {
  if (['refund','voidSale'].includes(op.kind)) await approveCheckoutReversal(db,owner,{intent:op});
  return recordCheckoutOperation(db, device, { intent: op, grantSecret: secret });
};

beforeEach(async () => {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/demo-sarisupply-rules/databases/(default)/documents`, { method: 'DELETE' });
  time = new Date().toISOString();
  await db.doc('merchants/m_ref').set({ status: 'active' });
  await db.doc('merchants/m_ref/memberships/refund-owner').set({userId:'refund-owner',merchantId:'m_ref',status:'active',role:'owner',allBranches:true,branchIds:[]});
  await db.doc(root).set({ merchantId: 'm_ref', status: 'active' });
  await db.doc('merchants/m_ref/devices/d_ref').set({ merchantId: 'm_ref', branchId: 'b_ref', authUid: 'device:d_ref', status: 'active' });
  await db.doc('merchants/m_ref/cashiers/c_ref').set({ merchantId: 'm_ref', status: 'active', assignedBranchIds: ['b_ref'], mustChangePin: false });
  await db.doc('merchants/m_ref/cashierCredentials/c_ref').set({ credentialVersion: 1 });
  await db.doc('merchants/m_ref/cashierGrants/g_ref').set({
    scope,
    secretHash: hashGrantSecret(secret),
    issuedAt: time,
    expiresAt: new Date(Date.parse(time) + 7 * 86400000).toISOString(),
  });

  const p = {
    id: 'p_ref',
    sku: 'TEA',
    name: 'Iced Tea',
    baseUnit: 'piece',
    active: true,
    revision: 1,
    units: [{ name: 'piece', factor: 1, priceCentavos: 1000, barcode: '099' }],
  };
  await db.doc('merchants/m_ref/products/p_ref').set(p);
  await db.doc('merchants/m_ref/catalogChanges/0000000001').set({ sequence: 1, product: p });
  await db.doc(`${root}/stock/p_ref`).set({ quantity: 20, revision: 1 });
});

afterAll(() => deleteApp(app));

describe('refund and void cloud reconciliation', () => {
  it('cashier cannot approve; missing, changed, or revoked Owner approval cannot reverse stock', async () => {
    await send(intent('shift_ref','openShift',1,{floatCentavos:1000}));
    await send(intent('sale_1','sale',2,{merchantName:'Store',branchName:'Main',lines:[productLine],tender:{kind:'cash',receivedCentavos:5000,reference:'',confirmed:false}}));
    const reversal = intent('owner-approved','voidSale',3,{originalSaleId:'sale_1',voidCentavos:5000,tenderKind:'cash',reason:'Cancel',authorizedByCashierId:'c_ref'});
    await expect(approveCheckoutReversal(db,device,{intent:reversal})).rejects.toMatchObject({code:'unauthenticated'});
    expect(await recordCheckoutOperation(db,device,{intent:reversal,grantSecret:secret})).toMatchObject({status:'blocked'});
    await approveCheckoutReversal(db,owner,{intent:reversal});
    expect(await recordCheckoutOperation(db,device,{intent:{...reversal,payload:{...reversal.payload,reason:'Changed'}},grantSecret:secret})).toMatchObject({status:'blocked'});
    await db.doc('merchants/m_ref/memberships/refund-owner').update({status:'removed'});
    await expect(recordCheckoutOperation(db,device,{intent:reversal,grantSecret:secret})).rejects.toMatchObject({code:'permission-denied'});
    expect((await db.doc(`${root}/stock/p_ref`).get()).get('quantity')).toBe(15);
  });
  it.each(['refund', 'voidSale'])('credit %s reverses debt once without replenishing allowance', async kind => {
    await send(intent('shift_ref', 'openShift', 1, { floatCentavos: 5000 }));
    await db.doc('merchants/m_ref/customers/customer').set({active:true, balanceCentavos:0, reservedCentavos:5000, creditLimitCentavos:10000});
    await db.doc('merchants/m_ref/creditAllowances/reservation').set({customerId:'customer',deviceId:'d_ref',branchId:'b_ref',
      issuedAt:time,expiresAt:new Date(Date.parse(time)+86400000).toISOString(),allowedCreditCentavos:5000,usedCreditCentavos:0});
    expect((await send(intent('sale_credit', 'sale', 2, { merchantName:'Store',branchName:'Main',lines:[productLine],
      tender:{kind:'credit',reference:'customer',creditGrantId:'reservation',receivedCentavos:0,confirmed:true} }))).status).toBe('accepted');
    const payload = {originalSaleId:'sale_credit',tenderKind:'credit',reason:'Return',authorizedByCashierId:'c_ref',
      ...(kind === 'refund' ? {lines:[{...productLine,refundCentavos:5000}],totalRefundCentavos:5000} : {voidCentavos:5000})};
    const reverse = intent('credit_reverse', kind, 3, payload);
    expect((await send(reverse)).status).toBe('accepted');
    expect((await send(reverse)).status).toBe('duplicate');
    expect((await db.doc('merchants/m_ref/customers/customer').get()).get('balanceCentavos')).toBe(0);
    expect((await db.doc('merchants/m_ref/creditAllowances/reservation').get()).get('usedCreditCentavos')).toBe(5000);
    expect((await db.doc(`${root}/checkoutShifts/shift_ref`).get()).get('expectedCashCentavos')).toBe(5000);
    expect((await db.doc(`${root}/stock/p_ref`).get()).get('quantity')).toBe(20);
  });
  it.each([
    ['factor', { factor: 2 }], ['price', { priceCentavos: 1200 }],
    ['tender', { tenderKind: 'qr' }], ['repeated', { repeated: true }],
    ['voidAmount', { voidCentavos: 4000 }], ['voidTender', { voidCentavos: 5000, tenderKind: 'qr' }],
  ])('blocks forged %s without changing stock or cash', async (_label, changes) => {
    await send(intent('shift_ref', 'openShift', 1, { floatCentavos: 5000 }));
    await send(intent('sale_original', 'sale', 2, { merchantName: 'Store', branchName: 'Main',
      lines: [productLine], tender: { kind: 'cash', receivedCentavos: 5000, reference: '', confirmed: false } }));
    const line = { ...productLine, quantity: 3, refundCentavos: 1000, ...changes };
    const payload = { originalSaleId: 'sale_original', lines: changes.repeated ? [line, line] : [line],
      totalRefundCentavos: changes.repeated ? 2000 : 1000, tenderKind: 'cash',
      reason: 'Return', authorizedByCashierId: 'c_ref', ...changes };
    const result = await send(intent('forged', 'voidCentavos' in changes ? 'voidSale' : 'refund', 3, payload));
    expect(result.status).toBe('blocked');
    expect((await db.doc(`${root}/stock/p_ref`).get()).get('quantity')).toBe(15);
    expect((await db.doc(`${root}/checkoutShifts/shift_ref`).get()).get('expectedCashCentavos')).toBe(10000);
  });
  it('refunds items within purchased quantity, restores stock, and adjusts cash', async () => {
    // 1. Open shift
    await send(intent('shift_ref', 'openShift', 1, { floatCentavos: 5000 }));

    // 2. Make sale: 5 pieces for 5,000 cash
    const saleIntent = intent('sale_1', 'sale', 2, {
      merchantName: 'Store',
      branchName: 'Main',
      lines: [productLine],
      tender: { kind: 'cash', receivedCentavos: 5000, reference: '', confirmed: false },
    });
    const saleRes = await send(saleIntent);
    expect(saleRes).toMatchObject({ status: 'accepted', sequence: 1 });

    // Stock was 20, sold 5 -> 15
    const stockAfterSale = await db.doc(`${root}/stock/p_ref`).get();
    expect(stockAfterSale.get('quantity')).toBe(15);

    // 3. Refund 2 pieces for 2,000 cash
    const refundIntent = intent('ref_1', 'refund', 3, {
      id: 'ref_1',
      originalSaleId: 'sale_1',
      scope,
      shiftId: 'shift_ref',
      ordinal: 3,
      occurredAt: time,
      lines: [
        {
          productId: 'p_ref',
          sku: 'TEA',
          name: 'Iced Tea',
          unit: 'piece',
          factor: 1,
          priceCentavos: 1000,
          quantity: 2,
          refundCentavos: 2000,
        },
      ],
      tenderKind: 'cash',
      reason: 'Wrong item bought',
      authorizedByCashierId: 'c_ref',
      totalRefundCentavos: 2000,
    });

    const refRes = await send(refundIntent);
    expect(refRes).toMatchObject({ status: 'accepted', sequence: 2 });

    // Stock restored by 2 -> 17
    const stockAfterRefund = await db.doc(`${root}/stock/p_ref`).get();
    expect(stockAfterRefund.get('quantity')).toBe(17);

    // Shift cash: 5000 float + 5000 sale - 2000 refund = 8000
    const shiftDoc = await db.doc(`${root}/checkoutShifts/shift_ref`).get();
    expect(shiftDoc.get('expectedCashCentavos')).toBe(8000);

    // Feed event produced with kind 'refund'
    const feedEvent = (await db.doc(`${root}/stockChanges/0000000002`).get()).data()!;
    expect(feedEvent.kind).toBe('refund');
    expect(feedEvent.positions[0]).toMatchObject({ productId: 'p_ref', delta: 2, quantity: 17 });

    // 4. Over-refund rejected (already refunded 2, trying to refund 4 more -> 6 > 5)
    const overRefund = intent('ref_over', 'refund', 4, {
      id: 'ref_over',
      originalSaleId: 'sale_1',
      scope,
      shiftId: 'shift_ref',
      ordinal: 4,
      occurredAt: time,
      lines: [
        {
          productId: 'p_ref',
          sku: 'TEA',
          name: 'Iced Tea',
          unit: 'piece',
          factor: 1,
          priceCentavos: 1000,
          quantity: 4,
          refundCentavos: 4000,
        },
      ],
      tenderKind: 'cash',
      reason: 'Return',
      authorizedByCashierId: 'c_ref',
      totalRefundCentavos: 4000,
    });
    const overRes = await send(overRefund);
    expect(overRes.status).toBe('blocked');
  });

  it('voidSale cancels entire sale, restores all items, and blocks subsequent refunds', async () => {
    await send(intent('shift_ref', 'openShift', 1, { floatCentavos: 2000 }));
    await send(
      intent('sale_to_void', 'sale', 2, {
        merchantName: 'Store',
        branchName: 'Main',
        lines: [productLine],
        tender: { kind: 'cash', receivedCentavos: 5000, reference: '', confirmed: false },
      }),
    );

    // Void the sale
    const voidOp = intent('void_1', 'voidSale', 3, {
      id: 'void_1',
      originalSaleId: 'sale_to_void',
      scope,
      shiftId: 'shift_ref',
      ordinal: 3,
      occurredAt: time,
      reason: 'Customer cancelled right after paying',
      authorizedByCashierId: 'c_ref',
      voidCentavos: 5000,
      tenderKind: 'cash',
    });

    const voidRes = await send(voidOp);
    expect(voidRes).toMatchObject({ status: 'accepted', sequence: 2 });

    // Stock restored to 20
    const stockAfterVoid = await db.doc(`${root}/stock/p_ref`).get();
    expect(stockAfterVoid.get('quantity')).toBe(20);

    // Drawer cash reverted to 2000 float
    const shiftDoc = await db.doc(`${root}/checkoutShifts/shift_ref`).get();
    expect(shiftDoc.get('expectedCashCentavos')).toBe(2000);

    // Cannot refund a voided sale
    const refundAfterVoid = intent('ref_voided', 'refund', 4, {
      id: 'ref_voided',
      originalSaleId: 'sale_to_void',
      scope,
      shiftId: 'shift_ref',
      ordinal: 4,
      occurredAt: time,
      lines: [
        {
          productId: 'p_ref',
          sku: 'TEA',
          name: 'Iced Tea',
          unit: 'piece',
          factor: 1,
          priceCentavos: 1000,
          quantity: 1,
          refundCentavos: 1000,
        },
      ],
      tenderKind: 'cash',
      reason: 'Return',
      authorizedByCashierId: 'c_ref',
      totalRefundCentavos: 1000,
    });
    const blockedRes = await send(refundAfterVoid);
    expect(blockedRes.status).toBe('blocked');
  });
});
