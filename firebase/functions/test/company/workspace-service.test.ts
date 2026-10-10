import { describe, expect, it } from 'vitest';
import { listCompanyInvitations } from '../../src/company/workspace-service';

const companyId = 'company-1';
const root = `companies/${companyId}`;
const request = { auth: { uid: 'owner', token: {
  email: 'owner@example.com', email_verified: true,
  firebase: { sign_in_provider: 'google.com' },
} } };
const input = { authorizationVersion: 1,
  context: { kind: 'company', companyId, role: 'companyOwner' } };

function database(ownerActive = true) {
  const records: Record<string, Record<string, unknown>> = {
    [root]: { companyId, authorizationVersion: 1, status: 'active' },
    [`${root}/memberships/owner`]: {
      companyId, userId: 'owner', status: 'active', revision: 1,
    },
    [`${root}/memberships/owner/roles/companyOwner`]: {
      companyId, userId: 'owner', role: 'companyOwner', revision: 1,
      status: ownerActive ? 'active' : 'removed', scope: { kind: 'company' },
    },
  };
  const docs = ['warehouseOperations', 'rider'].map(role => {
    const data: Record<string, unknown> = {
      recipientEmail: `${role}@example.com`, role, warehouseIds: ['warehouse-1'],
      status: 'pending', expiresAt: { toDate: () => new Date('2099-01-01T00:00:00Z') },
    };
    return { id: `invite-${role}`, get: (field: string) => data[field] };
  });
  const query = { orderBy: () => query, limit: () => query };
  const tx = { get: async (ref: unknown) => ref === query
    ? { docs, size: docs.length }
    : { data: () => records[ref as string] } };
  return {
    doc: (path: string) => path,
    collection: () => query,
    runTransaction: async (callback: (transaction: typeof tx) => unknown) => callback(tx),
  };
}

describe('company invitation list contract', () => {
  it('includes the company ID required by Admin for both staff roles', async () => {
    const result = await listCompanyInvitations(database() as never, request, input);
    expect(result.invitations).toEqual(['warehouseOperations', 'rider'].map(role => ({
      invitationId: `invite-${role}`, companyId, email: `${role}@example.com`,
      role, warehouseIds: ['warehouse-1'], status: 'pending',
      expiresAt: '2099-01-01T00:00:00.000Z',
    })));
  });

  it('denies listing after the owner role is removed', async () => {
    await expect(listCompanyInvitations(database(false) as never, request, input))
      .rejects.toMatchObject({ code: 'permission-denied' });
  });
});
