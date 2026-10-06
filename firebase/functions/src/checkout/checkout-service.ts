import { createHash } from 'node:crypto';
import { Firestore, FieldValue, Transaction } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { AuthRequest, AuthorizationService, requireHuman } from '../common/authz';
import { requireCashierGrant } from './cashier-grants';
import { Input, Intent, canonical, id, integer, object, keys, parseIntent, parseSale, text, parseRefund, parseVoid } from './checkout-validation';
const key = (n: number) => String(n).padStart(10,'0');
type Result = { operationId: string; status: string; sequence?: number; message?: string };
const authz = (db: Firestore, tx: Transaction) => new AuthorizationService(async path => (await tx.get(db.doc(path))).data() ?? null);
export async function resolveCatalogQuotes(db: Firestore, request: AuthRequest, input: Input) {
  const merchantId = id(input.merchantId), branchId = id(input.branchId);
  if (!Array.isArray(input.products) || !input.products.length || input.products.length > 20) throw new HttpsError('invalid-argument','Select at most twenty products');
  const pairs = input.products.map(raw => { const p=object(raw); return {productId:id(p.productId),revision:integer(p.revision,1)}; });
  if (new Set(pairs.map(p=>p.productId)).size !== pairs.length) throw new HttpsError('invalid-argument','Repeated product quote');
  return db.runTransaction(async tx => {
    const device = await authz(db,tx).requireActiveDevice(request);
    if (device.merchantId !== merchantId || device.branchId !== branchId) throw new HttpsError('permission-denied','Device scope mismatch');
    const changes = [];
    for (const pair of pairs) {
      const found = await tx.get(db.collection(`merchants/${merchantId}/catalogChanges`)
        .where('product.id','==',pair.productId).where('product.revision','==',pair.revision).limit(2));
      if (found.size !== 1) throw new HttpsError('failed-precondition','Refresh catalog before checkout');
      const event = found.docs[0].data();
      if (found.docs[0].id !== key(integer(event.sequence,1))) throw new HttpsError('failed-precondition','Catalog history needs review');
      changes.push(event);
    }
    return {changes};
  });
}
export async function approveCheckoutReversal(db: Firestore, request: AuthRequest, input: Input) {
  const intent = parseIntent(input.intent), scope = intent.scope;
  if (!['refund','voidSale'].includes(intent.kind)) throw new HttpsError('invalid-argument','Select a refund or void');
  const ownerId = requireHuman(request);
  const root = `merchants/${scope.merchantId}/branches/${scope.branchId}`;
  const fingerprint = createHash('sha256').update(canonical(intent)).digest('hex');
  return db.runTransaction(async tx => {
    await authz(db,tx).requireOwner(ownerId,scope.merchantId);
    await authz(db,tx).requireBranchAccess(ownerId,scope.merchantId,scope.branchId);
    const original = await tx.get(db.doc(`${root}/checkoutOperations/${id(intent.payload.originalSaleId)}`));
    if (original.get('result')?.status !== 'accepted' || original.get('intent')?.kind !== 'sale') {
      throw new HttpsError('failed-precondition','Sync the original receipt before Owner approval');
    }
    const ref = db.doc(`${root}/checkoutApprovals/${intent.id}`), previous = await tx.get(ref);
    if (previous.exists) {
      if (previous.get('fingerprint') !== fingerprint) throw new HttpsError('already-exists','Approved reversal changed');
      return {status:'approved',operationId:intent.id};
    }
    tx.create(ref,{fingerprint,ownerId,kind:intent.kind,originalSaleId:intent.payload.originalSaleId,
      intent,approvedAt:FieldValue.serverTimestamp()});
    return {status:'approved',operationId:intent.id};
  });
}

export async function recordCheckoutOperation(db: Firestore, request: AuthRequest, input: Input): Promise<Result> {
  const intent = parseIntent(input.intent), scope = intent.scope;
  const hash = createHash('sha256').update(canonical(intent)).digest('hex');
  const root = `merchants/${scope.merchantId}/branches/${scope.branchId}`;
  return db.runTransaction(async tx => {
    await requireCashierGrant(db,tx,request,scope,input.grantSecret,intent.occurredAt);
    const operationRef=db.doc(`${root}/checkoutOperations/${intent.id}`);
    const replay = await tx.get(operationRef);
    if (replay.exists) {
      if (replay.get('fingerprint') !== hash) return {operationId:intent.id,status:'blocked',message:'Receipt ID has another payment'};
      const result = replay.get('result') as Result;
      return {...result,status:result.status==='accepted'?'duplicate':result.status};
    }
    if (['refund','voidSale'].includes(intent.kind)) {
      const approval = await tx.get(db.doc(`${root}/checkoutApprovals/${intent.id}`));
      if (!approval.exists || approval.get('fingerprint') !== hash) {
        // No immutable blocked receipt yet: obtain approval then retry this same ID.
        return {operationId:intent.id,status:'blocked',message:'Owner approval required for this exact refund or void'};
      }
      await authz(db,tx).requireOwner(id(approval.get('ownerId')),scope.merchantId);
    }
    const shiftRef=db.doc(`${root}/checkoutShifts/${intent.shiftId}`);
    const deviceRef=db.doc(`${root}/checkoutDevices/${scope.deviceId}`);
    const [shiftSnap,deviceSnap] = await Promise.all([tx.get(shiftRef),tx.get(deviceRef)]);
    const shift = shiftSnap.data();
    let result: Result = {operationId:intent.id,status:'accepted'};
    let projection: Input | undefined, close=false;
    let stockWrites: {productId:string;quantity:number;revision:number;delta:number}[] = [];
    let sequence: number | undefined;
    let finance: Input = {};
    const extraWrites: (() => void)[] = [];
    const reverseCredit = async (original: Input, amount: number) => {
      const tender = object(object(original.payload).tender);
      if (tender.kind !== 'credit') return;
      const customerRef = db.doc(`merchants/${scope.merchantId}/customers/${id(tender.reference)}`);
      const customer = await tx.get(customerRef);
      if (!customer.exists || integer(customer.get('balanceCentavos')) < amount) {
        throw new HttpsError('failed-precondition', 'Credit was repaid or changed; Owner review required');
      }
      extraWrites.push(() => tx.update(customerRef, { balanceCentavos: integer(customer.get('balanceCentavos')) - amount }));
      // Do not replenish a consumed allowance when reversing debt.
    };
    const blocked = (message:string) => { result = {operationId:intent.id,status:'blocked',message}; };
    // Every read completes before the immutable envelope or any projection writes.
    if (intent.kind === 'openShift') {
      keys(intent.payload,['floatCentavos']);
      const float = integer(intent.payload.floatCentavos);
      if (intent.id !== intent.shiftId || intent.ordinal !== 1 || shiftSnap.exists || deviceSnap.get('activeShift')) blocked('Close the current shift first');
      else projection = {scope,open:true,lastOrdinal:1,expectedCashCentavos:float,floatCentavos:float,cashSalesCentavos:0,cashInCentavos:0,cashOutCentavos:0,cashRefundCentavos:0};
    } else if (!shift || shift.open !== true || deviceSnap.get('activeShift') !== intent.shiftId ||
        shift.scope.deviceId !== scope.deviceId || shift.scope.cashierId !== scope.cashierId || intent.ordinal !== shift.lastOrdinal+1) {
      blocked('Resolve earlier shift operations first');
    } else {
      projection = {...shift,lastOrdinal:intent.ordinal};
      try {
        if (intent.kind === 'sale') {
          const sale = parseSale(intent.payload);
          const snapshots = new Map<string,Input>();
          for (const [pid,line] of sale.products) {
            const event = await tx.get(db.doc(`merchants/${scope.merchantId}/catalogChanges/${key(line.catalogSequence)}`));
            const product = event.get('product');
            if (event.get('sequence') !== line.catalogSequence || !product || product.id !== pid || product.revision !== line.catalogRevision ||
                product.active !== true || product.sku !== line.sku || product.name !== line.name) throw new HttpsError('failed-precondition','Receipt prices need review');
            snapshots.set(pid,product);
          }
          for (const line of sale.lines) {
            const product = snapshots.get(line.productId)!;
            const unit = (product.units as Input[]).find(u=>u.name===line.unit);
            if (!unit || unit.factor !== line.factor || unit.priceCentavos !== line.priceCentavos) throw new HttpsError('failed-precondition','Receipt prices need review');
          }
          for (const [productId,base] of sale.quantities) {
            const current=await tx.get(db.doc(`${root}/stock/${productId}`));
            const quantity=integer(current.get('quantity')??0,-1e9)-base;
            if (quantity < -1e9) throw new HttpsError('failed-precondition','Stock quantity needs review');
            stockWrites.push({productId,quantity,revision:integer(current.get('revision')??0)+1,delta:-base});
          }
          const meta=await tx.get(db.doc(`${root}/inventoryMeta/stock`));
          sequence=integer(meta.get('sequence')??0)+1;
          const tender = object(intent.payload.tender);
          if (tender.kind === 'credit') {
            const customerRef = db.doc(`merchants/${scope.merchantId}/customers/${id(tender.reference)}`);
            const allowanceRef = db.doc(`merchants/${scope.merchantId}/creditAllowances/${id(tender.creditGrantId)}`);
            const [customer, allowance] = await Promise.all([tx.get(customerRef), tx.get(allowanceRef)]);
            const start = Date.parse(allowance.get('issuedAt')), expiry = Date.parse(allowance.get('expiresAt'));
            if (customer.get('active') !== true || allowance.get('status') === 'cancelled' || allowance.get('customerId') !== tender.reference ||
                allowance.get('deviceId') !== scope.deviceId || allowance.get('branchId') !== scope.branchId ||
                !Number.isFinite(start) || !Number.isFinite(expiry) || Date.parse(intent.occurredAt) < start || Date.parse(intent.occurredAt) >= expiry ||
                integer(allowance.get('usedCreditCentavos')) + sale.total > integer(allowance.get('allowedCreditCentavos'))) {
              throw new HttpsError('failed-precondition','Credit allowance is unavailable');
            }
            const balance = integer(customer.get('balanceCentavos')) + sale.total;
            const reserved = integer(customer.get('reservedCentavos')) - sale.total;
            if (reserved < 0 || balance > integer(customer.get('creditLimitCentavos'))) throw new HttpsError('failed-precondition','Credit limit exceeded');
            extraWrites.push(() => {
              tx.update(customerRef,{balanceCentavos:balance,reservedCentavos:reserved});
              tx.update(allowanceRef,{usedCreditCentavos:integer(allowance.get('usedCreditCentavos'))+sale.total});
            });
          }
          projection.cashSalesCentavos=integer(shift.cashSalesCentavos,0,Number.MAX_SAFE_INTEGER)+sale.netCash;
          projection.expectedCashCentavos=integer(shift.expectedCashCentavos,-Number.MAX_SAFE_INTEGER,Number.MAX_SAFE_INTEGER)+sale.netCash;
          finance={totalCentavos:sale.total,changeCentavos:sale.change,baseQuantities:Object.fromEntries(sale.quantities)};
        } else if (intent.kind === 'refund') {
          const refund = parseRefund(intent.payload);
          if (refund.authorizedByCashierId !== scope.cashierId) throw new HttpsError('failed-precondition','Refund authorizer must match cashier');
          const originalOpRef = db.doc(`${root}/checkoutOperations/${refund.originalSaleId}`);
          const originalOpSnap = await tx.get(originalOpRef);
          if (!originalOpSnap.exists || originalOpSnap.get('result')?.status !== 'accepted' || originalOpSnap.get('intent')?.kind !== 'sale') {
            throw new HttpsError('failed-precondition', 'Original sale not found or invalid');
          }
          const voidRef = db.doc(`${root}/checkoutVoids/${refund.originalSaleId}`);
          const voidSnap = await tx.get(voidRef);
          if (voidSnap.exists) {
            throw new HttpsError('failed-precondition', 'Original sale has been voided');
          }
          const summaryRef = db.doc(`${root}/checkoutRefundSummaries/${refund.originalSaleId}`);
          const summarySnap = await tx.get(summaryRef);
          const summary = summarySnap.data() ?? { refundedQuantities: {}, totalRefundCentavos: 0 };
          const originalLines = (originalOpSnap.get('intent')?.payload?.lines as Input[]) ?? [];
          const originalTotal = integer(originalOpSnap.get('totalCentavos') ?? 0);
          const originalTender = originalOpSnap.get('intent')?.payload?.tender?.kind;
          if (refund.tenderKind !== originalTender) throw new HttpsError('failed-precondition', 'Refund tender must match receipt');
          const lineKey = (line: Input) => JSON.stringify([line.productId,line.sku,line.name,line.unit,line.factor,line.priceCentavos]);
          const purchased = new Map<string, number>();
          for (const line of originalLines) {
            const key = lineKey(line);
            purchased.set(key, (purchased.get(key) ?? 0) + integer(line.quantity, 1));
          }
          const returned = { ...(summary.refundedLineQuantities ?? {}) };
          for (const line of refund.lines) {
            const key = lineKey(line);
            returned[key] = integer(returned[key] ?? 0) + line.quantity;
            // Legacy summaries lack unit identities. Conservatively count those returns
            // against each matching unit rather than risk returning stock twice.
            const previous = summary.refundedLineQuantities ? 0 : integer(summary.refundedQuantities?.[line.productId] ?? 0);
            if (!purchased.has(key) || returned[key] + previous > purchased.get(key)!) {
              throw new HttpsError('failed-precondition', 'Refund line exceeds original receipt');
            }
          }
          const legacyReturned = { ...(summary.legacyRefundedQuantities ?? (summary.refundedLineQuantities ? {} : summary.refundedQuantities ?? {})) };
          for (const line of refund.lines) {
            if (returned[lineKey(line)] + integer(legacyReturned[line.productId] ?? 0) > purchased.get(lineKey(line))!) {
              throw new HttpsError('failed-precondition', 'Refund quantity exceeds purchase');
            }
          }
          if (summary.totalRefundCentavos + refund.totalRefundCentavos > originalTotal) {
            throw new HttpsError('failed-precondition', 'Refund total exceeds sale total');
          }
          for (const [productId, base] of refund.quantities) {
            const current = await tx.get(db.doc(`${root}/stock/${productId}`));
            const quantity = integer(current.get('quantity') ?? 0, -1e9) + base;
            if (quantity > 1e9) throw new HttpsError('failed-precondition', 'Stock quantity needs review');
            stockWrites.push({ productId, quantity, revision: integer(current.get('revision') ?? 0) + 1, delta: base });
          }
          const meta = await tx.get(db.doc(`${root}/inventoryMeta/stock`));
          sequence = integer(meta.get('sequence') ?? 0) + 1;
          if (refund.tenderKind === 'cash') {
            projection.expectedCashCentavos = integer(shift.expectedCashCentavos, -Number.MAX_SAFE_INTEGER, Number.MAX_SAFE_INTEGER) - refund.totalRefundCentavos;
            projection.cashRefundCentavos = integer(shift.cashRefundCentavos ?? 0, 0, Number.MAX_SAFE_INTEGER) + refund.totalRefundCentavos;
          }
          const newRefundedQuantities = { ...(summary.refundedQuantities ?? {}) };
          for (const line of refund.lines) {
            newRefundedQuantities[line.productId] = (newRefundedQuantities[line.productId] ?? 0) + line.quantity;
          }
          extraWrites.push(() => {
            tx.set(summaryRef, {
              originalSaleId: refund.originalSaleId,
              refundedQuantities: newRefundedQuantities,
              refundedLineQuantities: returned,
              legacyRefundedQuantities: legacyReturned,
              totalRefundCentavos: summary.totalRefundCentavos + refund.totalRefundCentavos,
              updatedAt: FieldValue.serverTimestamp(),
            });
            tx.create(db.doc(`${root}/checkoutRefunds/${intent.id}`), {
              id: intent.id,
              originalSaleId: refund.originalSaleId,
              scope,
              shiftId: intent.shiftId,
              totalRefundCentavos: refund.totalRefundCentavos,
              lines: refund.lines,
              tenderKind: refund.tenderKind,
              reason: refund.reason,
              authorizedByCashierId: refund.authorizedByCashierId,
              recordedAt: FieldValue.serverTimestamp(),
            });
          });
          await reverseCredit(originalOpSnap.get('intent'), refund.totalRefundCentavos);
          finance = { totalRefundCentavos: refund.totalRefundCentavos, originalSaleId: refund.originalSaleId };
        } else if (intent.kind === 'voidSale') {
          const voidPayload = parseVoid(intent.payload);
          if (voidPayload.authorizedByCashierId !== scope.cashierId) throw new HttpsError('failed-precondition','Void authorizer must match cashier');
          const originalOpRef = db.doc(`${root}/checkoutOperations/${voidPayload.originalSaleId}`);
          const originalOpSnap = await tx.get(originalOpRef);
          if (!originalOpSnap.exists || originalOpSnap.get('result')?.status !== 'accepted' || originalOpSnap.get('intent')?.kind !== 'sale') {
            throw new HttpsError('failed-precondition', 'Original sale not found or invalid');
          }
          const voidRef = db.doc(`${root}/checkoutVoids/${voidPayload.originalSaleId}`);
          const voidSnap = await tx.get(voidRef);
          if (voidSnap.exists) {
            throw new HttpsError('failed-precondition', 'Sale already voided');
          }
          const summaryRef = db.doc(`${root}/checkoutRefundSummaries/${voidPayload.originalSaleId}`);
          const summarySnap = await tx.get(summaryRef);
          if (summarySnap.exists && (summarySnap.get('totalRefundCentavos') ?? 0) > 0) {
            throw new HttpsError('failed-precondition', 'Cannot void partially refunded sale');
          }
          const originalLines = (originalOpSnap.get('intent')?.payload?.lines as Input[]) ?? [];
          if (intent.shiftId !== originalOpSnap.get('intent')?.shiftId ||
              voidPayload.tenderKind !== originalOpSnap.get('intent')?.payload?.tender?.kind ||
              voidPayload.voidCentavos !== integer(originalOpSnap.get('totalCentavos'))) {
            throw new HttpsError('failed-precondition', 'Void must reverse original tender and total');
          }
          const quantities = new Map<string, number>();
          for (const raw of originalLines) {
            const line = raw as Input;
            const pid = id(line.productId);
            const factor = integer(line.factor, 1, 1e6);
            const qty = integer(line.quantity, 1);
            quantities.set(pid, (quantities.get(pid) ?? 0) + qty * factor);
          }
          for (const [productId, base] of quantities) {
            const current = await tx.get(db.doc(`${root}/stock/${productId}`));
            const quantity = integer(current.get('quantity') ?? 0, -1e9) + base;
            if (quantity > 1e9) throw new HttpsError('failed-precondition', 'Stock quantity needs review');
            stockWrites.push({ productId, quantity, revision: integer(current.get('revision') ?? 0) + 1, delta: base });
          }
          const meta = await tx.get(db.doc(`${root}/inventoryMeta/stock`));
          sequence = integer(meta.get('sequence') ?? 0) + 1;
          if (voidPayload.tenderKind === 'cash') {
            projection.expectedCashCentavos = integer(shift.expectedCashCentavos, -Number.MAX_SAFE_INTEGER, Number.MAX_SAFE_INTEGER) - voidPayload.voidCentavos;
            projection.cashRefundCentavos = integer(shift.cashRefundCentavos ?? 0, 0, Number.MAX_SAFE_INTEGER) + voidPayload.voidCentavos;
          }
          extraWrites.push(() => {
            tx.create(voidRef, {
              originalSaleId: voidPayload.originalSaleId,
              voidOperationId: intent.id,
              voidCentavos: voidPayload.voidCentavos,
              tenderKind: voidPayload.tenderKind,
              reason: voidPayload.reason,
              authorizedByCashierId: voidPayload.authorizedByCashierId,
              voidedAt: FieldValue.serverTimestamp(),
            });
          });
          await reverseCredit(originalOpSnap.get('intent'), voidPayload.voidCentavos);
          finance = { voidCentavos: voidPayload.voidCentavos, originalSaleId: voidPayload.originalSaleId };
        } else if (intent.kind === 'debtRepayment') {
          const amount = integer(intent.payload.amountCentavos,1);
          const customerRef = db.doc(`merchants/${scope.merchantId}/customers/${id(intent.payload.customerId)}`);
          const customer = await tx.get(customerRef);
          if (!customer.exists || amount > integer(customer.get('balanceCentavos'))) throw new HttpsError('failed-precondition','Repayment exceeds customer debt');
          extraWrites.push(() => tx.update(customerRef,{balanceCentavos:integer(customer.get('balanceCentavos'))-amount}));
          if (intent.payload.tenderKind === 'cash') {
            projection.cashInCentavos = integer(shift.cashInCentavos)+amount;
            projection.expectedCashCentavos = integer(shift.expectedCashCentavos,-Number.MAX_SAFE_INTEGER,Number.MAX_SAFE_INTEGER)+amount;
          }
        } else if (intent.kind === 'cashIn' || intent.kind === 'cashOut') {
          keys(intent.payload,['amountCentavos','reason']);
          const amount=integer(intent.payload.amountCentavos,1); text(intent.payload.reason,160);
          const field=intent.kind==='cashIn'?'cashInCentavos':'cashOutCentavos';
          projection[field]=integer(shift[field],0,Number.MAX_SAFE_INTEGER)+amount;
          projection.expectedCashCentavos=shift.expectedCashCentavos+(intent.kind==='cashIn'?amount:-amount);
        } else {
          keys(intent.payload,['countedCentavos','reason']);
          const counted=integer(intent.payload.countedCentavos), variance=counted-shift.expectedCashCentavos;
          text(intent.payload.reason,160,variance===0);
          integer(variance,-Number.MAX_SAFE_INTEGER,Number.MAX_SAFE_INTEGER);
          projection={...projection,open:false,countedCentavos:counted,varianceCentavos:variance,reason:intent.payload.reason}; close=true;
        }
        for (const field of ['cashSalesCentavos','cashInCentavos','cashOutCentavos','cashRefundCentavos','expectedCashCentavos'])
          if (projection[field] !== undefined) integer(projection[field],field==='expectedCashCentavos'?-Number.MAX_SAFE_INTEGER:0,Number.MAX_SAFE_INTEGER);
      } catch (error) {
        if (!(error instanceof HttpsError) || !['invalid-argument','failed-precondition'].includes(error.code)) throw error;
        blocked(intent.kind==='sale'?'Receipt prices or quantities need review':(intent.kind==='refund'||intent.kind==='voidSale'?'Refund or void needs review':'Check the cash amount and reason'));
      }
    }
    if (result.status === 'accepted') {
      const date = new Date(Date.parse(intent.occurredAt)+8*3600000).toISOString().slice(0,10);
      const dailyRef = db.doc(`${root}/dailyReports/${date}`);
      const existingDaily = await tx.get(dailyRef);
      const daily = existingDaily.data() ?? {date,branchId:scope.branchId,grossSalesCentavos:0,
        discountsCentavos:0,refundsCentavos:0,voidsCentavos:0,transactionCount:0,
        tenders:{cashCentavos:0,qrCentavos:0,creditCentavos:0},cashInCentavos:0,cashOutCentavos:0,
        openingFloatCentavos:0,cashRefundsCentavos:0,cashVoidsCentavos:0};
      if (intent.kind === 'sale') {
        const sale = parseSale(intent.payload), tender = object(intent.payload.tender);
        daily.grossSalesCentavos += sale.total;
        daily.transactionCount += 1;
        const field = tender.kind === 'cash' ? 'cashCentavos' : tender.kind === 'qr' ? 'qrCentavos' : 'creditCentavos';
        daily.tenders[field] = (daily.tenders[field] ?? 0) + sale.total;
      } else if (intent.kind === 'refund') {
        const refund = parseRefund(intent.payload);
        daily.refundsCentavos += refund.totalRefundCentavos;
        if (refund.tenderKind === 'cash') daily.cashRefundsCentavos += refund.totalRefundCentavos;
      } else if (intent.kind === 'voidSale') {
        const value = parseVoid(intent.payload);
        daily.voidsCentavos += value.voidCentavos;
        if (value.tenderKind === 'cash') daily.cashVoidsCentavos += value.voidCentavos;
      } else if (intent.kind === 'openShift') daily.openingFloatCentavos += integer(intent.payload.floatCentavos);
      else if (intent.kind === 'cashIn' || (intent.kind === 'debtRepayment' && intent.payload.tenderKind === 'cash')) daily.cashInCentavos += integer(intent.payload.amountCentavos);
      else if (intent.kind === 'cashOut') daily.cashOutCentavos += integer(intent.payload.amountCentavos);
      else if (intent.kind === 'closeShift') daily.actualCountedCashCentavos = (daily.actualCountedCashCentavos ?? 0)+integer(intent.payload.countedCentavos);
      extraWrites.push(() => tx.set(dailyRef,daily));
    }
    if (result.status === 'accepted') {
      for (const w of extraWrites) w();
      tx.set(shiftRef,{...projection,updatedAt:FieldValue.serverTimestamp()});
      if (intent.kind==='openShift' || close) tx.set(deviceRef,{activeShift:close?null:intent.shiftId});
      if (sequence !== undefined) {
        result.sequence=sequence;
        for (const p of stockWrites) tx.set(db.doc(`${root}/stock/${p.productId}`),{quantity:p.quantity,revision:p.revision});
        tx.set(db.doc(`${root}/inventoryMeta/stock`),{sequence});
        const changeKind = intent.kind === 'refund' ? 'refund' : intent.kind === 'voidSale' ? 'void' : 'sale';
        tx.create(db.doc(`${root}/stockChanges/${key(sequence)}`),{sequence,operationId:intent.id,kind:changeKind,positions:stockWrites});
      }
    }
    tx.create(operationRef,{fingerprint:hash,intent,result,...(result.status==='accepted'?finance:{}),receivedAt:FieldValue.serverTimestamp()});
    return result;
  });
}
