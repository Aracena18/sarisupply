import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { requireDocumentId } from './ids';

export interface AuthRequest {
  auth?: {
    uid: string;
    token: Record<string, unknown>;
  };
}

export type DocumentData = Record<string, unknown>;
export type ReadDocument = (path: string) => Promise<DocumentData | null>;

export interface MembershipRecord extends DocumentData {
  userId: string;
  merchantId: string;
  role: 'owner' | 'manager';
  status: 'active';
  allBranches: boolean;
  branchIds: string[];
}

export interface ActiveDevice extends DocumentData {
  authUid: string;
  merchantId: string;
  branchId: string;
  status: 'active';
}

const denied = () => new HttpsError('permission-denied', 'Access denied');

export function requireHuman(request: AuthRequest): string {
  const uid = request.auth?.uid;
  if (!uid || request.auth?.token.principalType === 'device') {
    throw new HttpsError('unauthenticated', 'Sign in as a human user');
  }
  return requireDocumentId(uid, 'user ID');
}

export class AuthorizationService {
  constructor(private readonly readDocument: ReadDocument) {}

  async requirePlatformAdmin(request: AuthRequest): Promise<string> {
    const uid = requireHuman(request);
    if (request.auth?.token.sarisupplyAdmin !== true) throw denied();
    const admin = await this.readDocument(`platformAdmins/${uid}`);
    if (admin?.status !== 'active' ||
        (admin.uid !== undefined && admin.uid !== uid)) {
      throw denied();
    }
    return uid;
  }

  async requireActiveMembership(
    uid: string,
    merchantId: string,
  ): Promise<MembershipRecord> {
    requireDocumentId(uid, 'user ID');
    requireDocumentId(merchantId, 'merchant ID');
    const merchant = await this.readDocument(`merchants/${merchantId}`);
    if (merchant?.status !== 'active') throw denied();
    const membership = await this.readDocument(
      `merchants/${merchantId}/memberships/${uid}`,
    );
    if (membership?.userId !== uid ||
        membership.merchantId !== merchantId ||
        membership.status !== 'active' ||
        (membership.role !== 'owner' && membership.role !== 'manager') ||
        typeof membership.allBranches !== 'boolean' ||
        !Array.isArray(membership.branchIds) ||
        !membership.branchIds.every((id) => typeof id === 'string')) {
      throw denied();
    }
    return membership as MembershipRecord;
  }

  async requireOwner(uid: string, merchantId: string): Promise<MembershipRecord> {
    const membership = await this.requireActiveMembership(uid, merchantId);
    if (membership.role !== 'owner' || membership.allBranches !== true) {
      throw denied();
    }
    return membership;
  }

  async requireBranchAccess(
    uid: string,
    merchantId: string,
    branchId: string,
  ): Promise<MembershipRecord> {
    requireDocumentId(branchId, 'branch ID');
    const membership = await this.requireActiveMembership(uid, merchantId);
    const branch = await this.readDocument(
      `merchants/${merchantId}/branches/${branchId}`,
    );
    if (branch?.status !== 'active' || branch.merchantId !== merchantId) {
      throw denied();
    }
    if (membership.role !== 'owner' &&
        !membership.allBranches &&
        !membership.branchIds.includes(branchId)) {
      throw denied();
    }
    return membership;
  }

  async requireActiveDevice(request: AuthRequest): Promise<ActiveDevice> {
    const uid = requireDocumentId(request.auth?.uid, 'device UID');
    const token = request.auth?.token;
    if (token?.principalType !== 'device') {
      throw new HttpsError('unauthenticated', 'Sign in as a POS device');
    }
    const merchantId = requireDocumentId(token.merchantId, 'merchant ID');
    const deviceId = requireDocumentId(token.deviceId, 'device ID');
    const merchant = await this.readDocument(`merchants/${merchantId}`);
    if (merchant?.status !== 'active') throw denied();
    const device = await this.readDocument(
      `merchants/${merchantId}/devices/${deviceId}`,
    );
    if (device?.authUid !== uid ||
        device.merchantId !== merchantId ||
        device.status !== 'active' ||
        typeof device.branchId !== 'string') {
      throw denied();
    }
    const branchId = requireDocumentId(device.branchId, 'branch ID');
    const branch = await this.readDocument(
      `merchants/${merchantId}/branches/${branchId}`,
    );
    if (branch?.status !== 'active' || branch.merchantId !== merchantId) {
      throw denied();
    }
    return device as ActiveDevice;
  }
}

const liveAuthorization = new AuthorizationService(async (path) => {
  const snapshot = await getFirestore().doc(path).get();
  return snapshot.exists ? snapshot.data() ?? null : null;
});

export const requirePlatformAdmin = (request: AuthRequest) =>
  liveAuthorization.requirePlatformAdmin(request);
export const requireActiveMembership = (uid: string, merchantId: string) =>
  liveAuthorization.requireActiveMembership(uid, merchantId);
export const requireOwner = (uid: string, merchantId: string) =>
  liveAuthorization.requireOwner(uid, merchantId);
export const requireBranchAccess = (
  uid: string,
  merchantId: string,
  branchId: string,
) => liveAuthorization.requireBranchAccess(uid, merchantId, branchId);
export const requireActiveDevice = (request: AuthRequest) =>
  liveAuthorization.requireActiveDevice(request);
