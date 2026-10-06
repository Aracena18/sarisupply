import { Firestore } from 'firebase-admin/firestore';
import { AuthRequest, AuthorizationService } from '../common/authz';
import { HttpsError } from 'firebase-functions/v2/https';
import { id, text } from '../checkout/checkout-validation';

export async function readOperationalWorkspace(db: Firestore, request: AuthRequest, input: Record<string, unknown>) {
  return db.runTransaction(async tx => {
    const authority = new AuthorizationService(async p => (await tx.get(db.doc(p))).data() ?? null);
    const uid = await authority.requirePlatformAdmin(request);
    const action = text(input.action,32);
    if (action === 'merchants') {
      const page = await tx.get(db.collection('merchants').where('status','==','active').limit(50));
      return {merchants:page.docs.map(d => ({id:d.id,name:d.get('businessName') ?? d.get('name') ?? d.id}))};
    }
    const merchantId = id(input.merchantId), root = `merchants/${merchantId}`;
    const merchant = await tx.get(db.doc(root));
    if (merchant.get('status') !== 'active') throw new HttpsError('not-found','Store is unavailable');
    if (action === 'procurement') {
      const kind = text(input.kind,32);
      if (!['suppliers','purchaseOrders','restockProposals','warehouses','products'].includes(kind)) throw new HttpsError('invalid-argument','Invalid workspace kind');
      const docs = await tx.get(db.collection(`${root}/${kind}`).limit(50));
      const membership = await tx.get(db.doc(`${root}/memberships/${uid}`));
      return {records:docs.docs.map(d => ({...d.data(),id:d.id})),
        canManagePurchasing:membership.get('status') === 'active' && membership.get('role') === 'owner' && membership.get('allBranches') === true && membership.get('userId') === uid && membership.get('merchantId') === merchantId};
    }
    if (action === 'reports') {
      const date = text(input.date,10);
      if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) throw new HttpsError('invalid-argument','Invalid report date');
      const branches = await tx.get(db.collection(`${root}/branches`).limit(50));
      const summaries = [];
      for (const branch of branches.docs) {
        const daily = await tx.get(db.doc(`${root}/branches/${branch.id}/dailyReports/${date}`));
        if (!daily.exists) continue;
        summaries.push({date,branchId:branch.id,branchName:branch.get('name') ?? branch.id,
          ...(daily.exists ? daily.data() : {grossSalesCentavos:0,transactionCount:0,tenders:{}})});
      }
      return {summaries,source:'accepted',branchLimit:50};
    }
    throw new HttpsError('invalid-argument','Unknown workspace action');
  });
}
