import type { Auth, UserRecord } from 'firebase-admin/auth';
import type { Firestore } from 'firebase-admin/firestore';
import { describe, expect, it } from 'vitest';
import { grantPlatformAdmin } from '../../src/admin/admin-service';

describe('grantPlatformAdmin', () => {
  it('pre-authorizes an existing user and preserves existing claims', async () => {
    let record: Record<string, unknown> | undefined;
    let claims: Record<string, unknown> | undefined;
    const auth = {
      getUserByEmail: async () => ({
        uid: 'user-1', email: 'admin@example.com', disabled: false,
        customClaims: { existingClaim: 'keep' },
      } as UserRecord),
      setCustomUserClaims: async (_uid: string, next: Record<string, unknown>) => {
        claims = next;
      },
    } as unknown as Auth;
    const db = {
      doc: (path: string) => ({
        set: async (next: Record<string, unknown>) => {
          expect(path).toBe('platformAdmins/user-1');
          record = next;
        },
      }),
    } as unknown as Firestore;

    await grantPlatformAdmin(auth, db, { email: 'admin@example.com' });

    expect(record).toMatchObject({
      uid: 'user-1', email: 'admin@example.com', status: 'active',
    });
    expect(claims).toEqual({ existingClaim: 'keep', sarisupplyAdmin: true });
  });

  it('rejects an ambiguous user selector', async () => {
    await expect(grantPlatformAdmin({} as Auth, {} as Firestore, {
      uid: 'user-1', email: 'admin@example.com',
    })).rejects.toThrow();
  });
});
