import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
  type RulesTestEnvironment,
} from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
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

  it('limits Manager branch reads to assigned branches', async () => {
    const db = environment.authenticatedContext('manager-1').firestore();
    await assertSucceeds(getDoc(doc(db, 'merchants/merchant-1/branches/branch-a')));
    await assertFails(getDoc(doc(db, 'merchants/merchant-1/branches/branch-b')));
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
  });
});
