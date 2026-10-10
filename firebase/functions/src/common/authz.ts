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

export const companyRoles = ['companyOwner', 'warehouseOperations', 'rider'] as const;
export type CompanyRole = typeof companyRoles[number];
export interface CompanyRoleGrant extends DocumentData {
  companyId: string;
  userId: string;
  role: CompanyRole;
  status: 'active';
  revision: number;
  scope: { kind: 'company' } | { kind: 'warehouses'; warehouseIds: string[] };
}

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

  async requireCompanyRole(
    request: AuthRequest, companyId: string, role: CompanyRole, warehouseId?: string,
  ): Promise<{ grant: CompanyRoleGrant; membershipRevision: number }> {
    const uid = requireHuman(request);
    const token = request.auth?.token;
    const firebase = token?.firebase as Record<string, unknown> | undefined;
    if (token?.email_verified !== true || typeof token.email !== 'string' ||
        !token.email.trim() || firebase?.sign_in_provider !== 'google.com') throw denied();
    requireDocumentId(companyId, 'company ID');
    if (!companyRoles.includes(role)) throw denied();
    const root = `companies/${companyId}`;
    const company = await this.readDocument(root);
    const member = await this.readDocument(`${root}/memberships/${uid}`);
    const grant = await this.readDocument(`${root}/memberships/${uid}/roles/${role}`);
    const revision = (value: unknown): value is number =>
      typeof value === 'number' && Number.isSafeInteger(value) && value > 0;
    if (company?.companyId !== companyId || company.status !== 'active' ||
        company.authorizationVersion !== 1 || member?.companyId !== companyId ||
        member.userId !== uid || member.status !== 'active' || !revision(member.revision) ||
        grant?.companyId !== companyId || grant.userId !== uid || grant.role !== role ||
        grant.status !== 'active' || !revision(grant.revision)) throw denied();
    const scope = grant.scope as Record<string, unknown> | undefined;
    let warehousesToCheck: string[] = [];
    if (role === 'companyOwner') {
      if (scope?.kind !== 'company' || Object.hasOwn(scope, 'warehouseIds')) throw denied();
    } else {
      const ids = scope?.warehouseIds;
      if (scope?.kind !== 'warehouses' || !Array.isArray(ids) || !ids.length ||
          ids.length > 100 || new Set(ids).size !== ids.length ||
          !ids.every(value => typeof value === 'string' && value.length > 0 &&
            value.length <= 128 && !value.includes('/') && value !== '.' && value !== '..')) throw denied();
      if (warehouseId !== undefined && !ids.includes(warehouseId)) throw denied();
      warehousesToCheck = warehouseId === undefined ? ids as string[] : [warehouseId];
    }
    if (role === 'companyOwner' && warehouseId !== undefined) warehousesToCheck = [warehouseId];
    for (const selectedId of warehousesToCheck) {
      requireDocumentId(selectedId, 'warehouse ID');
      const warehouse = await this.readDocument(`${root}/warehouses/${selectedId}`);
      if (warehouse?.companyId !== companyId || warehouse.warehouseId !== selectedId ||
          warehouse.status !== 'active') throw denied();
    }
    return { grant: grant as CompanyRoleGrant, membershipRevision: member.revision };
  }

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
        (membership.role === 'owner' && membership.allBranches !== true) ||
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
