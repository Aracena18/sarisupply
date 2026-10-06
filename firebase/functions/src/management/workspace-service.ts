import { FieldPath, Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';
import { AuthorizationService, AuthRequest, requireHuman } from '../common/authz';
import { requireDocumentId } from '../common/ids';

type Input = { merchantId: unknown; kind: unknown; cursor?: unknown };
const collections: Record<string, string> = {
  branches: 'branches', cashiers: 'cashiers', devices: 'devices',
  managers: 'memberships', invitations: 'managerInvites',
};
export async function listManagementRecords(db: Firestore, request: AuthRequest, input: Input) {
  const uid = requireHuman(request);
  const merchantId = requireDocumentId(input.merchantId, 'merchant ID');
  if (typeof input.kind !== 'string' || !Object.hasOwn(collections, input.kind)) {
    throw new HttpsError('invalid-argument', 'Invalid management list');
  }
  const kind = input.kind;
  const cursor = input.cursor === undefined ? undefined : requireDocumentId(input.cursor, 'cursor');
  const authz = new AuthorizationService(async (path) => {
    const snapshot = await db.doc(path).get(); return snapshot.data() ?? null;
  });
  const member = await authz.requireActiveMembership(uid, merchantId);
  const owner = member.role === 'owner' && member.allBranches;
  if (!owner && ['managers', 'invitations'].includes(kind)) {
    throw new HttpsError('permission-denied', 'Owner access required');
  }
  let query = db.collection(`merchants/${merchantId}/${collections[kind]}`)
    .orderBy(FieldPath.documentId()).limit(50);
  if (cursor) query = query.startAfter(cursor);
  const page = await query.get();
  // Historical invitation-created memberships omitted email. Recover the
  // authorized display identity from their accepted invitation, without Auth API
  // access or widening client read rules. New memberships retain verified email.
  const legacyNames = new Map<string, string>();
  if (kind === 'managers') {
    await Promise.all(page.docs.map(async (doc) => {
      const d = doc.data();
      if (d.role !== 'manager' || d.name || d.displayName || d.email) return;
      const invitations = await db.collection(`merchants/${merchantId}/managerInvites`)
        .where('acceptedBy', '==', doc.id).limit(1).get();
      const invitation = invitations.docs[0]?.data();
      if (invitation?.status === 'accepted' && invitation.merchantId === merchantId &&
        typeof invitation.email === 'string') legacyNames.set(doc.id, invitation.email);
    }));
  }
  const records = page.docs.flatMap((doc) => {
    const d = doc.data();
    if (kind === 'managers' && d.role !== 'manager') return [];
    const branchIds: string[] = kind === 'branches' ? [doc.id] :
      kind === 'devices' ? [d.branchId] : kind === 'cashiers' ? d.assignedBranchIds ?? [] : d.branchIds ?? [];
    if (!owner && (!member.allBranches &&
      (!branchIds.length || !branchIds.every((id) => member.branchIds.includes(id))))) return [];
    if (!owner && kind === 'branches' && d.status !== 'active') return [];
    return [{ id: doc.id, name: String(d.name ?? d.displayName ?? d.email ?? legacyNames.get(doc.id) ?? doc.id),
      code: String(d.code ?? d.employeeCode ?? ''), status: String(d.status ?? ''),
      branchIds, allBranches: d.allBranches === true }];
  });
  return { records, nextCursor: page.size === 50 ? page.docs[49].id : null };
}
