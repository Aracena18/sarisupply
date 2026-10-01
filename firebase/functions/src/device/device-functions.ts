import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { toHttpsError } from '../common/errors';
import {
  activatePosDevice as activate,
  getDeviceBootstrap as bootstrap,
  revokePosDevice as revoke,
} from './device-service';

const options = { region: 'asia-southeast1' } as const;
function dataObject(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpsError('invalid-argument', 'Request data must be an object');
  }
  return value as Record<string, unknown>;
}
async function handle<T>(work: () => Promise<T>): Promise<T> {
  try { return await work(); } catch (error) {
    if (!(error instanceof HttpsError)) logger.error('Device callable failed', error);
    throw toHttpsError(error);
  }
}

export const activatePosDevice = onCall(options, (request) =>
  handle(() => {
    const data = dataObject(request.data);
    return activate(getFirestore(), (uid, claims) =>
      getAuth().createCustomToken(uid, claims), request, {
        merchantId: data.merchantId as string,
        branchId: data.branchId as string,
        displayName: data.displayName as string,
        platform: data.platform as string,
        appVersion: data.appVersion as string,
        operationId: data.operationId as string,
      });
  }));

export const revokePosDevice = onCall(options, (request) =>
  handle(async () => {
    const data = dataObject(request.data);
    await revoke(getFirestore(), request, data.merchantId as string,
      data.deviceId as string);
    return { status: 'revoked' };
  }));

export const getDeviceBootstrap = onCall(options, (request) =>
  handle(() => bootstrap(getFirestore(), request)));
