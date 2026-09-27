import type { Auth } from 'firebase-admin/auth';
import { FieldValue } from 'firebase-admin/firestore';
import type { Firestore } from 'firebase-admin/firestore';
import { requireDocumentId } from '../common/ids';

export interface AdminSelector {
  uid?: string;
  email?: string;
}

/** Trusted operator operation. Never expose this through a client callable. */
export async function grantPlatformAdmin(
  auth: Auth,
  db: Firestore,
  selector: AdminSelector,
): Promise<string> {
  if (Boolean(selector.uid) === Boolean(selector.email)) {
    throw new Error('Specify exactly one of --uid or --email');
  }

  const user = selector.uid
    ? await auth.getUser(requireDocumentId(selector.uid, 'user ID'))
    : await auth.getUserByEmail(selector.email!.trim());
  if (user.disabled) throw new Error('Cannot grant access to a disabled user');

  await db.doc(`platformAdmins/${user.uid}`).set({
    uid: user.uid,
    email: user.email ?? null,
    status: 'active',
    updatedAt: FieldValue.serverTimestamp(),
  }, { merge: true });
  await auth.setCustomUserClaims(user.uid, {
    ...user.customClaims,
    sarisupplyAdmin: true,
  });
  return user.uid;
}
