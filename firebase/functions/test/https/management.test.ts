import { expect, it } from 'vitest';
import { listManagementRecords } from '../../src/management/workspace-service';
it('a malformed owner without owner-wide scope cannot list privileged records', async () => {
  const db = { doc: (path: string) => ({ get: async () => ({ data: () => path.includes('memberships')
    ? { userId: 'owner', merchantId: 'merchant', role: 'owner', status: 'active', allBranches: false, branchIds: [] }
    : { status: 'active' } }) }), collection: () => { throw new Error('Must not query'); } };
  await expect(listManagementRecords(db as never, { auth: { uid: 'owner', token: {} } },
    { merchantId: 'merchant', kind: 'invitations' })).rejects.toMatchObject({ code: 'permission-denied' });
});
it('invitation-created manager schema resolves a readable legacy identity', async () => {
  const db = {
    doc: (path: string) => ({ get: async () => ({ data: () => path.includes('memberships')
      ? { userId: 'owner', merchantId: 'merchant', role: 'owner', status: 'active', allBranches: true, branchIds: [] }
      : { status: 'active' } }) }),
    collection: (path: string) => {
      const data = path.endsWith('managerInvites')
        ? { status: 'accepted', merchantId: 'merchant', acceptedBy: 'manager', email: 'ana@example.test' }
        : { role: 'manager', status: 'active', branchIds: ['main'], allBranches: false };
      const query = { orderBy: () => query, limit: () => query, where: () => query,
        get: async () => ({ size: 1, docs: [{ id: 'manager', data: () => data }] }) };
      return query;
    },
  };
  const page = await listManagementRecords(db as never, { auth: { uid: 'owner', token: {} } }, { merchantId: 'merchant', kind: 'managers' });
  expect(page.records[0].name).toBe('ana@example.test');
});
