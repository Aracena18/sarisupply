import { getFirestore } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { defineSecret } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { toHttpsError } from '../common/errors';
import {
  changeCashierPin as changePin,
  createCashier as create,
  refreshCashierCredentialBundle as refreshBundle,
  resetCashierPin as resetPin,
  setCashierStatus as setStatus,
  verifyCashierPin as verifyPin,
} from './cashier-service';
import { createPinHasher } from './pin-kdf';

const pepper = defineSecret('CASHIER_PIN_PEPPER');
const options = { region: 'asia-southeast1' } as const;
const secureOptions = { ...options, secrets: [pepper] };
function dataObject(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpsError('invalid-argument', 'Request data must be an object');
  }
  return value as Record<string, unknown>;
}
async function handle<T>(work: () => Promise<T>): Promise<T> {
  try { return await work(); } catch (error) {
    if (!(error instanceof HttpsError)) logger.error('Cashier callable failed', error);
    throw toHttpsError(error);
  }
}
function hasher() { return createPinHasher(pepper.value()); }

export const createCashier = onCall(secureOptions, (request) =>
  handle(() => {
    const data = dataObject(request.data);
    return create(getFirestore(), hasher(), request, {
      merchantId: data.merchantId as string,
      displayName: data.displayName as string,
      employeeCode: data.employeeCode as string,
      assignedBranchIds: data.assignedBranchIds as string[],
    });
  }));

export const setCashierStatus = onCall(options, (request) =>
  handle(async () => {
    const data = dataObject(request.data);
    await setStatus(getFirestore(), request, data.merchantId as string,
      data.cashierId as string, data.status as 'active' | 'suspended');
    return { status: data.status };
  }));

export const verifyCashierPin = onCall(secureOptions, (request) =>
  handle(() => {
    const data = dataObject(request.data);
    return verifyPin(getFirestore(), hasher(), request,
      data.cashierId as string, data.pin as string);
  }));

export const changeCashierPin = onCall(secureOptions, (request) =>
  handle(() => {
    const data = dataObject(request.data);
    return changePin(getFirestore(), hasher(), request,
      data.cashierId as string, data.currentPin as string,
      data.newPin as string);
  }));

export const resetCashierPin = onCall(secureOptions, (request) =>
  handle(() => {
    const data = dataObject(request.data);
    return resetPin(getFirestore(), hasher(), request,
      data.merchantId as string, data.cashierId as string);
  }));

export const refreshCashierCredentialBundle = onCall(options, (request) =>
  handle(() => refreshBundle(getFirestore(), request)));
