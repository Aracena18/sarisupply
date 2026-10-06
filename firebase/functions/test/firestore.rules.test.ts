import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, query, setDoc, where } from 'firebase/firestore';
import { afterAll, beforeAll, beforeEach, describe, it } from 'vitest';

let environment: RulesTestEnvironment;

beforeAll(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8080').split(':');
  environment = await initializeTestEnvironment({
    projectId: 'demo-sarisupply-rules',
    firestore: {
      host,
      port: Number(port),
      rules: readFileSync(resolve(__dirname, '../../firestore.rules'), 'utf8'),
    },
  });
});

beforeEach(async () => {
  await environment.clearFirestore();
  await environment.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'users/owner-1'), { uid: 'owner-1' });
    await setDoc(doc(db, 'users/other-1'), { uid: 'other-1' });
    await setDoc(doc(db, 'users/owner-1/merchantRefs/merchant-1'), {
      merchantId: 'merchant-1', role: 'owner', status: 'active',
    });
    await setDoc(doc(db, 'merchants/merchant-1'), { status: 'active' });
    await setDoc(doc(db, 'merchants/merchant-1/memberships/owner-1'), {
      userId: 'owner-1', merchantId: 'merchant-1', role: 'owner',
      status: 'active', allBranches: true, branchIds: [],
    });
    await setDoc(doc(db, 'merchants/merchant-1/memberships/manager-1'), {
      userId: 'manager-1', merchantId: 'merchant-1', role: 'manager',
      status: 'active', allBranches: false, branchIds: ['branch-a'],
    });
    await setDoc(doc(db, 'merchants/merchant-1/branches/branch-a'), {
      merchantId: 'merchant-1', status: 'active',
    });
    await setDoc(doc(db, 'merchants/merchant-1/branches/branch-b'), {
      merchantId: 'merchant-1', status: 'active',
    });
    await setDoc(doc(db, 'platformAdmins/admin-1'), { uid: 'admin-1', status: 'active' });
    await setDoc(doc(db, 'merchantApplications/application-1'), {
      applicantUid: 'owner-1', status: 'pending_review',
    });
    await setDoc(doc(db, 'merchants/merchant-1/cashierCredentials/cashier-1'), {
      verifier: 'private',
    });
  });
});

afterAll(async () => {
  await environment?.cleanup();
});

describe('Firestore authorization rules', () => {
  it('lets users read their profile but not another user profile', async () => {
    const db = environment.authenticatedContext('owner-1').firestore();
    await assertSucceeds(getDoc(doc(db, 'users/owner-1')));
    await assertFails(getDoc(doc(db, 'users/other-1')));
  });

  it('lets an active member read only their own membership', async () => {
    const db = environment.authenticatedContext('manager-1').firestore();
    await assertSucceeds(getDoc(doc(db, 'merchants/merchant-1/memberships/manager-1')));
    await assertFails(getDoc(doc(db, 'merchants/merchant-1/memberships/owner-1')));
  });

  it('lets a human list only their own merchant references', async () => {
    const owner = environment.authenticatedContext('owner-1').firestore();
    const other = environment.authenticatedContext('other-1').firestore();
    await assertSucceeds(getDocs(collection(owner, 'users/owner-1/merchantRefs')));
    await assertFails(getDocs(collection(other, 'users/owner-1/merchantRefs')));
  });

  it('limits Manager branch reads to assigned branches', async () => {
    const db = environment.authenticatedContext('manager-1').firestore();
    await assertSucceeds(getDoc(doc(db, 'merchants/merchant-1/branches/branch-a')));
    await assertFails(getDoc(doc(db, 'merchants/merchant-1/branches/branch-b')));
  });

  it('lets an Owner query active branches but denies a scoped Manager list', async () => {
    const owner = environment.authenticatedContext('owner-1').firestore();
    const manager = environment.authenticatedContext('manager-1').firestore();
    const path = 'merchants/merchant-1/branches';
    const active = (db: typeof owner) => query(collection(db, path),
      where('status', '==', 'active'), where('merchantId', '==', 'merchant-1'));
    await assertSucceeds(getDocs(active(owner)));
    await assertFails(getDocs(active(manager)));
  });

  it('revocation in Firestore overrides a previously valid membership', async () => {
    await environment.withSecurityRulesDisabled(async (context) => {
      await setDoc(
        doc(context.firestore(), 'merchants/merchant-1/memberships/manager-1'),
        {
          userId: 'manager-1', merchantId: 'merchant-1', role: 'manager',
          status: 'removed', allBranches: true, branchIds: ['branch-a'],
        },
      );
    });
    const db = environment.authenticatedContext('manager-1').firestore();
    await assertFails(getDoc(doc(db, 'merchants/merchant-1/branches/branch-a')));
  });

  it('lets only the active pre-authorized Admin read their record', async () => {
    const db = environment.authenticatedContext('admin-1', {
      sarisupplyAdmin: true,
    }).firestore();
    await assertSucceeds(getDoc(doc(db, 'platformAdmins/admin-1')));
  });

  it('lets an active Admin review applications from other users', async () => {
    const admin = environment.authenticatedContext('admin-1', {
      sarisupplyAdmin: true,
    }).firestore();
    const unapproved = environment.authenticatedContext('other-1', {
      sarisupplyAdmin: true,
    }).firestore();
    await assertSucceeds(getDoc(doc(admin, 'merchantApplications/application-1')));
    await assertFails(getDoc(doc(unapproved, 'merchantApplications/application-1')));
  });

  it('does not trust an admin claim without a current active admin record', async () => {
    const db = environment.authenticatedContext('other-1', {
      sarisupplyAdmin: true,
    }).firestore();
    await assertFails(getDoc(doc(db, 'platformAdmins/admin-1')));
  });

  it('keeps credential material and authorization records server-only', async () => {
    const db = environment.authenticatedContext('owner-1').firestore();
    await assertFails(getDoc(doc(db, 'merchants/merchant-1/cashierCredentials/cashier-1')));
    await assertFails(setDoc(doc(db, 'merchants/merchant-1/memberships/owner-1'), {
      status: 'active', role: 'owner',
    }));
    await assertFails(getDoc(doc(db, 'merchants/merchant-1/managerInvites/invite-1')));
  });
});

describe('server-only inventory boundaries', () => {
  it('denies direct catalog, registry, feed, ledger and outbox access to every client role', async () => {
    const contexts = [environment.unauthenticatedContext(), environment.authenticatedContext('owner-1'),
      environment.authenticatedContext('manager-1'), environment.authenticatedContext('device:1', { principalType:'device',merchantId:'merchant-1',deviceId:'1' }),
      environment.authenticatedContext('admin-1', { sarisupplyAdmin:true })];
    for (const ctx of contexts) for (const path of ['merchants/merchant-1/products/p', 'merchants/merchant-1/skuRegistry/SKU',
      'merchants/merchant-1/barcodeRegistry/code', 'merchants/merchant-1/catalogChanges/0000000001',
      'merchants/merchant-1/catalogOperations/op', 'merchants/merchant-1/branches/branch-a/stock/p',
      'merchants/merchant-1/branches/branch-a/stockChanges/0000000001', 'merchants/merchant-1/branches/branch-a/stockOperations/op',
      'merchants/merchant-1/cashierGrants/grant', 'merchants/merchant-1/branches/branch-a/checkoutOperations/sale',
      'merchants/merchant-1/branches/branch-a/checkoutShifts/shift', 'merchants/merchant-1/branches/branch-a/checkoutDevices/device']) {
      await assertFails(getDoc(doc(ctx.firestore(), path)));
      await assertFails(setDoc(doc(ctx.firestore(), path), {quantity:1}));
    }
  });
});
