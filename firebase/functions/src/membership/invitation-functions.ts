import { getFirestore } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { toHttpsError } from '../common/errors';
import {
  acceptManagerInvitation as acceptInvite,
  createManagerInvitation as createInvite,
  listMyInvitations as listInvites,
  removeManager as remove,
  revokeManagerInvitation as revokeInvite,
  updateManagerAccess as updateAccess,
} from './membership-service';

const options = { region: 'asia-southeast1' } as const;
function dataObject(value: unknown): Record<string, unknown> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new HttpsError('invalid-argument', 'Request data must be an object');
  }
  return value as Record<string, unknown>;
}
async function handle<T>(work: () => Promise<T>): Promise<T> {
  try { return await work(); } catch (error) {
    if (!(error instanceof HttpsError)) logger.error('Membership callable failed', error);
    throw toHttpsError(error);
  }
}

export const createManagerInvitation = onCall(options, (request) =>
  handle(() => createInvite(getFirestore(), request, {
    merchantId: dataObject(request.data).merchantId as string,
    email: dataObject(request.data).email as string,
    allBranches: dataObject(request.data).allBranches as boolean,
    branchIds: dataObject(request.data).branchIds as string[],
    operationId: dataObject(request.data).operationId as string,
  })));

export const listMyInvitations = onCall(options, (request) =>
  handle(async () => ({ invitations: await listInvites(getFirestore(), request) })));

export const acceptManagerInvitation = onCall(options, (request) =>
  handle(() => {
    const data = dataObject(request.data);
    return acceptInvite(getFirestore(), request, data.merchantId as string, data.inviteId as string);
  }));

export const revokeManagerInvitation = onCall(options, (request) =>
  handle(async () => {
    const data = dataObject(request.data);
    await revokeInvite(getFirestore(), request, data.merchantId as string, data.inviteId as string);
    return { status: 'revoked' };
  }));

export const updateManagerAccess = onCall(options, (request) =>
  handle(async () => {
    const data = dataObject(request.data);
    await updateAccess(getFirestore(), request, data.merchantId as string,
      data.managerUid as string, data.allBranches as boolean, data.branchIds as string[]);
    return { status: 'updated' };
  }));

export const removeManager = onCall(options, (request) =>
  handle(async () => {
    const data = dataObject(request.data);
    await remove(getFirestore(), request, data.merchantId as string, data.managerUid as string);
    return { status: 'removed' };
  }));
