import { describe, expect, it } from 'vitest';
import { AuthorizationService, requireHuman } from '../../src/common/authz';

const human = (uid = 'owner-1') => ({ auth: { uid, token: {} } });
const device = (uid = 'device-uid') => ({
  auth: {
    uid,
    token: { principalType: 'device', merchantId: 'merchant-1', deviceId: 'pos-1' },
  },
});

function service(records: Record<string, Record<string, unknown>>) {
  return new AuthorizationService(async (path) => records[path] ?? null);
}

const merchant = { status: 'active' };
const branchA = { status: 'active', merchantId: 'merchant-1' };
const branchB = { status: 'active', merchantId: 'merchant-1' };

describe('backend authorization', () => {
  it('rejects requests without Firebase authentication', () => {
    expect(() => requireHuman({})).toThrowError(/sign in/i);
  });

  it('rejects a human with no merchant membership', async () => {
    const authz = service({ 'merchants/merchant-1': merchant });
    await expect(authz.requireActiveMembership('owner-1', 'merchant-1'))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('allows an active Owner to access an active branch', async () => {
    const authz = service({
      'merchants/merchant-1': merchant,
      'merchants/merchant-1/memberships/owner-1': {
        userId: 'owner-1', merchantId: 'merchant-1', role: 'owner',
        status: 'active', allBranches: true, branchIds: [],
      },
      'merchants/merchant-1/branches/branch-a': branchA,
    });
    await expect(authz.requireOwner('owner-1', 'merchant-1')).resolves.toBeDefined();
    await expect(authz.requireBranchAccess('owner-1', 'merchant-1', 'branch-a'))
      .resolves.toBeDefined();
  });

  it('limits a Manager to assigned active branches', async () => {
    const authz = service({
      'merchants/merchant-1': merchant,
      'merchants/merchant-1/memberships/manager-1': {
        userId: 'manager-1', merchantId: 'merchant-1', role: 'manager',
        status: 'active', allBranches: false, branchIds: ['branch-a'],
      },
      'merchants/merchant-1/branches/branch-a': branchA,
      'merchants/merchant-1/branches/branch-b': branchB,
    });
    await expect(authz.requireBranchAccess('manager-1', 'merchant-1', 'branch-a'))
      .resolves.toBeDefined();
    await expect(authz.requireBranchAccess('manager-1', 'merchant-1', 'branch-b'))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('rejects a removed Manager even with a cached branch assignment', async () => {
    const authz = service({
      'merchants/merchant-1': merchant,
      'merchants/merchant-1/memberships/manager-1': {
        userId: 'manager-1', merchantId: 'merchant-1', role: 'manager',
        status: 'removed', allBranches: true, branchIds: ['branch-a'],
      },
      'merchants/merchant-1/branches/branch-a': branchA,
    });
    await expect(authz.requireBranchAccess('manager-1', 'merchant-1', 'branch-a'))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('accepts an active device bound to its Firebase UID', async () => {
    const authz = service({
      'merchants/merchant-1': merchant,
      'merchants/merchant-1/branches/branch-a': branchA,
      'merchants/merchant-1/devices/pos-1': {
        authUid: 'device-uid', merchantId: 'merchant-1', branchId: 'branch-a',
        status: 'active',
      },
    });
    await expect(authz.requireActiveDevice(device()))
      .resolves.toMatchObject({ branchId: 'branch-a' });
  });

  it('rejects a revoked device despite a valid cached token', async () => {
    const authz = service({
      'merchants/merchant-1': merchant,
      'merchants/merchant-1/branches/branch-a': branchA,
      'merchants/merchant-1/devices/pos-1': {
        authUid: 'device-uid', merchantId: 'merchant-1', branchId: 'branch-a',
        status: 'revoked',
      },
    });
    await expect(authz.requireActiveDevice(device()))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('rejects an admin claim without an active admin record', async () => {
    const authz = service({});
    await expect(authz.requirePlatformAdmin({
      auth: { uid: 'admin-1', token: { sarisupplyAdmin: true } },
    })).rejects.toMatchObject({ code: 'permission-denied' });
  });

  it('requires both the admin claim and active admin record', async () => {
    const authz = service({ 'platformAdmins/admin-1': { status: 'active' } });
    await expect(authz.requirePlatformAdmin(human('admin-1')))
      .rejects.toMatchObject({ code: 'permission-denied' });
    await expect(authz.requirePlatformAdmin({
      auth: { uid: 'admin-1', token: { sarisupplyAdmin: true } },
    })).resolves.toBeDefined();
  });
});
