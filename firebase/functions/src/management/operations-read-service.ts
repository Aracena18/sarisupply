import { Firestore } from 'firebase-admin/firestore';
import { AuthRequest, AuthorizationService, requireHuman } from '../common/authz';
import { HttpsError } from 'firebase-functions/v2/https';
import { text } from '../checkout/checkout-validation';

export async function readOperationalWorkspace(db: Firestore, request: AuthRequest, input: Record<string, unknown>) {
  requireHuman(request);
  const action = text(input.action,32);
  if (action !== 'merchants') {
    throw new HttpsError('permission-denied', 'Use an authorized business workspace');
  }
  return db.runTransaction(async tx => {
    const authority = new AuthorizationService(async p => (await tx.get(db.doc(p))).data() ?? null);
    await authority.requirePlatformAdmin(request);
    if (action === 'merchants') {
      const page = await tx.get(db.collection('merchants').where('status','==','active').limit(50));
      return {merchants:page.docs.map(d => ({id:d.id,name:d.get('businessName') ?? d.get('name') ?? d.id}))};
    }
    throw new HttpsError('invalid-argument','Unknown workspace action');
  });
}
