import { Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { AuthRequest, AuthorizationService, requireHuman } from '../common/authz';
import { requireCashierGrant, GrantScope } from './cashier-grants';
import { object, id, integer, text, canonical } from './checkout-validation';

export async function manageCustomers(db: Firestore, request: AuthRequest, input: Record<string, unknown>) {
  const merchantId = id(input.merchantId), action = text(input.action, 32);
  return db.runTransaction(async tx => {
    const authorization = new AuthorizationService(async p => (await tx.get(db.doc(p))).data() ?? null);
    if (request.auth?.token.principalType === 'device') {
      const scope = object(input.scope) as GrantScope;
      if (scope.merchantId !== merchantId || action === 'save') throw new HttpsError('permission-denied', 'Owner approval required');
      await requireCashierGrant(db, tx, request, scope, input.grantSecret, new Date().toISOString());
    } else {
      await authorization.requireOwner(requireHuman(request), merchantId);
    }
    const root = `merchants/${merchantId}`;
    if (action === 'list') {
      const page = await tx.get(db.collection(`${root}/customers`).orderBy('name').limit(50));
      return {customers: page.docs.map(d => ({...d.data(), id:d.id}))};
    }
    const customerId = id(input.customerId);
    const customerRef = db.doc(`${root}/customers/${customerId}`);
    const existing = await tx.get(customerRef);
    if (action === 'save') {
      const customer = object(input.customer);
      const name = text(customer.name, 120), phone = text(customer.phone ?? '', 40, true);
      const creditLimitCentavos = integer(customer.creditLimitCentavos);
      const current = existing.data();
      if (creditLimitCentavos < integer(current?.balanceCentavos ?? 0) + integer(current?.reservedCentavos ?? 0)) {
        throw new HttpsError('failed-precondition', 'Limit is below existing debt and reserved allowance');
      }
      const saved = {id:customerId,name,phone,creditLimitCentavos,active:true,
        balanceCentavos:integer(current?.balanceCentavos ?? 0),reservedCentavos:integer(current?.reservedCentavos ?? 0)};
      tx.set(customerRef,saved);
      return {customer:saved};
    }
    if (action === 'cancelReservation') {
      if (request.auth?.token.principalType !== 'device') throw new HttpsError('permission-denied','Cashier device required');
      const scope = object(input.scope) as GrantScope, operationId = id(input.operationId);
      const ref = db.doc(`${root}/creditAllowances/${operationId}`), previous = await tx.get(ref);
      if (previous.exists && (previous.get('deviceId') !== scope.deviceId || previous.get('branchId') !== scope.branchId || previous.get('customerId') !== customerId)) throw new HttpsError('permission-denied','Allowance scope mismatch');
      if (previous.get('status') === 'cancelled') return {status:'cancelled',operationId};
      if (previous.exists && integer(previous.get('usedCreditCentavos')) !== 0) throw new HttpsError('failed-precondition','Used allowance cannot be cancelled');
      const amount = previous.exists ? integer(previous.get('allowedCreditCentavos')) : 0;
      if (amount) {
        const reserved = integer(existing.get('reservedCentavos')) - amount;
        if (reserved < 0) throw new HttpsError('failed-precondition','Allowance needs review');
        tx.update(customerRef,{reservedCentavos:reserved});
      }
      // The tombstone also blocks a reservation whose response was lost or delayed.
      tx.set(ref,{status:'cancelled',customerId,deviceId:scope.deviceId,branchId:scope.branchId},{merge:true});
      return {status:'cancelled',operationId};
    }
    if (action === 'reserve') {
      if (request.auth?.token.principalType !== 'device') throw new HttpsError('permission-denied','Cashier device required');
      const scope = object(input.scope) as GrantScope;
      const grantId = id(input.operationId), amount = integer(input.amountCentavos,1);
      const grantRef = db.doc(`${root}/creditAllowances/${grantId}`);
      const previous = await tx.get(grantRef);
      const fingerprint = canonical({customerId,deviceId:scope.deviceId,amount});
      if (previous.exists) {
        if (previous.get('status') === 'cancelled') throw new HttpsError('failed-precondition','Allowance cancelled');
        if (previous.get('branchId') !== scope.branchId || previous.get('fingerprint') !== fingerprint) throw new HttpsError('already-exists','Allowance ID changed');
        return {grant:previous.data()};
      }
      const customer = existing.data();
      if (!customer || customer.active !== true ||
          integer(customer.balanceCentavos) + integer(customer.reservedCentavos ?? 0) + amount > integer(customer.creditLimitCentavos)) {
        throw new HttpsError('failed-precondition','Customer credit is unavailable');
      }
      const issuedAt = new Date().toISOString();
      const grant = {id:grantId, customerId, deviceId:scope.deviceId, branchId:scope.branchId,
        allowedCreditCentavos:amount,usedCreditCentavos:0,issuedAt,
        expiresAt:new Date(Date.now()+7*86400000).toISOString(),fingerprint};
      tx.create(grantRef,grant);
      tx.update(customerRef,{reservedCentavos:integer(customer.reservedCentavos ?? 0)+amount});
      return {grant};
    }
    throw new HttpsError('invalid-argument','Unknown customer action');
  });
}
