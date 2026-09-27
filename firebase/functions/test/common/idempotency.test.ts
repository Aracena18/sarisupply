import type { Firestore, Transaction } from 'firebase-admin/firestore';
import { describe, expect, it } from 'vitest';
import { runIdempotent } from '../../src/common/idempotency';

function memoryFirestore(): Firestore {
  const documents = new Map<string, Record<string, unknown>>();
  return {
    collection: () => ({ doc: (id: string) => ({ id }) }),
    runTransaction: async <T>(work: (tx: Transaction) => Promise<T>) => {
      const writes: Array<() => void> = [];
      const tx = {
        get: async (ref: { id: string }) => ({
          exists: documents.has(ref.id),
          get: (field: string) => documents.get(ref.id)?.[field],
        }),
        create: (ref: { id: string }, data: Record<string, unknown>) => {
          writes.push(() => documents.set(ref.id, data));
        },
      } as unknown as Transaction;
      const result = await work(tx);
      writes.forEach((write) => write());
      return result;
    },
  } as unknown as Firestore;
}

describe('runIdempotent', () => {
  it('returns the first result without invoking a retried handler', async () => {
    const db = memoryFirestore();
    let calls = 0;
    const first = await runIdempotent('merchant-1:approve:request-1', async () => {
      calls += 1;
      return { merchantId: 'merchant-1' };
    }, db);
    const retry = await runIdempotent('merchant-1:approve:request-1', async () => {
      calls += 1;
      return { merchantId: 'duplicate' };
    }, db);

    expect(first).toEqual({ merchantId: 'merchant-1' });
    expect(retry).toEqual(first);
    expect(calls).toBe(1);
  });

  it('runs a different operation key independently', async () => {
    const db = memoryFirestore();
    expect(await runIdempotent('a/b', async () => 'first', db)).toBe('first');
    expect(await runIdempotent('a:b', async () => 'second', db)).toBe('second');
  });
});
