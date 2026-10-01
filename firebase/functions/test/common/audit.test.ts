import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { describe, expect, it } from 'vitest';
import { writeAuditEvent } from '../../src/common/audit';

describe('writeAuditEvent', () => {
  it('creates an immutable merchant event inside the business transaction', async () => {
    let createdPath = '';
    let createdData: Record<string, unknown> = {};
    const db = {
      doc: (path: string) => ({ path }),
      collection: (path: string) => ({
        doc: () => ({ id: 'event-1', path: `${path}/event-1` }),
      }),
    } as unknown as Firestore;
    const transaction = {
      create: (ref: { path: string }, data: Record<string, unknown>) => {
        createdPath = ref.path;
        createdData = data;
      },
    } as unknown as Transaction;

    const eventId = await writeAuditEvent({
      merchantId: 'merchant-1',
      actorType: 'human',
      actorId: 'owner-1',
      action: 'merchant.approved',
      targetType: 'merchant',
      targetId: 'merchant-1',
    }, transaction, db);

    expect(eventId).toBe('event-1');
    expect(createdPath).toBe('merchants/merchant-1/auditEvents/event-1');
    expect(createdData).toMatchObject({
      actorType: 'human', actorId: 'owner-1', action: 'merchant.approved',
      targetType: 'merchant', targetId: 'merchant-1',
    });
  });
});
